import 'package:flutter/material.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/auth/profil.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/lecteur/homePageLecteur.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Space Learn',
      theme: ThemeData(primarySwatch: Colors.orange),
      home: const ProfilPage(
        // ID de profil et nom d'utilisateur factices pour le développement
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}
