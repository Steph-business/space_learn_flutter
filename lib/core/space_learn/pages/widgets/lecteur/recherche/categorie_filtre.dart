import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';

import '../../../../../themes/app_colors.dart';
import '../../details/reading_page.dart';
import 'livre_card.dart';

class CategorieFiltres extends StatefulWidget {
  const CategorieFiltres({super.key});

  @override
  State<CategorieFiltres> createState() => _CategorieFiltresState();
}

class _CategorieFiltresState extends State<CategorieFiltres> {
  String _selectedCategory = "Romans";
  final categories = ["Romans", "Business", "Science", "Informatique"];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Boutons de catégories horizontaux (même apparence)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: categories.map((cat) {
              final isSelected = cat == _selectedCategory;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedCategory = cat;
                  });
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : Colors.grey[300]!,
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Text(
                    cat,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w500,
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 20),
        // Contenu de la catégorie sélectionnée (comme les tabs Teams)
        SizedBox(
          height: 200, // Hauteur fixe pour le contenu
          child: _buildCategoryContent(_selectedCategory),
        ),
      ],
    );
  }

  Widget _buildCategoryContent(String category) {
    // Contenu dynamique pour chaque catégorie
    final Map<String, List<Map<String, dynamic>>> categoryBooks = {
      "Romans": [
        {
          'title': 'Le Petit Prince',
          'author': 'Antoine de Saint-Exupéry',
          'chapters': [
            {
              'title': 'Chapitre 1',
              'content': 'Il y avait autrefois un petit prince...',
            },
            {
              'title': 'Chapitre 2',
              'content': 'Le petit prince habitait sur une planète...',
            },
          ],
        },
        {
          'title': '1984',
          'author': 'George Orwell',
          'chapters': [
            {
              'title': 'Chapitre 1',
              'content': 'C\'était une froide journée d\'avril...',
            },
            {
              'title': 'Chapitre 2',
              'content': 'Winston Smith gravit péniblement...',
            },
          ],
        },
        {
          'title': 'L\'Étranger',
          'author': 'Albert Camus',
          'chapters': [
            {
              'title': 'Chapitre 1',
              'content': 'Aujourd\'hui, maman est morte...',
            },
            {
              'title': 'Chapitre 2',
              'content': 'Le lendemain, Marie est venue...',
            },
          ],
        },
      ],
      "Business": [
        {
          'title': 'Comment se faire des amis',
          'author': 'Dale Carnegie',
          'chapters': [
            {
              'title': 'Chapitre 1',
              'content': 'Si vous voulez récolter des amis...',
            },
            {
              'title': 'Chapitre 2',
              'content': 'La façon la plus simple de gagner...',
            },
          ],
        },
        {
          'title': 'Les 7 habitudes',
          'author': 'Stephen Covey',
          'chapters': [
            {'title': 'Chapitre 1', 'content': 'Être proactif signifie...'},
            {
              'title': 'Chapitre 2',
              'content': 'Commencer avec la fin à l\'esprit...',
            },
          ],
        },
        {
          'title': 'Père riche, Père pauvre',
          'author': 'Robert Kiyosaki',
          'chapters': [
            {
              'title': 'Chapitre 1',
              'content': 'Les leçons que j\'ai apprises...',
            },
            {
              'title': 'Chapitre 2',
              'content': 'Pourquoi enseigner la finance...',
            },
          ],
        },
      ],
      "Science": [
        {
          'title': 'Sapiens',
          'author': 'Yuval Noah Harari',
          'chapters': [
            {
              'title': 'Chapitre 1',
              'content': 'Il y a environ 13,8 milliards d\'années...',
            },
            {
              'title': 'Chapitre 2',
              'content': 'Il y a 2,5 millions d\'années...',
            },
          ],
        },
        {
          'title': 'Le gène égoïste',
          'author': 'Richard Dawkins',
          'chapters': [
            {'title': 'Chapitre 1', 'content': 'Pourquoi sommes-nous ici ?...'},
            {
              'title': 'Chapitre 2',
              'content': 'Les réplicateurs et les véhicules...',
            },
          ],
        },
        {
          'title': 'Cosmos',
          'author': 'Carl Sagan',
          'chapters': [
            {
              'title': 'Chapitre 1',
              'content': 'Le cosmos est tout ce qui est...',
            },
            {
              'title': 'Chapitre 2',
              'content': 'L\'univers est fait de histoires...',
            },
          ],
        },
      ],
      "Informatique": [
        {
          'title': 'Clean Code',
          'author': 'Robert C. Martin',
          'chapters': [
            {'title': 'Chapitre 1', 'content': 'Il y a quelques années...'},
            {'title': 'Chapitre 2', 'content': 'Le nom d\'une variable...'},
          ],
        },
        {
          'title': 'The Pragmatic Programmer',
          'author': 'Andrew Hunt',
          'chapters': [
            {
              'title': 'Chapitre 1',
              'content': 'C\'est une grande responsabilité...',
            },
            {
              'title': 'Chapitre 2',
              'content': 'Que signifie être pragmatique...',
            },
          ],
        },
        {
          'title': 'Design Patterns',
          'author': 'Gang of Four',
          'chapters': [
            {
              'title': 'Chapitre 1',
              'content': 'Concevoir un logiciel orienté objet...',
            },
            {'title': 'Chapitre 2', 'content': 'Le patron Strategy...'},
          ],
        },
      ],
    };

    final books = categoryBooks[category] ?? [];

    return ListView.builder(
      itemCount: books.length,
      itemBuilder: (context, index) {
        final book = books[index];
        return LivreCard(
          titre: book['title']!,
          auteur: book['author']!,
          categorie: category,
          onTap: () {
            // Navigation vers la page de lecture
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ReadingPage(
                  book: {'title': book['title'], 'chapters': book['chapters']},
                  chapter: book['chapters'][0],
                  chapterIndex: 0,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
