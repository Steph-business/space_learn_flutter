import 'package:flutter/material.dart';

import 'package:space_learn_flutter/core/space_learn/data/dataServices/authServices.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/profileService.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/profilModel.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/auth/profil.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/lecteur/homePageLecteur.dart';
import 'package:space_learn_flutter/core/utils/tokenStorage.dart';
import 'package:space_learn_flutter/core/utils/profileStorage.dart';

import 'package:space_learn_flutter/core/space_learn/pages/principales/ecrivain/homePageAuteur.dart'
    as ecrivainHome;
import 'package:space_learn_flutter/core/space_learn/pages/principales/lecteur/homePageLecteur.dart'
    as lecteurHome;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Widget? _initialPage;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialPage();
  }

  Future<void> _loadInitialPage() async {
    try {
      final page = await _getInitialPage();
      if (mounted) {
        setState(() {
          _initialPage = page;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _initialPage = const ProfilPage();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _initialPage == null) {
      return MaterialApp(
        title: 'Space Learn',
        theme: ThemeData(primarySwatch: Colors.orange),
        debugShowCheckedModeBanner: false,
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return MaterialApp(
      title: 'Space Learn',
      theme: ThemeData(primarySwatch: Colors.orange),
      debugShowCheckedModeBanner: false,
      home: _initialPage,
    );
  }

  Future<Widget> _getInitialPage() async {
    // Check if user is already logged in
    final token = await TokenStorage.getToken();
    final selectedProfile = await ProfileStorage.getSelectedProfile();

    if (token != null && token.isNotEmpty && selectedProfile != null) {
      // User is logged in, determine which home page to show
      final profileName = selectedProfile.toLowerCase();
      if (profileName.contains('lecteur')) {
        return lecteurHome.HomePageLecteur(
          profileId: selectedProfile,
          userName: 'Lecteur',
        );
      } else if (profileName.contains('auteur') ||
          profileName.contains('ecrivain') ||
          profileName.contains('éditeur')) {
        return const ecrivainHome.HomePageAuteur(
          profileId: '',
          userName: 'Auteur',
        );
      }
    }

    // Default to profile selection page
    return const ProfilPage();
  }
}
