import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';

import '../../../../../themes/app_colors.dart';

class LivreCard extends StatelessWidget {
  final String titre;
  final String auteur;
  final String categorie;
  final VoidCallback? onTap;

  const LivreCard({
    super.key,
    required this.titre,
    required this.auteur,
    required this.categorie,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap:
          onTap ??
          () {
            // TODO: Navigate to book details page
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Ouverture de "$titre"')));
          },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 55,
              height: 55,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.book, color: Colors.white),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titre,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  Text(
                    auteur,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward, size: 20, color: Color(0xFF6D6DFF)),
          ],
        ),
      ),
    );
  }
}
