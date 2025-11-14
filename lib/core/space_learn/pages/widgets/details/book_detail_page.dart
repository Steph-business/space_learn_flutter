import 'package:flutter/material.dart';

import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/themes/app_text_styles.dart';
import 'reading_page.dart';

class BookDetailPage extends StatelessWidget {
  final Map<String, dynamic> book;

  const BookDetailPage({super.key, required this.book});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text(
          book['title'] ?? 'Détails du livre',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Couverture du livre
            Center(
              child: Container(
                height: 200,
                width: 150,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.book,
                  size: 80,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Titre et auteur
            Text(
              book['title'] ?? '',
              style: AppTextStyles.heading,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Par ${book['author'] ?? ''}',
              style: AppTextStyles.subheading,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // Description
            Text('Description', style: AppTextStyles.subheading),
            const SizedBox(height: 8),
            Text(
              book['description'] ?? 'Aucune description disponible.',
              style: AppTextStyles.bodyText1,
            ),
            const SizedBox(height: 30),

            // Liste des chapitres
            Text('Chapitres', style: AppTextStyles.subheading),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: (book['chapters'] as List?)?.length ?? 0,
              itemBuilder: (context, index) {
                final chapter = (book['chapters'] as List)[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(
                      'Chapitre ${index + 1}: ${chapter['title'] ?? ''}',
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      // Navigation vers la page de lecture
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ReadingPage(
                            book: book,
                            chapter: chapter,
                            chapterIndex: index,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),

            const SizedBox(height: 30),

            // Bouton Lire
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // Commencer la lecture du premier chapitre
                  final chapters = book['chapters'] as List?;
                  if (chapters != null && chapters.isNotEmpty) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ReadingPage(
                          book: book,
                          chapter: chapters[0],
                          chapterIndex: 0,
                        ),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Commencer la lecture',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Mock data pour les livres
class MockBookData {
  static final Map<String, dynamic> ownedBook1 = {
    'id': '1',
    'title': 'L\'Art de la guerre',
    'author': 'Sun Tzu',
    'description': 'Un classique sur la stratégie militaire et la philosophie.',
    'chapters': [
      {
        'id': 'chap1',
        'title': 'Introduction',
        'content': 'Contenu du chapitre 1...',
      },
      {
        'id': 'chap2',
        'title': 'La stratégie',
        'content': 'Contenu du chapitre 2...',
      },
      {
        'id': 'chap3',
        'title': 'Conclusion',
        'content': 'Contenu du chapitre 3...',
      },
    ],
  };

  static final Map<String, dynamic> ownedBook2 = {
    'id': '2',
    'title': 'Atomic Habits',
    'author': 'James Clear',
    'description':
        'Comment construire de bonnes habitudes et se débarrasser des mauvaises.',
    'chapters': [
      {
        'id': 'chap4',
        'title': 'Les habitudes composées',
        'content': 'Contenu du chapitre 4...',
      },
      {
        'id': 'chap5',
        'title': 'Le pouvoir des habitudes',
        'content': 'Contenu du chapitre 5...',
      },
    ],
  };
}
