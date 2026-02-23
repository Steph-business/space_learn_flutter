import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:space_learn_flutter/core/space_learn/pages/principales/auth/profil.dart';
import 'package:space_learn_flutter/core/utils/tokenStorage.dart';
import 'package:space_learn_flutter/core/utils/profileStorage.dart';

import 'package:space_learn_flutter/core/space_learn/pages/principales/ecrivain/accueil_auteur_page.dart'
    as ecrivainHome;
import 'package:space_learn_flutter/core/space_learn/pages/principales/lecteur/accueil_lecteur_page.dart'
    as lecteurHome;

Future<void> main() async {
  debugPrint('--- APP STARTING ---');
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('--- BINDING INITIALIZED ---');

  try {
    debugPrint('--- INITIALIZING SUPABASE ---');
    await Supabase.initialize(
      url: 'https://uqmydsydlkwxcfcdtsbu.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVxbXlkc3lkbGt3eGNmY2R0c2J1Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NzYxNDc1MiwiZXhwIjoyMDczMTkwNzUyfQ.DwBlZ_KXwFnO22Bu1a5f_PZcBSrBYWLC2frv-JeXebA',
    );
    debugPrint('--- SUPABASE INITIALIZED ---');
  } catch (e) {
    debugPrint('--- SUPABASE ERROR: $e ---');
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String? _selectedProfile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final token = await TokenStorage.getToken();
      final profile = await ProfileStorage.getSelectedProfile();

      if (mounted) {
        setState(() {
          // On ne garde le profil que si on a un token valide
          _selectedProfile = (token != null && token.isNotEmpty)
              ? profile
              : null;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Space Learn',
      theme: ThemeData(primarySwatch: Colors.orange),
      debugShowCheckedModeBanner: false,
      home: _isLoading
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : _getHomeWidget(),
    );
  }

  Widget _getHomeWidget() {
    if (_selectedProfile == null) return const ProfilPage();

    final profileName = _selectedProfile!.toLowerCase();
    if (profileName.contains('lecteur')) {
      return lecteurHome.HomePageLecteur(
        profileId: _selectedProfile!,
        userName: 'Lecteur',
      );
    } else if (profileName.contains('auteur') ||
        profileName.contains('ecrivain') ||
        profileName.contains('éditeur')) {
      return ecrivainHome.HomePageAuteur(
        profileId: _selectedProfile!,
        userName: 'Auteur',
      );
    }

    return const ProfilPage();
  }
}
