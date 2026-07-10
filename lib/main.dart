import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/cart_provider.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/notification_provider.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/notificationService.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:space_learn_flutter/core/space_learn/pages/principales/auth/profil.dart';
import 'package:space_learn_flutter/core/utils/token_storage.dart';
import 'package:space_learn_flutter/core/utils/profile_storage.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/user_model.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/authServices.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/profilePage.dart';

import 'package:space_learn_flutter/core/space_learn/pages/principales/ecrivain/accueil_auteur_page.dart'
    as ecrivainHome;
import 'package:space_learn_flutter/core/space_learn/pages/principales/lecteur/accueil_lecteur_page.dart'
    as lecteurHome;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Local Notifications
  NotificationService.initializeLocalNotifications();

  try {
    await Supabase.initialize(
      url: 'https://uqmydsydlkwxcfcdtsbu.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVxbXlkc3lkbGt3eGNmY2R0c2J1Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NzYxNDc1MiwiZXhwIjoyMDczMTkwNzUyfQ.DwBlZ_KXwFnO22Bu1a5f_PZcBSrBYWLC2frv-JeXebA',
    );
  } catch (e) {
  }

  runApp(const MyApp());
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatefulWidget {
  const MyApp({super.key});

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
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'Space Learn',
        theme: ThemeData(primarySwatch: Colors.orange),
        debugShowCheckedModeBanner: false,
        home: _isLoading
            ? const Scaffold(body: Center(child: CircularProgressIndicator()))
            : _getHomeWidget(),
      ),
    );
  }

  Widget _getHomeWidget() {
    if (_user == null || _selectedProfile == null) return const ProfilPage();

    if (!_user!.isProfileComplete) {
      return const ProfilePage(forceComplete: true);
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
        profileId: _selectedProfile!,
        userName: _user!.nomComplet,
      );
    }

    return const ProfilPage();
  }
}
