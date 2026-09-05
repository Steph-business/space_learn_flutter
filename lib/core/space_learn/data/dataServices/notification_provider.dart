import 'dart:async';
import 'package:space_learn_flutter/core/utils/preferences_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/authServices.dart';
import 'package:space_learn_flutter/core/services/session_service.dart';
import 'package:space_learn_flutter/core/utils/message_erreur.dart';
import 'package:space_learn_flutter/core/utils/token_storage.dart';
import 'notificationService.dart';
import '../model/notificationModel.dart';

/// La plus récente en tête, sans jamais faire remonter une date manquante.
///
/// Le tri précédent remplaçait une date absente par `DateTime.now()` : une
/// notification sans date devenait donc la plus récente de toutes et se
/// plaçait en haut. Un repli doit choisir le cas le moins nuisible — ici,
/// laisser couler ce dont on ignore la date plutôt que de la promouvoir.
///
/// Le départage par identifiant n'est pas cosmétique : deux notifications
/// écrites dans la même seconde — l'échec d'un paiement et la réussite de la
/// tentative suivante — ont la même date à la seconde près, et `compareTo`
/// rend alors zéro. Sans second critère, leur ordre dépend de celui où la
/// base les a rendues, c'est-à-dire de rien.
List<NotificationModel> trierDuPlusRecent(List<NotificationModel> liste) {
  final copie = List<NotificationModel>.from(liste);
  final jamais = DateTime.fromMillisecondsSinceEpoch(0);
  copie.sort((a, b) {
    final parDate = (b.creeLe ?? jamais).compareTo(a.creeLe ?? jamais);
    if (parDate != 0) return parDate;
    return b.id.compareTo(a.id);
  });
  return copie;
}

class NotificationProvider extends ChangeNotifier {
  NotificationProvider() {
    // Ce provider est créé à la racine de l'application (main.dart) et survit
    // à la déconnexion : sans cette inscription, les notifications du compte
    // déconnecté restaient en mémoire — pastille et liste d'un AUTRE compte
    // affichées à la personne suivante sur le même téléphone.
    //
    // La clé est `this`, l'INSCRIT lui-même, et non la chaîne constante
    // 'notifications' qui servait ici : le registre est une Map, donc deux
    // instances — un provider imbriqué, un test de widget, un rechargement à
    // chaud partiel — s'écrasaient l'une l'autre sous cette clé unique. La
    // première à mourir désinscrivait alors la purge de la SECONDE, qui
    // survivait à la déconnexion avec les notifications du compte précédent :
    // exactement la fuite que cette inscription est censée fermer.
    SessionService.enregistrerPurge(this, purge);

    // Le routeur des notifications (NotificationService.handleNotificationTap)
    // ouvre des écrans dont l'aboutissement n'est connu qu'APRÈS un aller-
    // retour réseau : il ne peut donc pas rendre son verdict à l'appelant, qui
    // marquait la notification lue sur une simple promesse — un message privé
    // dont la conversation n'avait pas pu être retrouvée passait lu, et le
    // seul pointeur vers ce fil disparaissait. On prête au service le geste de
    // marquer, qu'il n'exécutera qu'une fois la destination réellement
    // atteinte. Prêt de geste, comme la purge confiée à SessionService
    // ci-dessus : le service n'a ainsi ni BuildContext ni provider à connaître.
    //
    // Le geste est GARDÉ dans un champ pour que dispose() puisse vérifier que
    // celui posé sur le service est encore le sien : le slot est unique et
    // statique, si bien qu'une seconde instance y écrit par-dessus. Sans cette
    // garde, la première détruite remettait le slot à `null` et le service
    // perdait le geste de la SECONDE — les notifications ouvertes depuis une
    // bannière système ne se marquaient plus jamais lues.
    _marquerLuePretee = (id) async {
      final jeton = await TokenStorage.getToken();
      if (jeton == null || jeton.isEmpty) return;
      await markAsRead(id, jeton);
    };
    NotificationService.marquerLue = _marquerLuePretee;
  }

  /// Le geste prêté à NotificationService, tel qu'on l'y a posé.
  late final Future<void> Function(String id) _marquerLuePretee;

  final NotificationService _service = NotificationService();
  final AuthService _authService = AuthService();
  List<NotificationModel> _notifications = [];
  Map<String, List<NotificationModel>> _groupedNotifications = {};
  bool _isLoading = false;
  StreamSubscription? _subscription;
  dynamic _lastStreamError;

  /// Compte dont proviennent les listes en mémoire.
  ///
  /// Sert de garde-fou : si le compte connecté a changé, on vide AVANT de
  /// recharger, pour qu'un échec réseau ne laisse pas les notifications de
  /// l'ancien compte affichées au nouveau.
  String? _compteCharge;

  /// Dernier échec de chargement, lisible par l'écran.
  ///
  /// Une panne n'est pas un vide : sans cet état, un serveur injoignable
  /// laissait la page afficher « Aucune notification pour l'instant » —
  /// l'utilisateur croyait n'avoir rien reçu alors que rien n'avait répondu.
  /// Nul dès qu'un chargement démarre, et de nouveau nul quand il réussit :
  /// l'écran qui le lit sait donc toujours si l'état affiché est une panne ou
  /// une véritable absence de notifications, et peut proposer « Réessayer ».
  String? _erreurChargement;
  String? get derniereErreurChargement => _erreurChargement;

  /// Même valeur sous un nom plus court, pour l'écran qui l'appelle ainsi.
  String? get erreurChargement => _erreurChargement;

  List<NotificationModel> get notifications =>
      List.unmodifiable(_notifications);
  Map<String, List<NotificationModel>> get groupedNotifications =>
      _groupedNotifications;
  bool get isLoading => _isLoading;
  int get unreadCount => _notifications.where((n) => !n.lu).length;

  /// Vrai pour ce qui s'adresse à la PERSONNE plutôt qu'à l'un de ses métiers.
  ///
  /// Miroir d'estNotificationPersonnelle côté serveur (space_learn_livres/
  /// modules/notification/controller.go) : le SEUL type personnel est
  /// « message_prive ». Comparaison exacte, et non `contains('message')` :
  /// les autres types qui contiennent « message » (message de communauté,
  /// réponse à un message) restent des notifications de lecteur et doivent
  /// continuer d'aller dans le seul seau lecteur.
  static bool concerneLesDeuxProfils(String type) {
    final normalise = type.toLowerCase().trim();
    // La variante accentuée n'existe pas côté serveur ; on la tolère au cas
    // où une ancienne ligne en base la porterait encore.
    return normalise == 'message_prive' || normalise == 'message_privé';
  }

  /// Le profil auquel une notification s'adresse, deviné comme le SERVEUR.
  ///
  /// Miroir fidèle d'isAuthorNotification (space_learn_livres/modules/
  /// notification/controller.go) : sont des notifications d'AUTEUR le type
  /// « vente », « avis », « nouvel_abonne », et tout type préfixé « auteur ».
  /// Tout le reste appartient au LECTEUR. « message_prive » s'adresse à la
  /// personne et non à l'un de ses métiers : il rend `null`, ce qui vaut
  /// « les deux profils ».
  ///
  /// POURQUOI DEVINER ICI. Le modèle Go Notification n'a AUCUN champ Role
  /// (notification/model.go) : ni la route à plat ni le flux SSE n'en portent,
  /// et `json['role']` est toujours absent. Seule la route group_by_role
  /// classe, et elle le fait dans le nom des seaux. Les trois chemins qui
  /// remplissent ce provider — liste groupée, liste à plat, temps réel —
  /// doivent donc classer PAREIL, sinon la même notification change de profil
  /// selon la façon dont elle est arrivée : c'était l'ancienne heuristique
  /// « contains », qui ne reconnaissait ni « avis » (type d'auteur rangé chez
  /// le lecteur) ni « rappel_lecture » (type de lecteur laissé sans rôle,
  /// donc versé dans les deux seaux). Une seule fonction, trois chemins.
  static String? roleDeLaNotification(String type) {
    if (concerneLesDeuxProfils(type)) return null;
    final t = type.toLowerCase().trim();
    if (t == 'vente' ||
        t == 'avis' ||
        t == 'nouvel_abonne' ||
        t.startsWith('auteur')) {
      return 'auteur';
    }
    return 'lecteur';
  }

  int getUnreadCountByRole(String role) {
    return _notifications.where((n) {
      if (n.lu) return false;
      // Un message privé compte pour TOUS les profils : la branche
      // group_by_role du serveur le range côté lecteur (partition stricte),
      // mais son destinataire peut naviguer en auteur — sans cela, un auteur
      // n'était jamais prévenu qu'on lui avait écrit.
      if (concerneLesDeuxProfils(n.type)) return true;
      // `n.role == null` comptait autrefois pour les DEUX pastilles. Comme
      // rien ne pose ce champ hors de la route groupée, un simple passage par
      // l'accueil lecteur (qui charge la route à plat) faisait compter les
      // ventes du profil auteur dans la pastille du profil lecteur. On classe
      // désormais nous-mêmes ce que le serveur n'a pas classé.
      return (n.role ?? roleDeLaNotification(n.type)) == role;
    }).length;
  }

  /// Remet le provider à zéro : listes, compteur, flux temps réel.
  ///
  /// Appelée par SessionService.terminer : la fin de session doit effacer
  /// l'état en mémoire comme elle efface le stockage.
  void purge() {
    _subscription?.cancel();
    _subscription = null;
    _notifications = [];
    _groupedNotifications = {};
    _compteCharge = null;
    _erreurChargement = null;
    _isLoading = false;
    notifyListeners();
  }

  /// Vide les listes si le compte connecté n'est plus celui dont elles
  /// proviennent — AVANT d'appeler le réseau, pour que le `catch` d'un
  /// chargement en échec ne conserve jamais les données d'un autre compte.
  Future<void> _purgerSiCompteChange() async {
    try {
      final compteActuel = await TokenStorage.getUserId();
      if (_compteCharge != null && compteActuel != _compteCharge) {
        _subscription?.cancel();
        _subscription = null;
        _notifications = [];
        _groupedNotifications = {};
      }
      _compteCharge = compteActuel;
    } catch (_) {
      // Ne pas savoir qui est connecté n'empêche pas d'essayer de charger.
    }
  }

  Future<void> loadNotifications(
    String token, {
    bool onlyUnread = false,
  }) async {
    _isLoading = true;
    _erreurChargement = null;
    notifyListeners();
    await _purgerSiCompteChange();

    try {
      final user = await _authService.getUser(token);
      final userId = user?.id;

      final result = await _service.getNotifications(
        token,
        onlyUnread: onlyUnread,
      );
      List<NotificationModel> allNotifications = [];
      if (result is List<NotificationModel>) {
        allNotifications = result;
      }

      if (userId != null && userId.isNotEmpty) {
        // La route à plat ne porte AUCUN rôle : le modèle Go n'a pas de champ
        // Role, seule la route group_by_role classe — dans le nom des seaux.
        // Sans ce classement local, cet appel ÉCRASAIT les rôles posés par
        // loadGroupedNotifications : la pastille repartait à compter les deux
        // profils, et la page (qui lit les seaux) montrait autre chose que le
        // badge. On reproduit donc le tri du serveur avant de stocker.
        _notifications = trierDuPlusRecent(
          allNotifications
              .where((n) => n.utilisateurId == userId)
              .map((n) => _avecRole(n, n.role ?? roleDeLaNotification(n.type)))
              .toList(),
        );
      } else {
        // Si on ne connaît pas l'utilisateur, on ne montre rien par sécurité
        _notifications = [];
      }

      // Les seaux sont reconstruits sur la même liste, avec le même
      // classement. Ils restaient sinon figés sur un chargement groupé
      // antérieur : l'accueil lecteur passe par ici, et la page notifications
      // — qui lit les seaux — affichait ensuite un état plus vieux que la
      // pastille, calculée, elle, sur la liste à plat.
      //
      // Sauf en lecture partielle : une liste « non lues seulement » ferait
      // des seaux amputés, et l'écran des notifications, qui les affiche,
      // perdrait ses archives sans que rien ne l'explique.
      if (!onlyUnread) {
        _groupedNotifications = _regrouperParRole(_notifications);
      }

      _isLoading = false;
      notifyListeners();

      // Start streaming for real-time updates
      _startStreaming(token, userId);
    } catch (e) {
      _erreurChargement = messageLisible(
        e,
        repli: "Impossible de charger vos notifications.",
      );
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Range une liste à plat dans les seaux « lecteur » / « auteur ».
  ///
  /// Même règle que le serveur, et que le flux temps réel : ce qui s'adresse
  /// à la personne (message privé) va dans les DEUX seaux, le reste dans le
  /// seul seau de son métier. Les deux clés existent toujours, même vides —
  /// un seau absent faisait retomber l'écran sur la liste des deux profils.
  Map<String, List<NotificationModel>> _regrouperParRole(
    List<NotificationModel> liste,
  ) {
    final seaux = <String, List<NotificationModel>>{
      'lecteur': <NotificationModel>[],
      'auteur': <NotificationModel>[],
    };
    for (final n in trierDuPlusRecent(liste)) {
      final role = n.role ?? roleDeLaNotification(n.type);
      if (role == null) {
        for (final seau in seaux.values) {
          seau.add(n);
        }
      } else {
        seaux.putIfAbsent(role, () => <NotificationModel>[]).add(n);
      }
    }
    return seaux;
  }

  Future<void> loadGroupedNotifications(String token) async {
    _isLoading = true;
    _erreurChargement = null;
    notifyListeners();
    await _purgerSiCompteChange();

    try {
      final user = await _authService.getUser(token);
      final userId = user?.id;

      final result = await _service.getNotifications(token, groupByRole: true);

      if (result is Map<String, List<NotificationModel>>) {
        // La liste à plat se construit sur la réponse BRUTE, avant la recopie
        // ci-dessous : ainsi un message privé n'y figure qu'une fois et le
        // compteur de non-lus ne le compte pas deux fois.
        _notifications = trierDuPlusRecent(
          result.values.expand((element) => element).toList(),
        );

        final seaux = <String, List<NotificationModel>>{
          for (final entree in result.entries)
            entree.key: List<NotificationModel>.from(entree.value),
        };

        // « message_prive » s'adresse à la PERSONNE, pas à l'un de ses
        // métiers — mais la branche group_by_role du serveur reste une
        // partition STRICTE qui le range côté lecteur (le correctif « dans
        // les deux seaux » ne vaut que pour la branche ?role= du site). Sans
        // cette recopie, un auteur navigant en profil auteur n'était jamais
        // prévenu qu'on lui avait écrit : ni pastille, ni ligne.
        final tousLesSeaux = <String>{'lecteur', 'auteur', ...seaux.keys};
        for (final n in _notifications) {
          if (!concerneLesDeuxProfils(n.type)) continue;
          for (final nomSeau in tousLesSeaux) {
            final liste = seaux.putIfAbsent(nomSeau, () => []);
            if (!liste.any((x) => x.id == n.id)) liste.add(n);
          }
        }

        // Chaque seau est trié, pas seulement la liste à plat.
        //
        // L'écran affiche `groupedNotifications[role]` et ne retombe sur
        // `notifications` que si ce seau est vide : c'était donc la SEULE liste
        // triée qui n'était presque jamais celle qu'on voyait. Un échec de
        // paiement s'affichait au-dessus de la réussite qui l'avait suivi.
        _groupedNotifications = {
          for (final entree in seaux.entries)
            entree.key: trierDuPlusRecent(entree.value),
        };
      }

      _isLoading = false;
      notifyListeners();

      if (userId != null) _startStreaming(token, userId);
    } catch (e) {
      // La liste conservée ici est toujours celle du MÊME compte :
      // _purgerSiCompteChange a vidé avant l'appel si le compte a changé.
      // On garde donc le dernier état connu, mais on dit la panne à l'écran.
      _erreurChargement = messageLisible(
        e,
        repli: "Impossible de charger vos notifications.",
      );
      _isLoading = false;
      notifyListeners();
    }
  }

  void _startStreaming(String token, String? userId) {
    _subscription?.cancel();
    _subscription = _service
        .streamNotifications(token)
        .listen(
          (notification) {
            if (userId == null ||
                userId.isEmpty ||
                notification.utilisateurId != userId) {
              return; // Ignorer les notifications qui ne nous concernent pas
            }

            // Le flux SSE ne porte pas de rôle non plus : on le devine avec
            // la MÊME fonction que les deux routes HTTP.
            //
            // L'heuristique précédente testait des fragments (« vente »,
            // « abonn », « payment », « chapitre », « message ») qui ne
            // correspondaient pas aux types réels : « avis » — une
            // notification d'AUTEUR, et une notification d'argent — n'était
            // reconnu par aucun test, restait sans rôle, et la branche « tous
            // les seaux » ci-dessous l'affichait aussi au profil LECTEUR, où
            // « tout marquer comme lu » l'éteignait. Symétriquement,
            // « rappel_lecture » atterrissait chez l'auteur. Au premier
            // rechargement le serveur remettait tout dans un seul seau et la
            // ligne disparaissait de l'écran où on venait de la voir.
            //
            // Un message privé garde role=null : il compte ainsi pour tous
            // les rôles (pastille) et la boucle ci-dessous le range dans tous
            // les seaux — le ranger côté lecteur rendait l'auteur sourd aux
            // messages reçus pendant qu'il navigue en profil auteur.
            final String? assignedRole =
                notification.role ?? roleDeLaNotification(notification.type);

            final taggedNotif = NotificationModel(
              id: notification.id,
              utilisateurId: notification.utilisateurId,
              type: notification.type,
              contenu: notification.contenu,
              lu: notification.lu,
              creeLe: notification.creeLe,
              role: assignedRole,
              referenceId: notification.referenceId,
              data: notification.data,
            );

            // Add new notification at the beginning
            _notifications = [taggedNotif, ..._notifications];

            // Also update grouped map if it exists
            if (assignedRole != null) {
              final list = _groupedNotifications[assignedRole] ?? [];
              _groupedNotifications[assignedRole] = [taggedNotif, ...list];
            } else {
              // Un seul type arrive ici : le message privé, qui s'adresse à
              // la personne et non à l'un de ses métiers. Ce qui vaut pour
              // tous les profils va donc dans tous les seaux — c'est
              // exactement ce que la page recompose après un rechargement,
              // si bien que l'état reçu en direct ne diverge plus de l'état
              // rechargé.
              for (final nomSeau in <String>{
                'lecteur',
                'auteur',
                ..._groupedNotifications.keys,
              }) {
                final list = _groupedNotifications[nomSeau] ?? [];
                _groupedNotifications[nomSeau] = [taggedNotif, ...list];
              }
            }

            // L'alerte système, si le lecteur l'a acceptée.
            //
            // Elle partait sans condition : les interrupteurs de l'écran
            // « Notifications » enregistraient leur état sur l'appareil et
            // personne ne les relisait. Couper « Rappels de lecture »
            // n'empêchait aucun rappel d'arriver.
            //
            // La notification reste ajoutée à la liste dans tous les cas : le
            // réglage porte sur l'interruption — la bannière qui s'affiche par
            // dessus ce qu'on fait — pas sur le droit d'être informé.
            PreferencesNotifications.doitAfficher(taggedNotif.type).then((ok) {
              if (!ok) return;
              NotificationService.showLocalNotification(
                id: taggedNotif.id,
                title: taggedNotif.type,
                body: taggedNotif.contenu,
              );
            });

            notifyListeners();
          },
          onError: (error) {
            final errorStr = error.toString();
            // Don't flood logs with connection issues if server is down
            if (errorStr.contains("SocketException") ||
                errorStr.contains("HttpException") ||
                errorStr.contains("Connection refused") ||
                errorStr.contains("Connection closed")) {
              return;
            }
            if (errorStr != _lastStreamError?.toString()) {
              _lastStreamError = error;
            }
          },
        );
  }

  /// Le meme modele, marque comme lu.
  ///
  /// NotificationModel n'a pas de copyWith : recopier ses neuf champs a chaque
  /// endroit qui en modifie un est un piege — le jour ou l'on en ajoute un,
  /// chaque copie oubliee le perd sans bruit. Une seule copie a tenir.
  NotificationModel _marquee(NotificationModel n) => NotificationModel(
    id: n.id,
    utilisateurId: n.utilisateurId,
    type: n.type,
    contenu: n.contenu,
    lu: true,
    creeLe: n.creeLe,
    role: n.role,
    referenceId: n.referenceId,
    data: n.data,
  );

  /// Le même modèle, rangé sous un autre profil.
  ///
  /// Même raison que `_marquee` : une seule copie des neuf champs à tenir.
  NotificationModel _avecRole(NotificationModel n, String? role) =>
      NotificationModel(
        id: n.id,
        utilisateurId: n.utilisateurId,
        type: n.type,
        contenu: n.contenu,
        lu: n.lu,
        creeLe: n.creeLe,
        role: role,
        referenceId: n.referenceId,
        data: n.data,
      );

  /// Marque une notification comme lue, dans les deux listes.
  ///
  /// Il y en a deux : `_notifications`, a plat, et `_groupedNotifications`,
  /// par role. La page des notifications lit la seconde ; cette methode ne
  /// touchait que la premiere. Une notification ouverte restait donc affichee
  /// comme non lue, et le filtre « non lues » continuait de la montrer —
  /// exactement le contraire de ce qu'on attend en la lisant.
  ///
  /// Rend `false` quand le serveur a refusé. L'échec était avalé en silence :
  /// « tout marquer comme lu » enchaîne un PUT par notification, et si le
  /// réseau tombait au milieu, l'écran affichait la même liste qu'avant sans
  /// jamais dire pourquoi. Aucun succès ne s'annonce sans réponse du serveur.
  Future<bool> markAsRead(String id, String token) async {
    try {
      await _service.markAsRead(id, token);

      final index = _notifications.indexWhere((n) => n.id == id);
      if (index != -1) {
        _notifications[index] = _marquee(_notifications[index]);
      }

      for (final role in _groupedNotifications.keys) {
        final liste = _groupedNotifications[role]!;
        final i = liste.indexWhere((n) => n.id == id);
        if (i != -1) liste[i] = _marquee(liste[i]);
      }

      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Marque tout comme lu. Rend `false` quand le serveur a refusé.
  ///
  /// L'échec partait dans un `catch` VIDE : rien ne changeait à l'écran — ce
  /// qui est juste, puisque le serveur n'a rien marqué — mais personne ne
  /// pouvait le dire à l'utilisateur, qui voyait ses pastilles rester allumées
  /// après avoir appuyé sur « tout marquer comme lu » sans la moindre
  /// explication. Comme `markAsRead` et `supprimer` au-dessus : le verdict du
  /// serveur remonte à l'appelant.
  Future<bool> markAllAsRead(String token) async {
    try {
      await _service.markAllAsRead(token);
      _notifications = _notifications.map(_marquee).toList();
      _groupedNotifications = _groupedNotifications.map(
        (role, liste) => MapEntry(role, liste.map(_marquee).toList()),
      );
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Retire une notification, ici et sur le serveur.
  ///
  /// L'affichage est mis a jour avant la reponse pour que le geste reponde
  /// tout de suite ; si le serveur refuse, elle revient a sa place plutot que
  /// de disparaitre d'un ecran ou elle existe encore.
  Future<bool> supprimer(String id, String token) async {
    final avantPlat = List<NotificationModel>.from(_notifications);
    final avantGroupe = _groupedNotifications.map(
      (role, liste) => MapEntry(role, List<NotificationModel>.from(liste)),
    );

    _notifications.removeWhere((n) => n.id == id);
    for (final liste in _groupedNotifications.values) {
      liste.removeWhere((n) => n.id == id);
    }
    notifyListeners();

    try {
      await _service.deleteNotification(id, token);
      return true;
    } catch (e) {
      _notifications = avantPlat;
      _groupedNotifications = avantGroupe;
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    // Un provider détruit ne doit plus recevoir la purge de fin de session :
    // notifyListeners après dispose lèverait.
    //
    // MÊME identité qu'à l'inscription — `this`, et la même purge : on retire
    // la SIENNE, jamais celle d'une autre instance. Avec la chaîne constante
    // d'avant, le premier provider détruit emportait l'inscription de tous
    // les autres.
    SessionService.oublierPurge(this, purge);
    // Même raison pour le geste prêté au service : l'appeler après dispose
    // ferait lever notifyListeners. Mais on ne retire QUE le sien — si une
    // autre instance a depuis posé le sien dans ce slot unique, le remettre à
    // `null` la rendrait sourde sans qu'elle en sache rien.
    if (identical(NotificationService.marquerLue, _marquerLuePretee)) {
      NotificationService.marquerLue = null;
    }
    _subscription?.cancel();
    super.dispose();
  }
}
