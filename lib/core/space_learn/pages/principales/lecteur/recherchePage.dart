import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';

import 'package:space_learn_flutter/core/themes/layout/recherche_bar.dart';
import '../../../../themes/app_colors.dart';
import '../../../../themes/layout/navBarAll.dart';
import '../../widgets/lecteur/recherche/categorie_filtre.dart';
import '../../widgets/lecteur/recherche/resultat_liste.dart';

class RecherchePageLecteur extends StatelessWidget {
  const RecherchePageLecteur({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 250, 249, 246),
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
                  const Text(
                    "Recherche",
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  // Widget : barre de recherche
                  const CustomSearchBar(),

                  const SizedBox(height: 20),

                  // Widget : catégories ou filtres
                  const CategorieFiltres(),

                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
