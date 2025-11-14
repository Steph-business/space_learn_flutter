import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';

import '../../../../themes/layout/navBarAll.dart';
import '../../../../themes/layout/recherche_bar.dart';
import '../../widgets/lecteur/markeplace/livre_card.dart';
import '../../widgets/lecteur/markeplace/section_titre.dart';
import '../../widgets/lecteur/markeplace/select_categorie.dart';

class MarketplacePage extends StatelessWidget {
  const MarketplacePage({super.key});

  @override
  Widget build(BuildContext context) {
    final livres = [
      {
        "titre": "L'importance des réseaux",
        "auteur": "Jean Dupont",
        "prix": "12.99 €",
      },
      {
        "titre": "Créer une entreprise",
        "auteur": "Alice Martin",
        "prix": "15.99 €",
      },
      {"titre": "Apprendre Flutter", "auteur": "Sophie K.", "prix": "10.50 €"},
      {"titre": "Introduction à l’IA", "auteur": "Marc D.", "prix": "13.49 €"},
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // En-tête fixe
          const NavBarAll(),
          // Contenu défilable
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Titre principal
                  const SizedBox(height: 10),

                  // Barre de recherche
                  const CustomSearchBar(),

                  const SizedBox(height: 20),

                  // Catégories
                  const SelectCategorie(),

                  const SizedBox(height: 26),

                  // Titre section
                  const SectionTitle(title: "Livres populaires"),

                  const SizedBox(height: 2),

                  // Grille de livres
                  GridView.builder(
                    itemCount: livres.length,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.75,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                        ),
                    itemBuilder: (context, index) {
                      final livre = livres[index];
                      return LivreCard(
                        titre: livre["titre"]!,
                        auteur: livre["auteur"]!,
                        prix: livre["prix"]!,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
