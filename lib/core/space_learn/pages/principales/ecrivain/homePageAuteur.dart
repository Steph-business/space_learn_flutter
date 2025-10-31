import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/auteur/home/action_rapide.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/auteur/home/livre_recent.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/auteur/home/notification_recent.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/auteur/home/revenus.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/auteur/home/statistique.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/lecteur/markeplace/section_titre.dart';
import 'package:space_learn_flutter/core/themes/layout/navBarAll.dart';
import 'package:space_learn_flutter/core/themes/layout/navBarAuteur.dart';

class HomePageAuteur extends StatefulWidget {
  // L'ID unique de l'utilisateur, essentiel pour les requêtes API
  final String profileId;
  // Le nom de l'utilisateur est maintenant un paramètre
  final String userName;

  const HomePageAuteur({
    super.key,
    required this.profileId,
    this.userName = 'Auteur',
  });

  @override
  State<HomePageAuteur> createState() => _HomePageAuteurState();
}

class _HomePageAuteurState extends State<HomePageAuteur> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Header fixe
          NavBarAll(userName: widget.userName),
          // Contenu défilable
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Statistique(),
                  const SizedBox(height: 20),
                  const SectionTitle(title: "Action rapides"),
                  const AuteurActionsRapide(),
                  const SizedBox(height: 50),

                  // Revenus
                  const SectionTitle(title: "Revenus mensuels"),
                  const SizedBox(height: 20),
                  const Revenus(),
                  const SizedBox(height: 50),

                  // Livres récents
                  const SectionTitle(title: "Mes livres récents"),
                  const SizedBox(height: 20),
                  const AuteurLivresRecents(),

                  const SizedBox(height: 50),
                  const SectionTitle(title: "Notifications récentes"),
                  const SizedBox(height: 20),
                  const RecentNotificationsPage(),
                  const SizedBox(
                    height: 100,
                  ), // Espace pour le menu fixe en bas
                ],
              ),
            ),
          ),
          // Menu fixe en bas
          const NavBarAuteur(),
        ],
      ),
    );
  }
}
