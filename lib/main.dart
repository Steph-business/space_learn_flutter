import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/notification_provider.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/notificationService.dart';
import 'package:space_learn_flutter/core/services/api_client.dart';
import 'package:space_learn_flutter/core/services/session_service.dart';
import 'package:space_learn_flutter/core/services/deep_link_service.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/details/book_loader_page.dart';
import 'package:space_learn_flutter/core/themes/theme_provider.dart';
import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/utils/app_notifications.dart';
import 'package:space_learn_flutter/core/themes/app_theme.dart';

import 'package:space_learn_flutter/core/space_learn/pages/principales/auth/profil.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/auth/bienvenue.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/auth/login.dart';
import 'package:space_learn_flutter/core/utils/token_storage.dart';
import 'package:space_learn_flutter/core/utils/profile_storage.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/user_model.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/profilModel.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/authServices.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/profileService.dart';

import 'package:space_learn_flutter/core/space_learn/pages/principales/ecrivain/accueil_auteur_page.dart'
    as ecrivainHome;
import 'package:space_learn_flutter/core/space_learn/pages/principales/lecteur/accueil_lecteur_page.dart'
    as lecteurHome;
import 'package:space_learn_flutter/core/widgets/splash_screen.dart';
import 'package:space_learn_flutter/core/services/lecture_audio_handler.dart';
import 'package:space_learn_flutter/core/utils/parcours.dart';
import 'package:space_learn_flutter/core/utils/api_routes.dart';

/// Ce que toutes les préparations réunies ont le droit de faire attendre avant
/// le premier écran.
///
/// Un budget commun, et non un délai par étape : quatre étapes à huit secondes
/// laisseraient une demi-minute d'écran figé.
const Duration _budgetDemarrage = Duration(seconds: 8);

/// Exécute une préparation sans qu'elle puisse retenir le lancement.
///
/// Aucune n'est indispensable à l'affichage : sans elles l'application ouvre
/// diminuée — pas de notifications, pas de lecture en arrière-plan, le thème
/// par défaut — ce qui vaut infiniment mieux qu'un écran de lancement figé. Là,
/// l'utilisateur n'a aucun recours : `runApp` n'a pas été appelé, il n'y a donc
/// pas d'interface, pas de bouton, pas de message, rien à toucher.
///
/// Deux de ces appels n'étaient protégés par rien : une exception de
/// `initializeDateFormatting` ou de `SharedPreferences` sortait de `main` et
/// laissait le splash natif à l'écran, définitivement.
Future<void> _preparer(
  String nom,
  DateTime limite,
  Future<void> Function() etape,
) async {
  try {
    await etape().timeout(_resteAvant(limite));
  } catch (e) {
    debugPrint('Démarrage — « $nom » abandonné : $e');
  }
}

Duration _resteAvant(DateTime limite) {
  final reste = limite.difference(DateTime.now());
  return reste.isNegative ? Duration.zero : reste;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Local Notifications
  NotificationService.initializeLocalNotifications();

  final limite = DateTime.now().add(_budgetDemarrage);

  // L'initialisation de Supabase a disparu d'ici, avec la lecture de
  // SUPABASE_URL et SUPABASE_ANON_KEY.
  //
  // Le mobile ne parlait plus à Supabase que pour une chose : déposer la photo
  // de profil dans le seau « avatars », depuis trois écrans. Cela lui coûtait
  // d'embarquer une clé — et celle qui avait été rangée sous le nom
  // « SUPABASE_ANON_KEY » était en réalité la clé service_role, qui passe outre
  // toutes les règles d'accès de la base et se lit dans l'APK par un simple
  // décompactage. La photo emprunte désormais la route /upload du serveur des
  // livres, comme les couvertures : plus aucune clé Supabase dans
  // l'application.
  //
  // Les adresses supabase.co déjà enregistrées restent lisibles : ce sont de
  // simples URL publiques, aucun client n'est nécessaire pour les afficher
  // (voir ApiRoutes.sanitizeImageUrl, qui les laisse passer telles quelles).

  // Session expirée (401 sur une route métier) : purger la session locale et
  // ramener l'utilisateur à l'écran de connexion, quelle que soit la page
  // depuis laquelle la requête a été émise.
  ApiClient.onUnauthorized = _handleSessionExpired;

  // Liens de recommandation : https://<domaine>/book/<id> doit ouvrir la fiche
  // du livre plutôt qu'un navigateur.
  DeepLinkService.instance.onLivreDemande = _ouvrirLivreDepuisLien;
  unawaited(DeepLinkService.instance.demarrer());

  // Sans ces données, tout DateFormat portant une locale explicite lève une
  // LocaleDataException à l'affichage (cas déjà présent dans la page de détail
  // d'un événement, qui formate en 'fr_FR').
  await _preparer(
    'formats de date',
    limite,
    () => initializeDateFormatting('fr_FR', null),
  );
  Intl.defaultLocale = 'fr_FR';

  // Le mode de thème est lu AVANT le premier rendu : sans cela la première
  // frame s'affiche dans la palette par défaut puis bascule, et les écrans qui
  // lisent AppColors au moment de leur construction restent sur l'ancienne.
  var savedThemeMode = ThemeProvider.defaultThemeMode;
  await _preparer('thème', limite, () async {
    savedThemeMode = await ThemeProvider.loadSavedMode();
  });

  // Branche la lecture a voix haute au systeme : notification, commandes sur
  // l'ecran verrouille, boutons du casque. Sans elle, la synthese s'arrete des
  // que l'application passe en arriere-plan. Un echec n'empeche pas le
  // demarrage : la lecture fonctionne alors ecran allume, comme avant.
  //
  // AudioService.init lie un service de premier plan Android : il rend la main
  // quand le systeme le veut bien, et son try interne ne protege que des
  // exceptions, pas d'une attente sans fin.
  await _preparer('lecture audio', limite, demarrerLectureAudio);

  _avertirSiAucunServeurConfigure();
  _avertirSiTraficEnClair();

  runApp(MyApp(initialThemeMode: savedThemeMode));
}

/// Dit tout haut qu'aucune adresse de serveur n'a été fournie à la compilation.
///
/// L'adresse de production ne figure plus dans les sources — le dépôt mobile est
/// public. `ApiRoutes.host` retombe donc sur « localhost », et l'application ne
/// joint plus rien : chaque appel échoue par un « Connection refused » sur le
/// port 8083, un message qui accuse le réseau alors qu'il ne manque qu'un
/// drapeau de compilation.
///
/// Le diagnostic a déjà coûté deux lancements. Il tient en une ligne, et cette
/// ligne cite la commande exacte — le prochain qui la lira n'aura pas à
/// retrouver une conversation vieille de six mois.
///
/// Sur un ÉMULATEUR Android, « localhost » désigne l'émulateur lui-même : même
/// un serveur lancé sur le poste de développement resterait injoignable. C'est
/// « 10.0.2.2 » qu'il faut écrire dans ce cas-là, jamais « localhost ».
void _avertirSiAucunServeurConfigure() {
  if (ApiRoutes.host != 'localhost') return;
  debugPrint(
    '\n'
    '┌───────────────────────────────────────────────────────────────────┐\n'
    '│  AUCUNE ADRESSE DE SERVEUR : rien ne sera chargé.                 │\n'
    '│                                                                   │\n'
    '│  Relancez avec le fichier de configuration :                      │\n'
    '│                                                                   │\n'
    '│    flutter run --dart-define-from-file=dart_define.json           │\n'
    '│                                                                   │\n'
    '│  (dart_define.json n\'est pas suivi par Git — recopiez             │\n'
    '│   dart_define.example.json si vous ne l\'avez pas encore.)         │\n'
    '└───────────────────────────────────────────────────────────────────┘\n',
  );
}

/// Dit tout haut que l'application parle EN CLAIR à une adresse publique.
///
/// L'APPLICATION EST LE CLIENT QU'UN CERTIFICAT N'ATTEINT PAS. Les deux
/// serveurs Go écoutent aujourd'hui 8083 et 8084 en direct, hors du proxy :
/// l'application les joint sans passer par lui, donc tout ce que le proxy porte
/// — le plafond de téléversement, une éventuelle limitation de débit, un WAF,
/// et surtout le TLS — lui est facultatif. Un jeton de session, un mot de passe
/// et un OTP traversent le réseau lisibles par qui écoute le Wi-Fi.
///
/// Le piège est de calendrier, et il est sérieux. Le jour où le certificat sera
/// posé sur le 443, le site passera en https d'un simple rechargement ;
/// l'application, elle, continuera de parler en clair sur 8083/8084 tant que
/// l'APK n'aura pas été RECONSTRUIT avec la nouvelle adresse — et un APK déjà
/// installé sur un téléphone ne se rattrape pas à distance. La reconstruction
/// et la publication de la nouvelle version viennent donc AVANT l'annonce du
/// passage en HTTPS, jamais après : sinon la plateforme aurait l'air corrigée
/// alors que la majorité de son trafic serait restée en clair.
///
/// LA BASCULE NE DEMANDE PAS UNE LIGNE DE CODE. Toutes les constantes
/// d'`ApiRoutes` sont « origine + chemin », et les deux proxys routent déjà
/// l'ensemble des chemins que l'application appelle : /auth/*, /utilisateurs/*
/// vers 8083 ; /api/* et /upload vers 8084 (space-learn.conf, deploy/Caddyfile).
/// Il suffit d'écrire la même origine, sans port, dans les deux variables de
/// `dart_define.json` :
///
///     "API_BASE_URL":     "https://api.mondomaine.tld",
///     "API_BASE_URL_GIN": "https://api.mondomaine.tld"
///
/// L'avertissement ne parle que d'une adresse PUBLIQUE en http. « localhost »,
/// « 10.0.2.2 » (le poste de développement vu depuis l'émulateur) et les
/// adresses de réseau local sont le quotidien du développement : les signaler
/// ferait du bruit, et le bruit finit par cacher le signal. Il ne s'affiche
/// qu'en débogage, pour la même raison — un `debugPrint` ne sert à rien dans un
/// APK distribué.
///
/// CE QUI VEUT DIRE QUE CE RAPPEL-CI NE VOIT JAMAIS CELUI QUI PUBLIE. Tout ce
/// qu'il dit s'adresse pourtant à la personne qui tape
/// `flutter build apk --release`, c'est-à-dire à la seule qui puisse agir. Le
/// même contrôle est donc repris dans `run.ps1` (action `release`), juste avant
/// la construction : il y relit `dart_define.json` et demande confirmation
/// plutôt que de laisser partir en silence un APK qui parle en clair. Les deux
/// appliquent la même règle d'adresse privée ; si l'une change, l'autre doit
/// suivre.
void _avertirSiTraficEnClair() {
  if (!kDebugMode) return;

  for (final adresse in {ApiRoutes.baseUrl, ApiRoutes.baseUrlsGin}) {
    final uri = Uri.tryParse(adresse);
    if (uri == null || uri.scheme != 'http') continue;
    if (_estUneAdresseDeDeveloppement(uri.host)) continue;

    debugPrint(
      '\n'
      '┌───────────────────────────────────────────────────────────────────┐\n'
      '│  TRAFIC EN CLAIR vers une adresse publique.                       │\n'
      '│                                                                   │\n'
      '│    $adresse\n'
      '│                                                                   │\n'
      '│  Jetons, mots de passe et OTP circulent lisibles, et le port       │\n'
      '│  direct court-circuite le proxy (plafond de téléversement, quota). │\n'
      '│                                                                   │\n'
      '│  Le jour du HTTPS : reconstruire l\'APK sur                        │\n'
      '│  https://<domaine> SANS port — AVANT d\'annoncer le passage,       │\n'
      '│  un APK déjà installé continuera d\'appeler 8083/8084 en clair.    │\n'
      '└───────────────────────────────────────────────────────────────────┘\n',
    );
    return; // Une fois suffit : les deux adresses ont la même origine.
  }
}

/// Cette adresse est-elle celle d'un poste de développement ?
///
/// Le http y est normal et sans conséquence : rien ne sort de la machine ou du
/// réseau local. Seule une adresse routable sur Internet mérite l'avertissement.
bool _estUneAdresseDeDeveloppement(String hote) {
  if (hote.isEmpty) return true;

  const machineLocale = {
    'localhost',
    '127.0.0.1',
    '::1',
    // L'émulateur Android voit le poste de développement à cette adresse-là,
    // jamais à « localhost », qui y désigne l'émulateur lui-même.
    '10.0.2.2',
    '10.0.3.2', // Genymotion.
  };
  if (machineLocale.contains(hote)) return true;
  if (hote.endsWith('.local')) return true;

  // Réseaux privés (RFC 1918) : le téléphone et le poste sur le même Wi-Fi.
  //
  // Le découpage en quatre nombres se fait UNE fois, et les trois plages se
  // testent dessus. Les deux premières se contentaient d'un `startsWith('10.')`
  // et d'un `startsWith('192.168.')` sur la chaîne d'hôte : un nom de domaine
  // public tel que « 10.exemple.ci » — improbable, mais parfaitement légal en
  // DNS — passait alors pour un réseau privé et faisait taire l'avertissement.
  // La plage 172.16-31, elle, découpait déjà correctement. Le commentaire
  // ci-dessus promet des ADRESSES ; la fonction en teste maintenant.
  final octets = hote.split('.');
  if (octets.length != 4) return false;
  final nombres = octets.map(int.tryParse).toList();
  if (nombres.any((n) => n == null || n < 0 || n > 255)) return false;

  if (nombres[0] == 10) return true;
  if (nombres[0] == 192 && nombres[1] == 168) return true;
  if (nombres[0] == 172 && nombres[1]! >= 16 && nombres[1]! <= 31) return true;

  return false;
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// LE LIVRE DEMANDÉ PAR UN LIEN, QUAND L'ÉCRAN N'EXISTE PAS ENCORE.
///
/// LE DÉFAUT, ET C'ÉTAIT LE CAS NORMAL DU PARTAGE. `_ouvrirLivreDepuisLien`
/// abandonnait en silence quand le navigateur n'avait pas d'état — un simple
/// `return`. Or c'est précisément la situation d'un lien qui LANCE
/// l'application : `DeepLinkService.demarrer()` part sans être attendu (voir
/// plus haut, `unawaited`), son `getInitialLink()` est un appel de canal de
/// plateforme qui rend la main en quelques millisecondes, et pendant ce temps
/// `main` charge encore les formats de date, le thème et le service audio.
/// `navigatorKey.currentState` ne vaut quelque chose qu'une fois `MaterialApp`
/// construit, donc bien après.
///
/// Conséquence exacte : un lien reçu par quelqu'un qui n'avait PAS déjà
/// l'application ouverte l'ouvrait sur l'accueil, jamais sur le livre. C'est
/// le cas ordinaire d'une recommandation envoyée par message — celui pour
/// lequel tout ce mécanisme existe. Le lien reçu application déjà ouverte, lui,
/// fonctionnait : le défaut ne se voyait donc pas en développement, où l'on a
/// toujours l'application sous les yeux.
///
/// On mémorise au lieu de jeter. Un seul emplacement suffit : deux liens ne se
/// suivent pas d'assez près pour se bousculer, et si cela arrivait, c'est le
/// dernier demandé qui compte.
String? _livreDemandeEnAttente;

/// Ouvre la fiche d'un livre reçu par lien de recommandation.
///
/// L'écran de chargement est empilé sur la navigation en cours plutôt que de la
/// remplacer : le lecteur revient d'un simple retour là où il en était.
void _ouvrirLivreDepuisLien(String livreId) {
  final navigator = navigatorKey.currentState;
  if (navigator == null) {
    _livreDemandeEnAttente = livreId;
    return;
  }

  navigator.push(
    MaterialPageRoute(builder: (_) => BookLoaderPage(livreId: livreId)),
  );
}

/// Ouvre le livre mis de côté, s'il y en a un et si l'écran est prêt.
///
/// APPELÉE APRÈS LA PREMIÈRE IMAGE, et non pendant la construction : pousser
/// une route depuis un `build` lève une exception. D'où le report à la fin de
/// la frame.
///
/// SEULEMENT AVEC UNE SESSION OUVERTE, et c'est délibéré. Sans compte,
/// l'application affiche la page de bienvenue ; y empiler le chargeur d'un
/// livre ferait partir des requêtes que le serveur refuse, et le refus
/// déclenche la déconnexion, qui renvoie sur l'écran de connexion en vidant la
/// pile. Le destinataire verrait le livre s'ouvrir puis disparaître. Tant que
/// l'application n'a pas de parcours visiteur, le lien reste en attente : ce
/// n'est pas pire qu'avant — il était jeté — et le jour où ce parcours
/// existera, c'est ici qu'il se branchera.
void _ouvrirLeLivreEnAttente() {
  if (_livreDemandeEnAttente == null) return;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final id = _livreDemandeEnAttente;
    if (id == null) return;
    if (navigatorKey.currentState == null) return;
    _livreDemandeEnAttente = null;
    _ouvrirLivreDepuisLien(id);
  });
}

/// Fin de session : purge, retour à la connexion, et LA RAISON quand il y en a
/// une.
///
/// `/auth/refresh` a deux refus et ils ne s'expliquent pas de la même façon.
/// Le 401 dit que le jeton est mort, et « Votre session a expiré » suffit. Le
/// 403 dit que le COMPTE est fermé, et le serveur y écrit la raison ET
/// l'adresse où écrire (space_learn_auth, controllers/refresh.go). Les deux
/// sortaient ici par la même phrase générique : la personne était mise dehors
/// sans savoir pourquoi ni à qui s'adresser — à l'instant précis où elle perd
/// « Aide & FAQ », seul endroit de l'application qui portait cette adresse.
///
/// UN MESSAGE FURTIF NE CONVIENT PAS À CE REFUS-LÀ : on ne recopie pas une
/// adresse électronique en quatre secondes, et c'est le raisonnement que
/// l'écran de connexion tient déjà pour les 403 de `/auth/login`. Le refus de
/// droit prend donc un dialogue qu'on ferme soi-même, et il n'offre AUCUN
/// « Réessayer » — le jeton est révoqué, réessayer ne peut pas aboutir.
/// L'expiration ordinaire, elle, reste un message furtif.
///
/// Voir [ApiClient.motifDeLaFinDeSession].
Future<void> _handleSessionExpired() async {
  final motif = ApiClient.motifDeLaFinDeSession;
  await SessionService.terminer();

  final navigator = navigatorKey.currentState;
  if (navigator == null) return;

  await navigator.pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const LoginPage()),
    (route) => false,
  );

  final messengerContext = navigatorKey.currentContext;
  if (messengerContext == null || !messengerContext.mounted) return;

  if (motif != null && motif.trim().isNotEmpty) {
    await AppNotifications.showPremiumDialog(
      messengerContext,
      title: "Connexion refusée",
      message: motif,
      confirmText: "Fermer",
      isError: true,
    );
    return;
  }

  AppNotifications.showSnackBar(
    messengerContext,
    message: 'Votre session a expiré. Veuillez vous reconnecter.',
    isError: true,
  );
}

class MyApp extends StatefulWidget {
  final ThemeMode initialThemeMode;

  const MyApp({
    super.key,
    this.initialThemeMode = ThemeProvider.defaultThemeMode,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  /// Ce que le démarrage s'autorise à attendre du réseau, en tout.
  static const Duration _delaiDemarrage = Duration(seconds: 10);

  String? _selectedProfile;
  String? _selectedProfileRole;
  UserModel? _user;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  /// Ce que l'application sait au démarrage.
  ///
  /// Toute exception ramenait ici à la page de bienvenue, c'est-à-dire à
  /// « vous n'êtes pas connecté ». Or l'échec le plus courant n'est pas une
  /// session finie : c'est un réseau coupé. Le lecteur qui ouvrait
  /// l'application dans une zone mal couverte se croyait déconnecté et
  /// ressaisissait son mot de passe, alors que sa session était intacte dans
  /// le coffre.
  ///
  /// Une session réellement refusée par le serveur n'a pas besoin de ce
  /// chemin : ApiClient la purge et ramène lui-même à la connexion.
  ///
  /// L'attente est bornée. Rien ne la bornait : ni `getUser`, ni `getProfils`,
  /// ni le client HTTP en dessous — seul `/auth/refresh` porte un délai. Un
  /// serveur qui accepte la connexion sans jamais répondre laissait donc
  /// l'application sur son écran de lancement, indéfiniment et sans recours :
  /// cette méthode n'est appelée qu'une fois, et le splash n'offre aucun
  /// bouton. Passé le délai, on ouvre avec ce qu'on sait localement, comme
  /// pour n'importe quel autre échec réseau.
  Future<void> _loadInitialData() async {
    try {
      await _relireLaSession();
    } catch (e) {
      // Dernier filet, et il manquait. Toute exception qui sort d'ici laisse
      // _isLoading à true, donc l'écran de lancement affiché pour toujours :
      // rien ne rappelle cette méthode et le splash n'a pas de bouton.
      //
      // Deux lectures se font hors de tout try : celle du jeton, avant le
      // premier, et celles du repli, dans le catch. Le coffre chiffré est le
      // cas concret — sur Android, une clé Keystore abîmée par une
      // restauration de sauvegarde fait lever TokenStorage.getToken.
      //
      // Sans rien de lisible, la page de bienvenue est le seul choix sûr :
      // elle mène à la connexion, qui réécrira une session propre.
      debugPrint('Démarrage : session illisible — $e');
      _presenter(user: null, profile: null, role: null);
    }
  }

  Future<void> _relireLaSession() async {
    final token = await TokenStorage.getToken();

    // Personne n'est connecté : il n'y a rien à relire.
    if (token == null || token.isEmpty) {
      _presenter(user: null, profile: null, role: null);
      return;
    }

    // Un seul budget pour tout le démarrage, et non un délai par appel : le
    // chemin en comporte deux à la suite, qui cumuleraient leurs attentes.
    final limite = DateTime.now().add(_delaiDemarrage);

    try {
      final user = await AuthService().getUser(token).timeout(_reste(limite));
      final profile = await ProfileStorage.getSelectedProfile();
      _presenter(
        user: user,
        profile: user?.profilId.isNotEmpty == true ? user!.profilId : profile,
        role: await _roleAJour(user, profile, limite),
      );
    } catch (e) {
      // Le serveur n'a pas répondu. On garde la session et ce qu'on sait
      // localement : l'application s'ouvre là où elle s'était fermée, et les
      // écrans qui ont besoin du réseau afficheront leur propre échec.
      debugPrint('Profil non relu au démarrage : $e');
      _presenter(
        user: await _profilLocal(),
        profile: await ProfileStorage.getSelectedProfile(),
        role: await ProfileStorage.getSelectedProfileRole(),
      );
    }
  }

  /// Ce qu'il reste du budget de démarrage. Jamais négatif : `timeout` le
  /// refuserait.
  static Duration _reste(DateTime limite) {
    final reste = limite.difference(DateTime.now());
    return reste.isNegative ? Duration.zero : reste;
  }

  void _presenter({UserModel? user, String? profile, String? role}) {
    if (!mounted) return;
    setState(() {
      _user = user;
      _selectedProfile = profile;
      _selectedProfileRole = role;
      _isLoading = false;
    });
  }

  /// Le rôle, relu du serveur quand le profil a changé.
  ///
  /// Il était toujours pris dans le stockage local, jamais dans la réponse qui
  /// venait pourtant d'arriver : un profil modifié côté serveur — un lecteur
  /// devenu auteur — n'était vu qu'à la reconnexion suivante.
  ///
  /// La résolution demande la liste des profils, donc un appel réseau : on ne
  /// la fait que si le profil a effectivement bougé, et un échec laisse
  /// simplement le rôle connu en place.
  Future<String?> _roleAJour(
    UserModel? user,
    String? profilConnu,
    DateTime limite,
  ) async {
    final memorise = await ProfileStorage.getSelectedProfileRole();
    if (user == null || user.profilId.isEmpty || user.profilId == profilConnu) {
      return memorise;
    }

    try {
      final profils = await ProfileService().getProfils().timeout(
        _reste(limite),
      );
      final trouve = profils.firstWhere(
        (p) => p.id.trim().toLowerCase() == user.profilId.trim().toLowerCase(),
        orElse: () => ProfilModel(id: '', libelle: ''),
      );
      if (trouve.id.isEmpty) return memorise;

      final role = trouve.libelle.toLowerCase();
      await ProfileStorage.saveSelectedProfileRole(role);
      await ProfileStorage.saveSelectedProfile(user.profilId);
      return role;
    } catch (e) {
      debugPrint('Rôle non rafraîchi : $e');
      return memorise;
    }
  }

  /// Le peu qu'on sait du compte sans le serveur, pour ouvrir l'application.
  ///
  /// Rend `null` s'il n'y a même pas de nom mémorisé : sans rien à afficher,
  /// mieux vaut la page de bienvenue qu'un écran d'accueil vide.
  Future<UserModel?> _profilLocal() async {
    final nom = await TokenStorage.getUserName();
    final id = await TokenStorage.getUserId();
    final profil = await ProfileStorage.getSelectedProfile();
    if (nom == null || nom.isEmpty) return null;

    return UserModel(
      id: id ?? '',
      profilId: profil ?? '',
      nomComplet: nom,
      email: '',
      isProfileComplete: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    AppColors.suivreLeTheme(context);
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(initialMode: widget.initialThemeMode),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          // Point de synchronisation unique entre le thème Flutter et la
          // palette globale AppColors. Il doit rester ici, au-dessus de
          // MaterialApp : toute reconstruction déclenchée par un changement de
          // thème passe par ce builder, donc tous les écrans reconstruits
          // ensuite lisent la bonne palette. C'est ce qui manquait quand
          // l'en-tête et la barre de navigation restaient sombres en mode clair.
          AppColors.isDark = themeProvider.isDarkMode;

          // La barre de statut système ne suit pas le thème toute seule : en
          // mode clair, l'en-tête devient blanc et il faut des icônes sombres
          // pour qu'elles restent lisibles.
          SystemChrome.setSystemUIOverlayStyle(
            SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: themeProvider.isDarkMode
                  ? Brightness.light
                  : Brightness.dark,
              statusBarBrightness: themeProvider.isDarkMode
                  ? Brightness.dark
                  : Brightness.light,
              systemNavigationBarColor: AppColors.scaffoldBackground,
              systemNavigationBarIconBrightness: themeProvider.isDarkMode
                  ? Brightness.light
                  : Brightness.dark,
            ),
          );

          return MaterialApp(
            navigatorKey: navigatorKey,
            title: 'Space Learn',
            themeMode: themeProvider.themeMode,
            // Chaque ThemeData décrit sa propre palette (cf. AppTheme).
            theme: AppTheme.clair,
            darkTheme: AppTheme.sombre,
            debugShowCheckedModeBanner: false,
            home: _isLoading ? const SplashScreen() : _getHomeWidget(),
          );
        },
      ),
    );
  }

  Widget _getHomeWidget() {
    // Personne connectée : on présente d'abord le produit.
    //
    // L'application ouvrait sur « Qui êtes-vous ? » — une question posée à
    // quelqu'un qui n'avait encore rien vu, et que même un lecteur déjà
    // inscrit devait traverser avant d'atteindre la connexion. La page de
    // bienvenue mène aux deux chemins, et le choix du profil est redevenu ce
    // qu'il est : la première étape de la création de compte.
    if (_user == null) {
      return const BienvenuePage();
    }

    // Connecté mais sans profil : ce cas subsiste pour les comptes créés avant
    // que le choix soit intégré à l'inscription.
    if (_selectedProfile == null) {
      return const ProfilPage();
    }

    /* L'accueil d'un compte ouvert est rendu : le lien mis de côté au
       démarrage peut enfin aboutir. Voir [_ouvrirLeLivreEnAttente]. */
    _ouvrirLeLivreEnAttente();

    final role = _selectedProfileRole?.toLowerCase() ?? '';
    if (role.contains('lecteur')) {
      return lecteurHome.HomePageLecteur(
        profileId: _selectedProfile!,
        userName: _user!.nomComplet,
      );
    } else if (estParcoursAuteur(role)) {
      return ecrivainHome.HomePageAuteur(
        key: ecrivainHome.HomePageAuteur.navKey,
        profileId: _selectedProfile!,
        userName: _user!.nomComplet,
      );
    }

    return const ProfilPage();
  }
}
