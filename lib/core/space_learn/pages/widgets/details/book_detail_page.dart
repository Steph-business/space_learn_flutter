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
                width: 140,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: book['image'] != null &&
                        book['image'].toString().isNotEmpty &&
                        !book['image'].toString().contains('example.com')
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          book['image'],
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.book,
                              size: 80,
                              color: AppColors.primary,
                            );
                          },
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes !=
                                        null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            );
                          },
                        ),
                      )
                    : const Icon(
                        Icons.book,
                        size: 80,
                        color: AppColors.primary,
                      ),
              ),
            ),
            const SizedBox(height: 16),

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
            const SizedBox(height: 12),

            // Stats Row moved here
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildStatItem(
                  Icons.star,
                  Colors.amber,
                  (book['note_moyenne'] ?? 0.0).toStringAsFixed(1),
                  "Avis",
                ),
                _buildDivider(),
                _buildStatItem(
                  Icons.download_rounded,
                  AppColors.primary,
                  (book['telechargements'] ?? 0).toString(),
                  "Téléch.",
                ),
                _buildDivider(),
                _buildStatItem(
                  Icons.calendar_today,
                  Colors.grey,
                  book['cree_le'] != null
                      ? "${DateTime.parse(book['cree_le'].toString()).day}/${DateTime.parse(book['cree_le'].toString()).month}/${DateTime.parse(book['cree_le'].toString()).year}"
                      : "N/A",
                  "Publié",
                ),
              ],
            ),
            const SizedBox(height: 20),


            // Description
            Text('Description', style: AppTextStyles.subheading),
            const SizedBox(height: 8),
            Text(
              book['description'] ?? 'Aucune description disponible.',
              style: AppTextStyles.bodyText1,
            ),
            const SizedBox(height: 20),

            // Bouton Lire
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ReadingPage(book: book),
                    ),
                  );
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

  Widget _buildStatItem(IconData icon, Color color, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 30,
      width: 1,
      color: Colors.grey[300],
      margin: const EdgeInsets.symmetric(horizontal: 20),
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
    // 'chapters': [] // Removed chapters
  };

  static final Map<String, dynamic> ownedBook2 = {
    'id': '2',
    'title': 'Atomic Habits',
    'author': 'James Clear',
    'description':
        'Comment construire de bonnes habitudes et se débarrasser des mauvaises.',
    // 'chapters': [] // Removed chapters
  };
}
