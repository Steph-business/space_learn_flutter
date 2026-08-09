import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/cart_provider.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/notification_provider.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/notificationService.dart';
import 'package:space_learn_flutter/core/services/api_client.dart';
import 'package:space_learn_flutter/core/themes/theme_provider.dart';
import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:space_learn_flutter/core/space_learn/pages/principales/auth/profil.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/auth/login.dart';
import 'package:space_learn_flutter/core/utils/token_storage.dart';
import 'package:space_learn_flutter/core/utils/profile_storage.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/user_model.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/authServices.dart';

import 'package:space_learn_flutter/core/space_learn/pages/principales/ecrivain/accueil_auteur_page.dart'
    as ecrivainHome;
import 'package:space_learn_flutter/core/space_learn/pages/principales/lecteur/accueil_lecteur_page.dart'
    as lecteurHome;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Local Notifications
  NotificationService.initializeLocalNotifications();

  try {
    const supabaseUrl = String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'https://uqmydsydlkwxcfcdtsbu.supabase.co',
    );
    const supabaseAnonKey = String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue: '***CLE_SUPABASE_RETIREE***',
    );
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  } catch (e, stackTrace) {
    debugPrint('Supabase init exception: $e\n$stackTrace');
  }

  // Session expirée (401 sur une route métier) : purger la session locale et
  // ramener l'utilisateur à l'écran de connexion, quelle que soit la page
  // depuis laquelle la requête a été émise.
  ApiClient.onUnauthorized = _handleSessionExpired;

  runApp(const MyApp());
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> _handleSessionExpired() async {
  await TokenStorage.clearToken();
  await ProfileStorage.clearSelectedProfile();
  await ProfileStorage.clearSelectedProfileRole();

  final navigator = navigatorKey.currentState;
  if (navigator == null) return;

  await navigator.pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const LoginPage()),
    (route) => false,
  );

  final messengerContext = navigatorKey.currentContext;
  if (messengerContext != null && messengerContext.mounted) {
    ScaffoldMessenger.of(messengerContext).showSnackBar(
      const SnackBar(
        content: Text('Votre session a expiré. Veuillez vous reconnecter.'),
      ),
    );
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String? _selectedProfile;
  String? _selectedProfileRole;
  UserModel? _user;
  bool _isRegistered = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final token = await TokenStorage.getToken();
      final isRegistered = await ProfileStorage.getIsRegisteredUser();
      
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
              _isRegistered = isRegistered;
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
          _isRegistered = isRegistered;
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
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            navigatorKey: navigatorKey,
            title: 'Space Learn',
            themeMode: themeProvider.themeMode,
            theme: ThemeData(
              brightness: Brightness.light,
              primarySwatch: Colors.orange,
              primaryColor: AppColors.primary,
              scaffoldBackgroundColor: AppColors.scaffoldBackground,
              colorScheme: ColorScheme.fromSeed(
                seedColor: AppColors.primary,
                brightness: Brightness.light,
                primary: AppColors.primary,
                secondary: AppColors.secondary,
              ),
            ),
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              primarySwatch: Colors.orange,
              primaryColor: AppColors.primary,
              scaffoldBackgroundColor: AppColors.scaffoldBackground,
              colorScheme: ColorScheme.fromSeed(
                seedColor: AppColors.primary,
                brightness: Brightness.dark,
                primary: AppColors.primary,
                secondary: AppColors.secondary,
              ),
            ),
            debugShowCheckedModeBanner: false,
            home: _isLoading
                ? const Scaffold(body: Center(child: CircularProgressIndicator()))
                : _getHomeWidget(),
          );
        },
      ),
    );
  }

  Widget _getHomeWidget() {
    if (_user == null) {
      return _isRegistered ? const LoginPage() : const ProfilPage();
    }

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