import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../services/api_client.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:space_learn_flutter/main.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/notificationModel.dart';
import 'package:space_learn_flutter/core/themes/layout/nav_bar_lecteur.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/ecrivain/livres_page.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/ecrivain/abonnes_page.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/lecteur/bibliotheque_page.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/lecteur/communaute/forum_discussion_page.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/lecteur/communaute/forum_messages_page.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/discussionService.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/dm_service.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/conversation_model.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/conversation_page.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/messages_page.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/ecrivain/communaute_page.dart'
    as ecrivainTeams;
import 'package:space_learn_flutter/core/utils/api_routes.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/bookService.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/details/reading_page.dart';
import 'package:space_learn_flutter/core/utils/token_storage.dart';
import 'package:space_learn_flutter/core/utils/message_erreur.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/evenementService.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/communaute/evenement_apercu.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/details/book_detail_page.dart';

class NotificationService {
  final http.Client client;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  NotificationService({http.Client? client})
    : client = client ?? ApiClient.instance;

  static void initializeLocalNotifications() {
    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );

    _localNotifications.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null) {
          try {
            final Map<String, dynamic> data = jsonDecode(response.payload!);
            final notif = NotificationModel.fromJson(data);
            // Même règle que dans la liste : on ne marque lu que ce qui a
            // vraiment mené quelque part. Les destinations différées se
            // marquent seules (voir [marquerLue]).
            if (handleNotificationTap(notif) && !notif.lu) {
              marquerLue?.call(notif.id);
            }
          } catch (e) {}
        }
      },
    );
  }

  /// Le geste « marquer cette notification comme lue », prête par le provider.
  ///
  /// POURQUOI UN GESTE PRÊTÉ. La moitié des destinations ne s'ouvre qu'après
  /// un aller-retour réseau (retrouver le livre, la discussion, la
  /// conversation). `handleNotificationTap` est synchrone : il rendait `true`
  /// sans condition, et l'appelant marquait la notification lue sur une simple
  /// promesse. Réseau coupé au moment du doigt, la notification passait lue et
  /// déposait l'utilisateur sur un écran de repli — pour un message privé,
  /// c'était le seul pointeur vers la conversation qui disparaissait.
  ///
  /// Le service ne connaît ni provider ni BuildContext : NotificationProvider
  /// lui confie ce geste à sa construction, et le service ne l'appelle
  /// qu'après avoir VU la destination s'ouvrir.
  static Future<void> Function(String id)? marquerLue;

  /// Ouvre l'ecran que la notification designe.
  ///
  /// Rend `false` quand la destination promise n'a PAS pu etre atteinte tout
  /// de suite — soit qu'elle ait echoue, soit qu'elle ne soit connue qu'apres
  /// coup. L'appelant s'en sert pour ne PAS marquer la notification comme
  /// lue : une notification qu'on n'a pas pu suivre doit rester la, non lue,
  /// pour qu'on puisse reessayer — plutot que de disparaitre en emportant ce
  /// qu'on n'a jamais vu. Les destinations differees se marquent seules, via
  /// [marquerLue], une fois l'ecran reellement ouvert.
  static bool handleNotificationTap(NotificationModel notif) {
    final context = navigatorKey.currentContext;
    if (context == null) {
      return false;
    }

    final type = notif.type.toLowerCase();

    // Helper to clear nav stack until root shell
    void popToRoot() {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }

    /// Une destination qui n'est connue qu'apres coup.
    ///
    /// On rend `false` — l'appelant ne marque donc rien — et c'est ici qu'on
    /// marque, si et seulement si l'ecran promis s'est ouvert.
    bool quandOuverte(Future<bool> ouverture) {
      ouverture.then((ouverte) {
        if (ouverte && !notif.lu) marquerLue?.call(notif.id);
      });
      return false;
    }

    // Role check (normalization)
    final isLecteur = (notif.role == 'lecteur' || notif.role == null);

    if (type == 'avis') {
      // « Nouvel avis sur votre livre X » ouvre X.
      //
      // Le serveur rangeait cet evenement dans « communaute », sans reference :
      // il tombait donc dans la branche des salons et menait au forum. Il porte
      // maintenant son propre type et l'identifiant du livre — et c'est la
      // fiche qu'il faut, puisque les avis s'y affichent. La page reconnait
      // l'auteur toute seule.
      return quandOuverte(
        _ouvrirLaFicheDuLivre(context, notif.referenceId, isLecteur, popToRoot),
      );
    } else if (type == 'nouvel_abonne') {
      // On montre QUI vient de s'abonner : la liste des abonnes du
      // destinataire, ou le nouveau venu figure avec son nom et sa photo.
      //
      // Et non sa fiche a lui : `/api/authors/:id` repond 404 pour un compte
      // sans livre publie, ce qui est le cas d'un lecteur — c'est-a-dire de la
      // plupart des abonnes. La reference voyage tout de meme, pour le jour ou
      // un profil de lecteur existera.
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AbonnesPage(authorId: notif.utilisateurId),
        ),
      );
      // Poussee a l'instant, sans reseau : le verdict est certain.
      return true;
    } else if (type == 'message_prive') {
      // « Nouveau message de X » ouvre la CONVERSATION PRIVÉE, pas le forum.
      //
      // reference_id est l'identifiant de la conversation
      // (direct_message/service.go : CreateNotification(..., convID)). Le type
      // contient « message » et tombait donc dans la branche des salons :
      // getDiscussionById répondait 404 — ce n'est pas une discussion — et le
      // repli poussait le hall du forum, sans rapport avec le message reçu.
      // La notification était ensuite marquée lue : le seul pointeur vers la
      // conversation disparaissait. Cette branche passe AVANT le test
      // `contains('message')`, sinon elle est inatteignable.
      //
      // Elle partait aussi sans `await`, si bien que l'appelant marquait lu
      // avant meme de savoir si la conversation avait ete retrouvee : le
      // pointeur disparaissait quand meme. C'est desormais l'ouverture qui
      // decide.
      return quandOuverte(
        _ouvrirLaConversationPrivee(context, notif.referenceId),
      );
    } else if (type.contains('message') ||
        type.contains('reponse') ||
        type.contains('communaute')) {
      // On ouvre le salon dont il est question, pas « un » salon.
      //
      // Le serveur joint l'identifiant de la discussion a la notification
      // depuis toujours ; le routage l'ignorait et poussait le salon global,
      // meme quand le message venait du club d'un livre. Et « communaute » —
      // le type reellement emis pour « Nouveau message dans votre salon » —
      // n'etait reconnu par aucune branche : il tombait dans le cas par
      // defaut, qui renvoie a la bibliotheque.
      return quandOuverte(_ouvrirLeSalon(context, notif.referenceId));
    } else if (type.contains('annonce') || type.contains('evenement')) {
      // On ouvre LA publication, pas « la communaute ».
      //
      // La notification dit « Nouvelle annonce de l'auteur : … » et deposait le
      // lecteur sur l'onglet Communaute, a lui de retrouver de quoi on lui
      // parlait — alors que son identifiant voyage dans la notification.
      return quandOuverte(
        _ouvrirLaPublication(context, notif.referenceId, isLecteur, popToRoot),
      );
    } else if (type.contains('nouveau_livre')) {
      // « Nouveau livre publie » doit montrer LE livre.
      //
      // Le lecteur ne le possede pas encore : l'envoyer dans sa bibliotheque
      // lui fait chercher un ouvrage qui n'y est pas. C'est la fiche qu'il
      // faut ouvrir — celle ou l'on peut justement l'acquerir.
      return quandOuverte(
        _ouvrirLaFicheDuLivre(context, notif.referenceId, isLecteur, popToRoot),
      );
    } else if (type.contains('rappel_lecture')) {
      // « Vous n'avez pas lu X depuis plus de 24h » doit rouvrir X.
      //
      // Le rappel menait a la bibliotheque : au lecteur de retrouver lui-meme
      // l'ouvrage dont on venait de lui parler, alors que la notification en
      // porte l'identifiant. C'est un geste de plus a chaque fois, et le
      // rappel perd ce qui le rendait utile.
      return quandOuverte(
        _ouvrirLeLivre(context, notif.referenceId, popToRoot),
      );
    } else if (type.contains('paiement') ||
        type.contains('achat') ||
        type.contains('vente') ||
        type.contains('livre') ||
        type.contains('chapitre')) {
      if (isLecteur) {
        popToRoot();
        MainNavBar.mainNavBarKey.currentState?.navigateToBibliotheque();
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                LivresPage(onBackPressed: () => Navigator.of(context).pop()),
          ),
        );
      }
    } else {
      // Default fallback
      if (isLecteur) {
        popToRoot();
        MainNavBar.mainNavBarKey.currentState?.navigateToBibliotheque();
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const BibliothequePage()),
        );
      }
    }
    return true;
  }

  /// Ouvre la fiche d'un livre qu'on ne possede pas encore.
  ///
  /// Rend `false` sur chaque repli : la bibliotheque n'est pas la fiche
  /// promise. La notification reste alors non lue et le geste se retente.
  static Future<bool> _ouvrirLaFicheDuLivre(
    BuildContext context,
    String? livreId,
    bool isLecteur,
    VoidCallback popToRoot,
  ) async {
    if (livreId == null || livreId.trim().isEmpty) {
      popToRoot();
      MainNavBar.mainNavBarKey.currentState?.navigateToBibliotheque();
      return false;
    }

    try {
      final token = await TokenStorage.getToken();
      final livre = await BookService().getBookById(livreId, authToken: token);
      if (!context.mounted) return false;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BookDetailPage(book: livre, isOwned: false),
        ),
      );
      return true;
    } catch (_) {
      if (!context.mounted) return false;
      popToRoot();
      MainNavBar.mainNavBarKey.currentState?.navigateToBibliotheque();
      return false;
    }
  }

  /// Ouvre l'annonce ou l'evenement designe par la notification.
  ///
  /// Sans identifiant exploitable, on retombe sur la communaute plutot que de
  /// ne rien faire — mais c'est le repli, plus la regle.
  static Future<bool> _ouvrirLaPublication(
    BuildContext context,
    String? evenementId,
    bool isLecteur,
    VoidCallback popToRoot,
  ) async {
    Future<bool> repli() async {
      if (!context.mounted) return false;
      if (isLecteur) {
        popToRoot();
        MainNavBar.mainNavBarKey.currentState?.navigateToCommunaute();
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ecrivainTeams.TeamsPage(),
          ),
        );
      }
      return false;
    }

    if (evenementId == null || evenementId.trim().isEmpty) return repli();

    try {
      final token = await TokenStorage.getToken();
      if (token == null) return repli();
      final publication = await EvenementService().getEvenementById(
        evenementId,
        token,
      );
      if (!context.mounted) return false;
      // La feuille est poussee ici et se referme quand l'utilisateur le
      // decide : l'attendre retarderait le verdict jusqu'a sa fermeture, alors
      // que la publication est deja a l'ecran — donc deja suivie.
      unawaited(afficherEvenement(context, publication));
      return true;
    } catch (_) {
      // La publication a pu etre retiree depuis l'envoi de la notification.
      return repli();
    }
  }

  /// Ouvre le livre designe par la notification, la ou la lecture s'etait
  /// arretee.
  ///
  /// Sans identifiant exploitable, on retombe sur la bibliotheque plutot que
  /// de ne rien faire.
  static Future<bool> _ouvrirLeLivre(
    BuildContext context,
    String? livreId,
    VoidCallback popToRoot,
  ) async {
    if (livreId == null || livreId.trim().isEmpty) {
      popToRoot();
      MainNavBar.mainNavBarKey.currentState?.navigateToBibliotheque();
      return false;
    }

    try {
      final token = await TokenStorage.getToken();
      final livre = await BookService().getBookById(livreId, authToken: token);
      if (!context.mounted) return false;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ReadingPage(book: livre.toJson()),
        ),
      );
      return true;
    } catch (_) {
      // Le livre a pu etre retire du catalogue depuis l'envoi du rappel.
      if (!context.mounted) return false;
      popToRoot();
      MainNavBar.mainNavBarKey.currentState?.navigateToBibliotheque();
      return false;
    }
  }

  /// Ouvre la discussion designee par la notification.
  ///
  /// Faute d'identifiant exploitable — vieille notification, reference
  /// manquante — on retombe sur le salon commun plutot que de ne rien faire.
  static Future<bool> _ouvrirLeSalon(
    BuildContext context,
    String? discussionId,
  ) async {
    if (discussionId == null || discussionId.trim().isEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ForumDiscussionPage()),
      );
      return false;
    }

    try {
      final discussion = await DiscussionService().getDiscussionById(
        discussionId,
      );
      if (!context.mounted) return false;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ForumMessagesPage(discussion: discussion),
        ),
      );
      return true;
    } catch (_) {
      // La discussion a pu etre supprimee entre-temps.
      if (!context.mounted) return false;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ForumDiscussionPage()),
      );
      return false;
    }
  }

  /// Ouvre la conversation privée désignée par la notification.
  ///
  /// Le serveur n'offre pas de lecture d'une conversation par identifiant :
  /// on la retrouve dans la liste des conversations — c'est d'ailleurs elle
  /// qui porte le correspondant, dont l'écran a besoin. Faute de la retrouver
  /// (réseau, fil disparu), on dépose sur l'écran Messages : le fil y est, ou
  /// son absence s'y explique — jamais sur le forum, qui n'a rien à voir.
  /// Rend `true` UNIQUEMENT si la conversation elle-meme s'est ouverte.
  ///
  /// L'ecran Messages est un repli, pas la destination promise : reseau coupe
  /// au moment du doigt, ou fil introuvable, la notification doit rester non
  /// lue. Elle porte le seul identifiant de conversation dont on dispose — la
  /// marquer lue effaçait ce pointeur, et le fil n'etait plus retrouvable
  /// qu'en fouillant la messagerie.
  static Future<bool> _ouvrirLaConversationPrivee(
    BuildContext context,
    String? conversationId,
  ) async {
    Future<bool> versLaListe() async {
      if (!context.mounted) return false;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const MessagesPage()),
      );
      return false;
    }

    final id = conversationId?.trim();
    if (id == null || id.isEmpty) return versLaListe();

    try {
      final token = await TokenStorage.getToken();
      if (token == null) return versLaListe();

      final conversations = await DmService().getConversations(token);
      Conversation? trouvee;
      for (final c in conversations) {
        if (c.id == id) {
          trouvee = c;
          break;
        }
      }
      final conversation = trouvee;
      if (conversation == null) return versLaListe();

      if (!context.mounted) return false;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ConversationPage(conversation: conversation),
        ),
      );
      return true;
    } catch (_) {
      return versLaListe();
    }
  }

  static Future<void> showLocalNotification({
    required String id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'high_importance_channel',
        'Notifications Importantes',
        channelDescription: 'Canal pour les notifications de l\'application',
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );

    await _localNotifications.show(
      id: id.hashCode,
      title: title.toUpperCase(),
      body: body,
      notificationDetails: notificationDetails,
      payload: payload,
    );
  }

  Future<dynamic> getNotifications(
    String authToken, {
    bool onlyUnread = false,
    bool groupByRole = false,
  }) async {
    String url = ApiRoutes.notifications;
    List<String> queryParams = [];
    if (onlyUnread) queryParams.add("lu=false");
    if (groupByRole) queryParams.add("group_by_role=true");

    if (queryParams.isNotEmpty) {
      url += "?${queryParams.join("&")}";
    }

    final response = await client.get(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $authToken'},
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      final rawData = data['data'] ?? data;

      if (groupByRole && rawData is Map<String, dynamic>) {
        final Map<String, List<NotificationModel>> grouped = {};
        rawData.forEach((key, value) {
          if (value is List) {
            grouped[key] = value
                .map((json) => NotificationModel.fromJson(json, role: key))
                .toList();
          } else {
            // Un seau sans élément arrive `null`, pas `[]` : côté Go, un
            // slice nil se sérialise en null (notification/controller.go).
            // L'ignorer faisait disparaître la clé du rôle, et l'écran, ne
            // trouvant pas son seau, se rabattait sur la liste À PLAT des
            // deux profils. Un seau nul est un seau VIDE, pas un seau absent.
            grouped[key] = <NotificationModel>[];
          }
        });
        return grouped;
      } else if (rawData is List) {
        return rawData.map((json) => NotificationModel.fromJson(json)).toList();
      }
      return <NotificationModel>[];
    } else {
      throw Exception(
        messageDeLaReponse(
          response,
          repli: "Impossible de charger vos notifications.",
        ),
      );
    }
  }

  Future<NotificationModel> createNotification(
    Map<String, dynamic> notificationData,
    String authToken,
  ) async {
    final response = await client.post(
      Uri.parse(ApiRoutes.notifications),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $authToken',
      },
      body: jsonEncode(notificationData),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      return NotificationModel.fromJson(data['data'] ?? data);
    } else {
      throw Exception(
        messageDeLaReponse(
          response,
          repli: "Cette notification n'a pas pu être créée.",
        ),
      );
    }
  }

  Future<void> markAsRead(String id, String authToken) async {
    final url = ApiRoutes.markNotificationAsRead.replaceFirst(':id', id);
    final response = await client.put(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $authToken'},
    );

    if (response.statusCode != 200) {
      throw Exception(
        messageDeLaReponse(
          response,
          repli: "Cette notification n'a pas pu être marquée comme lue.",
        ),
      );
    }
  }

  Future<void> markAllAsRead(String authToken) async {
    final response = await client.put(
      Uri.parse(ApiRoutes.markAllNotificationsAsRead),
      headers: {'Authorization': 'Bearer $authToken'},
    );

    if (response.statusCode != 200) {
      throw Exception(
        messageDeLaReponse(
          response,
          repli: "Vos notifications n'ont pas pu être marquées comme lues.",
        ),
      );
    }
  }

  Future<void> deleteNotification(String id, String authToken) async {
    final url = ApiRoutes.notificationById.replaceFirst(':id', id);
    final response = await client.delete(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $authToken'},
    );

    if (response.statusCode != 200) {
      throw Exception(
        messageDeLaReponse(
          response,
          repli: "Cette notification n'a pas pu être supprimée.",
        ),
      );
    }
  }

  /// Le flux des notifications, en direct.
  ///
  /// [authToken] n'est plus utilisé pour ouvrir la connexion : il ne sert qu'à
  /// ne pas casser les appelants existants. Le jeton est relu à CHAQUE
  /// tentative, et c'est tout l'objet du correctif.
  ///
  /// Il était capturé une fois, à l'ouverture, et la boucle de reconnexion
  /// réutilisait indéfiniment le même. Tant qu'un jeton valait vingt-quatre
  /// heures, cela ne se voyait pas : l'application était relancée avant. Depuis
  /// qu'il ne vaut qu'une heure, les notifications s'arrêtaient au bout d'une
  /// heure — définitivement, avec une reconnexion toutes les trente secondes
  /// présentant chaque fois le même jeton mort. Silence côté écran, et une
  /// requête inutile toutes les demi-minutes sur des forfaits data comptés.
  Stream<NotificationModel> streamNotifications(String authToken) {
    final controller = StreamController<NotificationModel>.broadcast();

    bool cancelled = false;
    controller.onCancel = () {
      cancelled = true;
    };

    () async {
      int attempt = 0;

      while (!cancelled) {
        HttpClient? httpClient;
        HttpClientRequest? request;
        try {
          final jeton = await TokenStorage.getToken();
          if (jeton == null || jeton.isEmpty) {
            // Plus de session : inutile d'insister vite.
            await Future.delayed(const Duration(seconds: 30));
            continue;
          }

          final uri = Uri.parse(ApiRoutes.notificationsStream);
          httpClient = HttpClient();
          request = await httpClient.getUrl(uri);
          request.headers.set('Authorization', 'Bearer $jeton');
          request.headers.set('Accept', 'text/event-stream');
          request.headers.set('Cache-Control', 'no-cache');

          final response = await request.close();
          if (response.statusCode != 200) {
            // Un 401 se répare, et lui seul : on demande un jeton neuf avant
            // de réessayer. L'intercepteur d'ApiClient ne peut rien ici — une
            // connexion longue n'est pas une requête qu'on rejoue.
            if (response.statusCode == 401) {
              final verdict = await ApiClient.instance.renouvelerSession();
              // Session réellement finie : on cesse d'insister. La boucle
              // rouvrait sinon une connexion toutes les trente secondes, pour
              // toujours, avec un jeton dont on savait qu'il était mort — sur
              // des forfaits data comptés.
              if (verdict == Renouvellement.refuse) break;
            }
            attempt = math.min(attempt + 1, 6);
            final wait = math.min(30, 1 << attempt);
            await Future.delayed(Duration(seconds: wait));
            continue;
          }

          attempt = 0;

          final utf8Stream = response.transform(utf8.decoder);
          final lineStream = utf8Stream.transform(const LineSplitter());

          StringBuffer buffer = StringBuffer();

          await for (final rawLine in lineStream) {
            if (cancelled) break;
            final line = rawLine.trim();
            if (line.isEmpty) {
              if (buffer.isNotEmpty) {
                final dataStr = buffer.toString();
                try {
                  final decoded = jsonDecode(dataStr);
                  Map<String, dynamic>? payload;

                  if (decoded is Map<String, dynamic>) {
                    if (decoded.containsKey('data')) {
                      final d = decoded['data'];
                      if (d is Map) {
                        payload = Map<String, dynamic>.from(d);
                      } else if (d is String) {
                        try {
                          final inner = jsonDecode(d);
                          if (inner is Map) {
                            payload = Map<String, dynamic>.from(inner);
                          }
                        } catch (_) {}
                      }
                    } else {
                      payload = decoded;
                    }
                  }

                  if (payload != null) {
                    final model = NotificationModel.fromJson(payload);
                    if (!controller.isClosed) controller.add(model);
                  }
                } catch (e) {}
                buffer.clear();
              }
            } else if (line.startsWith('data:')) {
              buffer.write(line.substring(5).trim());
            } else if (!line.startsWith(':') && !line.startsWith('event:')) {
              buffer.write(line);
            }
          }
        } catch (e) {
          if (e is! SocketException && e is! HttpException) {}
        } finally {
          try {
            request?.abort();
          } catch (_) {}
          try {
            httpClient?.close(force: true);
          } catch (_) {}
        }

        if (!cancelled) {
          attempt = math.min(attempt + 1, 6);
          final wait = math.min(10, 1 << attempt);
          await Future.delayed(Duration(seconds: wait));
        }
      }

      if (!controller.isClosed) await controller.close();
    }();

    return controller.stream;
  }
}
