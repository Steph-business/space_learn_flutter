import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/utils/app_notifications.dart';
import 'package:flutter/material.dart';
import 'package:space_learn_flutter/core/themes/app_dimensions.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/book_model.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/details/book_detail_page.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/bookService.dart';
import 'package:space_learn_flutter/core/utils/token_storage.dart';

// La carte est intentionnellement epuree : titre, statut, prix, note.
// Les actions (Modifier, Publier, Supprimer) se trouvent dans le menu
// 3-points de la page detail, accessible en appuyant sur la carte.
class PublicationCard extends StatelessWidget {
  final BookModel book;
  final String? authorName;
  final VoidCallback? onBookUpdated;

  const PublicationCard({
    super.key,
    required this.book,
    this.authorName,
    this.onBookUpdated,
  });

  @override
  Widget build(BuildContext context) {
    AppColors.suivreLeTheme(context);
    const mois = [
      "",
      "jan",
      "fev",
      "mars",
      "avr",
      "mai",
      "juin",
      "juil",
      "aout",
      "sept",
      "oct",
      "nov",
      "dec",
    ];
    final String formattedDate = book.creeLe != null
        ? "${book.creeLe!.day} ${mois[book.creeLe!.month]} ${book.creeLe!.year}"
        : "N/A";

    final isPublished = book.statut.toLowerCase() == 'publie';
    final statusColor = isPublished ? AppColors.success : AppColors.warning;
    final statusText = isPublished ? "Publie" : book.statut;

    return GestureDetector(
      onTap: () async {
        // Tap : page detail avec menu de gestion (modifier/publier/supprimer)
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BookDetailPage(
              book: book,
              isOwned: true,
              peutAcheter: false, // false = auteur = menu de gestion visible
            ),
          ),
        );
        if (result == true && onBookUpdated != null) {
          onBookUpdated!();
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          border: Border.all(
            color: AppColors.textPrimary.withValues(alpha: 0.04),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Couverture
            Hero(
              tag: 'book_cover_${book.id}',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppDimensions.radiusInner),
                child: SizedBox(
                  width: 64,
                  height: 90,
                  child:
                      book.imageCouverture != null &&
                          book.imageCouverture!.isNotEmpty &&
                          !book.imageCouverture!.contains('example.com')
                      ? Image.network(
                          book.imageCouverture!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _buildPlaceholderCover(),
                        )
                      : _buildPlaceholderCover(),
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Informations
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.titre,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(
                            AppDimensions.radiusSmall,
                          ),
                        ),
                        child: Text(
                          statusText,
                          style: GoogleFonts.poppins(
                            color: statusColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Iconsax.calendar_1,
                        size: 11,
                        color: AppColors.textPrimary.withValues(alpha: 0.3),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        formattedDate,
                        style: GoogleFonts.poppins(
                          color: AppColors.textPrimary.withValues(alpha: 0.4),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        "${book.prix} FCFA",
                        style: GoogleFonts.poppins(
                          color: AppColors.accentInk,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(
                        Iconsax.eye,
                        size: 13,
                        color: AppColors.textPrimary.withValues(alpha: 0.3),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        "${book.telechargements} lectures",
                        style: GoogleFonts.poppins(
                          color: AppColors.textPrimary.withValues(alpha: 0.4),
                          fontSize: 11,
                        ),
                      ),
                      if (book.noteMoyenne > 0) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.star_rounded,
                          size: 13,
                          color: AppColors.warning,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          "${book.noteMoyenne}",
                          style: GoogleFonts.poppins(
                            color: AppColors.warning,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Fleche indicatrice
            Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: AppColors.textPrimary.withValues(alpha: 0.2),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderCover() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.secondaryVariant.withValues(alpha: 0.15),
            AppColors.violet.withValues(alpha: 0.1),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Center(
        child: Icon(Iconsax.book_1, color: AppColors.textHint, size: 24),
      ),
    );
  }
}
