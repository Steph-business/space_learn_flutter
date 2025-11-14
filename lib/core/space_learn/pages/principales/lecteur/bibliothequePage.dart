import 'package:flutter/material.dart';

import 'package:space_learn_flutter/core/themes/layout/navBarAll.dart';
import 'package:space_learn_flutter/core/themes/layout/recherche_bar.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/lecteur/bibliotheque/filtre_livres.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/lecteur/bibliotheque/livre_card.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/details/reading_page.dart';

class BibliothequePage extends StatefulWidget {
  const BibliothequePage({Key? key}) : super(key: key);

  @override
  State<BibliothequePage> createState() => _BibliothequePageState();
}

class _BibliothequePageState extends State<BibliothequePage> {
  String filtreActif = "Tous";

  final List<Map<String, dynamic>> livres = [
    // Business Category
    {
      "titre": "L'Art de la guerre",
      "auteur": "Sun Tzu",
      "progression": 75,
      "statut": "En cours",
      "couleur": [Color(0xFF6A5AE0), Color(0xFF8B82F6)],
      "categorie": "Business",
    },
    {
      "titre": "Atomic Habits",
      "auteur": "James Clear",
      "progression": 100,
      "statut": "Terminé",
      "couleur": [Color(0xFFFF5E8A), Color(0xFFFF7DB3)],
      "categorie": "Business",
    },
    {
      "titre": "Rich Dad Poor Dad",
      "auteur": "Robert Kiyosaki",
      "progression": 60,
      "statut": "En cours",
      "couleur": [Color(0xFF2196F3), Color(0xFF64B5F6)],
      "categorie": "Business",
    },
    {
      "titre": "The Lean Startup",
      "auteur": "Eric Ries",
      "progression": 85,
      "statut": "Terminé",
      "couleur": [Color(0xFF00BCD4), Color(0xFF4DD0E1)],
      "categorie": "Business",
    },
    {
      "titre": "Zero to One",
      "auteur": "Peter Thiel",
      "progression": 40,
      "statut": "En cours",
      "couleur": [Color(0xFF3F51B5), Color(0xFF7986CB)],
      "categorie": "Business",
    },

    // Informatique Category
    {
      "titre": "Clean Code",
      "auteur": "Robert C. Martin",
      "progression": 45,
      "statut": "En cours",
      "couleur": [Color(0xFF4CAF50), Color(0xFF81C784)],
      "categorie": "Informatique",
    },
    {
      "titre": "The Pragmatic Programmer",
      "auteur": "Andrew Hunt",
      "progression": 70,
      "statut": "En cours",
      "couleur": [Color(0xFF8BC34A), Color(0xFFAED581)],
      "categorie": "Informatique",
    },
    {
      "titre": "Design Patterns",
      "auteur": "Gang of Four",
      "progression": 25,
      "statut": "En cours",
      "couleur": [Color(0xFF009688), Color(0xFF4DB6AC)],
      "categorie": "Informatique",
    },
    {
      "titre": "Code Complete",
      "auteur": "Steve McConnell",
      "progression": 95,
      "statut": "Terminé",
      "couleur": [Color(0xFF607D8B), Color(0xFF90A4AE)],
      "categorie": "Informatique",
    },
    {
      "titre": "Refactoring",
      "auteur": "Martin Fowler",
      "progression": 50,
      "statut": "En cours",
      "couleur": [Color(0xFF795548), Color(0xFFA1887F)],
      "categorie": "Informatique",
    },

    // Science Category
    {
      "titre": "Sapiens",
      "auteur": "Yuval Noah Harari",
      "progression": 90,
      "statut": "Terminé",
      "couleur": [Color(0xFFFF9800), Color(0xFFFFB74D)],
      "categorie": "Science",
    },
    {
      "titre": "A Brief History of Time",
      "auteur": "Stephen Hawking",
      "progression": 35,
      "statut": "En cours",
      "couleur": [Color(0xFF9E9E9E), Color(0xFFBDBDBD)],
      "categorie": "Science",
    },
    {
      "titre": "The Gene",
      "auteur": "Siddhartha Mukherjee",
      "progression": 80,
      "statut": "Terminé",
      "couleur": [Color(0xFF673AB7), Color(0xFF9575CD)],
      "categorie": "Science",
    },
    {
      "titre": "Cosmos",
      "auteur": "Carl Sagan",
      "progression": 55,
      "statut": "En cours",
      "couleur": [Color(0xFF3F51B5), Color(0xFF7986CB)],
      "categorie": "Science",
    },
    {
      "titre": "The Body Keeps the Score",
      "auteur": "Bessel van der Kolk",
      "progression": 65,
      "statut": "En cours",
      "couleur": [Color(0xFFE91E63), Color(0xFFF06292)],
      "categorie": "Science",
    },

    // Littérature Category
    {
      "titre": "1984",
      "auteur": "George Orwell",
      "progression": 30,
      "statut": "En cours",
      "couleur": [Color(0xFF9C27B0), Color(0xFFBA68C8)],
      "categorie": "Littérature",
    },
    {
      "titre": "To Kill a Mockingbird",
      "auteur": "Harper Lee",
      "progression": 100,
      "statut": "Terminé",
      "couleur": [Color(0xFF4CAF50), Color(0xFF81C784)],
      "categorie": "Littérature",
    },
    {
      "titre": "Pride and Prejudice",
      "auteur": "Jane Austen",
      "progression": 75,
      "statut": "En cours",
      "couleur": [Color(0xFFFF5722), Color(0xFFFF8A65)],
      "categorie": "Littérature",
    },
    {
      "titre": "The Great Gatsby",
      "auteur": "F. Scott Fitzgerald",
      "progression": 45,
      "statut": "En cours",
      "couleur": [Color(0xFF2196F3), Color(0xFF64B5F6)],
      "categorie": "Littérature",
    },
    {
      "titre": "One Hundred Years of Solitude",
      "auteur": "Gabriel García Márquez",
      "progression": 20,
      "statut": "En cours",
      "couleur": [Color(0xFF009688), Color(0xFF4DB6AC)],
      "categorie": "Littérature",
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
                    children: livres
                        .where((livre) {
                          if (filtreActif == "Tous") return true;
                          return livre["categorie"] == filtreActif;
                        })
                        .map((livre) {
                          return GestureDetector(
                            onTap: () {
                              // Navigation vers la page de lecture
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ReadingPage(
                                    book: {
                                      'title': livre["titre"],
                                      'chapters': [
                                        {
                                          'title': 'Chapitre 1',
                                          'content': 'Contenu du chapitre 1...',
                                        },
                                        {
                                          'title': 'Chapitre 2',
                                          'content': 'Contenu du chapitre 2...',
                                        },
                                      ],
                                    },
                                    chapter: {
                                      'title': 'Chapitre 1',
                                      'content': 'Contenu du chapitre 1...',
                                    },
                                    chapterIndex: 0,
                                  ),
                                ),
                              );
                            },
                            child: LivreCard(
                              titre: livre["titre"],
                              auteur: livre["auteur"],
                              progression: livre["progression"],
                              statut: livre["statut"],
                              couleurs: livre["couleur"],
                            ),
                          );
                        })
                        .toList(),
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
