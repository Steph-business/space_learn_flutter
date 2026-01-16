import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';

import '../../details/purchase_page.dart';

class LivreCard extends StatelessWidget {
  final String titre;
  final String auteur;
  final String prix;

  const LivreCard({
    super.key,
    required this.titre,
    required this.auteur,
    required this.prix,
  });

  @override
  Widget build(BuildContext context) {
    // Mock data pour le livre
    final mockBook = {
      'id': titre.hashCode.toString(),
      'title': titre,
      'author': auteur,
      'price': prix,
      'description': 'Description du livre $titre par $auteur.',
      // 'chapters': [], // Removed chapters
    };

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => PurchasePage(book: mockBook)),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 110,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF73B3), Color(0xFFEE5AFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Icon(Icons.book, color: Colors.white, size: 40),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              titre,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: const Color(0xFF1E293B),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              auteur,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w400,
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            const Spacer(),
            Text(
              prix,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: const Color(0xFF2563EB),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
