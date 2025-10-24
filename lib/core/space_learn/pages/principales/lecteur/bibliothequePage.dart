import 'package:flutter/material.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/lecteur/bibliotheque/filtre_livres.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/lecteur/bibliotheque/livre_card.dart';
import 'package:space_learn_flutter/core/themes/layout/navBarAll.dart';
import 'package:space_learn_flutter/core/themes/layout/recherche_bar.dart';

class BibliothequePage extends StatefulWidget {
  const BibliothequePage({Key? key}) : super(key: key);

  @override
  State<BibliothequePage> createState() => _BibliothequePageState();
}

class _BibliothequePageState extends State<BibliothequePage> {
  String filtreActif = "Tous";

  final List<Map<String, dynamic>> livres = [
    {
      "titre": "L'Art de la guerre",
      "auteur": "Sun Tzu",
      "progression": 75,
      "statut": "En cours",
      "couleur": [Color(0xFF6A5AE0), Color(0xFF8B82F6)],
    },
    {
      "titre": "Atomic Habits",
      "auteur": "James Clear",
      "progression": 100,
      "statut": "Terminé",
      "couleur": [Color(0xFFFF5E8A), Color(0xFFFF7DB3)],
    },
  ];

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
                    "Bibliothèque",
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  const CustomSearchBar(),
                  const SizedBox(height: 16),
                  FiltreLivres(
                    filtreActif: filtreActif,
                    onFiltreChange: (f) => setState(() => filtreActif = f),
                  ),
                  ListView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: livres.map((livre) {
                      return LivreCard(
                        titre: livre["titre"],
                        auteur: livre["auteur"],
                        progression: livre["progression"],
                        statut: livre["statut"],
                        couleurs: livre["couleur"],
                      );
                    }).toList(),
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
