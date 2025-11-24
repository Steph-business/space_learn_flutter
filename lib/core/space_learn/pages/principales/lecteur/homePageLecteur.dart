import 'package:flutter/material.dart';

import '../../../../themes/app_colors.dart';
import '../../../../themes/app_text_styles.dart';
import '../../widgets/details/reading_page.dart';
import '../../../../themes/layout/navBarAll.dart';
import '../../../../themes/layout/navBarLecteur.dart';
import '../../widgets/lecteur/home/continue_reading_section.dart';
import '../../widgets/lecteur/home/recent_activity_section.dart';
import '../../widgets/lecteur/home/recommendations_section.dart';
import '../../widgets/lecteur/home/stats_section.dart';
import 'bibliothequePage.dart';
import 'markeplacePage.dart';
import 'teamsPage.dart';

class HomePageLecteur extends StatelessWidget {
  // L'ID unique de l'utilisateur, essentiel pour les requêtes API
  final String profileId;
  // Le nom de l'utilisateur est maintenant un paramètre
  final String userName;

  const HomePageLecteur({
    super.key,
    required this.profileId,
    this.userName = 'Utilisateur',
  });

  // Données fictives pour la démonstration
  Map<String, dynamic> get _sampleBook => {
    'title': "L'art de la simplicité",
    'chapters': [
      {'title': 'Chapitre 1', 'content': 'Contenu du chapitre 1...'},
      {'title': 'Chapitre 2', 'content': 'Contenu du chapitre 2...'},
      {'title': 'Chapitre 3', 'content': 'Contenu du chapitre 3...'},
    ],
  };

  Map<String, dynamic> get _sampleChapter =>
      _sampleBook['chapters'][2]; // Chapitre 3
  int get _sampleChapterIndex => 2;

  @override
  Widget build(BuildContext context) {
    return MainNavBar(
      child: Scaffold(
        key: const PageStorageKey('homePageLecteur'),
        backgroundColor: const Color.fromARGB(255, 250, 249, 246),
        body: Column(
          children: [
            // En-tête fixe
            NavBarAll(userName: userName),
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
                    ContinueReadingSection(
                      book: _sampleBook,
                      chapter: _sampleChapter,
                      chapterIndex: _sampleChapterIndex,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ReadingPage(
                              book: _sampleBook,
                              chapter: _sampleChapter,
                              chapterIndex: _sampleChapterIndex,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    // Recommendations Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSectionTitle('Recommandations'),
                        TextButton(
                          onPressed: () {
                            // Utiliser un callback pour changer l'index de la navbar
                            // Cette approche évite les problèmes de type
                            final navBarElement = context
                                .findAncestorRenderObjectOfType<RenderObject>();
                            if (navBarElement != null) {
                              final navBar = context
                                  .findAncestorWidgetOfExactType<MainNavBar>();
                              if (navBar != null) {
                                final state =
                                    (navBar as StatefulElement).state
                                        as dynamic;
                                if (state != null &&
                                    state._onItemTapped != null) {
                                  state._onItemTapped(
                                    2,
                                  ); // Index 2 pour Marketplace
                                }
                              }
                            }
                          },
                          child: const Text('Voir tout'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const RecommendationsSection(),
                    const SizedBox(height: 28),
                    // Teams Activity Section (moved from Recent Activity)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSectionTitle('Activité Teams'),
                        TextButton(
                          onPressed: () {
                            // Navigation vers la page Teams
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const TeamsPageLecteur(),
                              ),
                            );
                          },
                          child: const Text('Voir tout'),
                        ),
                      ],
                    ),
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
