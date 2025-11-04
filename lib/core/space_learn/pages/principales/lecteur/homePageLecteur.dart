import 'package:flutter/material.dart';
import '../../../../themes/app_colors.dart';
import '../../../../themes/app_text_styles.dart';
import '../../layout/navBarLecteur.dart';
import '../../layout/navBarAll.dart';
import '../../widgets/lecteur/home/stats_section.dart';
import '../../widgets/lecteur/home/continue_reading_section.dart';
import '../../widgets/lecteur/home/recommendations_section.dart';
import '../../widgets/lecteur/home/recent_activity_section.dart';

class HomePageLecteur extends StatefulWidget {
  // L'ID unique de l'utilisateur, essentiel pour les requêtes API
  final String profileId;
  // Le nom de l'utilisateur est maintenant un paramètre
  final String userName;

  const HomePageLecteur({
    super.key,
    required this.profileId,
    this.userName = 'Utilisateur',
  });

  @override
  State<HomePageLecteur> createState() => _HomePageLecteurState();
}

class _HomePageLecteurState extends State<HomePageLecteur> {
  @override
  Widget build(BuildContext context) {
    return MainNavBar(
      child: Scaffold(
        backgroundColor: const Color.fromARGB(255, 250, 249, 246),
        body: Column(
          children: [
            // En-tête fixe
            NavBarAll(userName: widget.userName),
            // Contenu défilable
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const StatsSection(), // TODO: Passer les données des stats
                    const SizedBox(height: 24),
                    // Continue Reading Section
                    _buildSectionTitle('Continuer la lecture'),
                    const SizedBox(height: 16),
                    const ContinueReadingSection(), // TODO: Passer les données de lecture
                    const SizedBox(height: 24),
                    // Recommendations Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSectionTitle('Recommandations'),
                        TextButton(
                          onPressed: () {},
                          child: const Text('Voir tout'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const RecommendationsSection(),
                    const SizedBox(height: 28),
                    // Recent Activity Section
                    _buildSectionTitle('Activité récente'),
                    const SizedBox(height: 6),
                    const RecentActivitySection(),
                    const SizedBox(
                      height: 8,
                    ), // Espace final pour éviter que le contenu touche le bas
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      ),
    );
  }
}
