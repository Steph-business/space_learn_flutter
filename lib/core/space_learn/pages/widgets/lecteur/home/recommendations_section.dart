import 'package:flutter/material.dart';

import '../../details/book_detail_page.dart';
import '../../details/purchase_page.dart';

class RecommendationsSection extends StatelessWidget {
  const RecommendationsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _BookCard(
            title: "Le pouvoir du moment présent",
            color: Colors.lightBlue,
            onTap: () =>
                _navigateToBookDetail(context, "Le pouvoir du moment présent"),
          ),
          const SizedBox(width: 12),
          _BookCard(
            title: "Sapiens",
            color: Colors.lightGreen,
            onTap: () => _navigateToBookDetail(context, "Sapiens"),
          ),
          const SizedBox(width: 12),
          _BookCard(
            title: "Dune",
            color: Colors.orangeAccent,
            onTap: () => _navigateToBookDetail(context, "Dune"),
          ),
        ],
      ),
    );
  }

  void _navigateToBookDetail(BuildContext context, String bookTitle) {
    // Données fictives pour la démonstration
    final Map<String, dynamic> bookData = {
      'title': bookTitle,
      'author': 'Auteur inconnu',
      'description': 'Description du livre $bookTitle',
      'price': '9.99 €',
      'chapters': [
        {'title': 'Chapitre 1', 'content': 'Contenu du chapitre 1...'},
        {'title': 'Chapitre 2', 'content': 'Contenu du chapitre 2...'},
      ],
    };

    // Vérifier si l'utilisateur a acheté le livre (simulation)
    bool hasPurchased = _checkIfPurchased(bookTitle);

    if (hasPurchased) {
      // Si acheté, aller à la page de détails du livre
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => BookDetailPage(book: bookData)),
      );
    } else {
      // Si pas acheté, aller à la page d'achat
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => PurchasePage(book: bookData)),
      );
    }
  }

  bool _checkIfPurchased(String bookTitle) {
    // Simulation : seuls certains livres sont considérés comme achetés
    // Dans une vraie app, cela viendrait d'une API ou d'une base de données
    const purchasedBooks = ["Le pouvoir du moment présent"];
    return purchasedBooks.contains(bookTitle);
  }
}

class _BookCard extends StatelessWidget {
  final String title;
  final Color color;
  final VoidCallback? onTap;

  const _BookCard({required this.title, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        color: color,
        elevation: 2,
        child: Container(
          width: 120,
          padding: const EdgeInsets.all(8),
          child: Center(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
