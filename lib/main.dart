import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/cart_provider.dart';
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
import 'package:space_learn_flutter/core/space_learn/data/dataServices/authServices.dart';

import 'package:space_learn_flutter/core/space_learn/pages/principales/ecrivain/accueil_auteur_page.dart'
    as ecrivainHome;
import 'package:space_learn_flutter/core/space_learn/pages/principales/lecteur/accueil_lecteur_page.dart'
    as lecteurHome;
import 'package:space_learn_flutter/core/widgets/splash_screen.dart';
import 'package:space_learn_flutter/core/services/lecture_audio_handler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Local Notifications
  NotificationService.initializeLocalNotifications();

  try {
    const supabaseUrl = String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'https://uqmydsydlkwxcfcdtsbu.supabase.co',
    );
    // La clé anon est publique par nature, mais elle n'a pas de valeur par
    // défaut : elle doit être fournie au build via
    // --dart-define=SUPABASE_ANON_KEY=... (ou --dart-define-from-file).
    const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  } catch (e, stackTrace) {
    debugPrint('Supabase init exception: $e\n$stackTrace');
  }

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
  await initializeDateFormatting('fr_FR', null);
  Intl.defaultLocale = 'fr_FR';

  // Le mode de thème est lu AVANT le premier rendu : sans cela la première
  // frame s'affiche dans la palette par défaut puis bascule, et les écrans qui
  // lisent AppColors au moment de leur construction restent sur l'ancienne.
  final savedThemeMode = await ThemeProvider.loadSavedMode();

  // Branche la lecture a voix haute au systeme : notification, commandes sur
  // l'ecran verrouille, boutons du casque. Sans elle, la synthese s'arrete des
  // que l'application passe en arriere-plan. Un echec n'empeche pas le
  // demarrage : la lecture fonctionne alors ecran allume, comme avant.
  await demarrerLectureAudio();

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
  String? _selectedProfile;
  String? _selectedProfileRole;
  UserModel? _user;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final token = await TokenStorage.getToken();

      if (token != null && token.isNotEmpty) {
        final authService = AuthService();
        final user = await authService.getUser(token);
        if (user != null) {
          final profile = await ProfileStorage.getSelectedProfile();
          final role = await ProfileStorage.getSelectedProfileRole();
          if (mounted) {
            setState(() {
              _user = user;
              _selectedProfile = profile;
              _selectedProfileRole = role;
              _isLoading = false;
            });
          }
          return;
        }
      }
      if (mounted) {
        setState(() {
          _selectedProfile = null;
          _selectedProfileRole = null;
          _user = null;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _selectedProfile = null;
          _selectedProfileRole = null;
          _user = null;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    AppColors.suivreLeTheme(context);
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartProvider()),
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
    } else if (role.contains('auteur') ||
        role.contains('ecrivain') ||
        role.contains('administrateur') ||
        role.contains('éditeur')) {
      return ecrivainHome.HomePageAuteur(
        key: ecrivainHome.HomePageAuteur.navKey,
        profileId: _selectedProfile!,
        userName: _user!.nomComplet,
      );
    }

    return const ProfilPage();
  }
}
