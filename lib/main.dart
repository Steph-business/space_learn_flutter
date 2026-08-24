import 'dart:async';

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
import 'package:supabase_flutter/supabase_flutter.dart';

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

  await _preparer('Supabase', limite, () async {
    const supabaseUrl = String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'https://uqmydsydlkwxcfcdtsbu.supabase.co',
    );
    // La clé anon est publique par nature, mais elle n'a pas de valeur par
    // défaut : elle doit être fournie au build via
    // --dart-define=SUPABASE_ANON_KEY=... (ou --dart-define-from-file).
    const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  });

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

  runApp(MyApp(initialThemeMode: savedThemeMode));
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Ouvre la fiche d'un livre reçu par lien de recommandation.
///
/// L'écran de chargement est empilé sur la navigation en cours plutôt que de la
/// remplacer : le lecteur revient d'un simple retour là où il en était.
void _ouvrirLivreDepuisLien(String livreId) {
  final navigator = navigatorKey.currentState;
  if (navigator == null) return;

  navigator.push(
    MaterialPageRoute(builder: (_) => BookLoaderPage(livreId: livreId)),
  );
}

Future<void> _handleSessionExpired() async {
  await SessionService.terminer();

  final navigator = navigatorKey.currentState;
  if (navigator == null) return;

  await navigator.pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const LoginPage()),
    (route) => false,
  );

  final messengerContext = navigatorKey.currentContext;
  if (messengerContext != null && messengerContext.mounted) {
    AppNotifications.showSnackBar(
      messengerContext,
      message: 'Votre session a expiré. Veuillez vous reconnecter.',
      isError: true,
    );
  }
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
