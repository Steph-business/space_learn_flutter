import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/details/book_detail_page.dart';
import '../../../../data/model/book_model.dart';

class LivreCard extends StatelessWidget {
  final BookModel book;
  final bool isOwned;

  const LivreCard({super.key, required this.book, this.isOwned = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BookDetailPage(book: book, isOwned: isOwned),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackground, // Dark card background
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Section
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                child: Container(
                  width: double.infinity,
                  color: AppColors.scaffoldBackground,
                  child:
                      book.imageCouverture != null &&
                          book.imageCouverture!.isNotEmpty &&
                          !book.imageCouverture!.contains('example.com')
                      ? Image.network(
                          book.imageCouverture!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _buildPlaceholder(),
                        )
                      : _buildPlaceholder(),
                ),
              ),
            ),
            // Info Section
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.titre,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Colors.white, // White title
                      height: 1.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    book.authorName,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w500,
                      fontSize: 11,
                      color: AppColors.slateLight, // Slate-400 for author
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  // Rating
                  Row(
                    children: [
                      if (book.telechargements > 0) ...[
                        Row(
                          children: List.generate(
                            5,
                            (index) => Icon(
                              index < book.noteMoyenne.floor()
                                  ? Icons.star_rounded
                                  : (index < book.noteMoyenne
                                        ? Icons.star_half_rounded
                                        : Icons.star_outline_rounded),
                              color: AppColors.warning,
                              size: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          book.noteMoyenne.toStringAsFixed(1),
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.slateLight,
                          ),
                        ),
                      ],
                      if (book.nombreMessages > 0) ...[
                        const SizedBox(width: 8),
                        const Icon(
                          Iconsax.message,
                          color: AppColors.slateLight,
                          size: 11,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${book.nombreMessages}',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.slateLight,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Price
                  Text(
                    '${book.prix} FCFA',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: AppColors.primary, // Cyan for price
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Button Row
                  // Boutons supprimés à la demande de l'utilisateur
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return const Center(
      child: Icon(Icons.book_rounded, color: AppColors.border, size: 40),
    );
  }
}
