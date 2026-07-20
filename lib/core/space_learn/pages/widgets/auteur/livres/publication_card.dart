import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/book_model.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/details/book_detail_page.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/ecrivain/ajouter_livre_page.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/ecrivain/statistiques_livre_page.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/bookService.dart';
import 'package:space_learn_flutter/core/utils/token_storage.dart';

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

  void _navigateToBookDetail(BuildContext context, BookModel book) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            BookDetailPage(book: book, isOwned: true, showCart: false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const mois = [
      "",
      "jan",
      "fév",
      "mars",
      "avr",
      "mai",
      "juin",
      "juil",
      "août",
      "sept",
      "oct",
      "nov",
      "déc",
    ];
    final String formattedDate = book.creeLe != null
        ? "${book.creeLe!.day} ${mois[book.creeLe!.month]} ${book.creeLe!.year} à ${book.creeLe!.hour.toString().padLeft(2, '0')}:${book.creeLe!.minute.toString().padLeft(2, '0')}"
        : "N/A";

    final isPublished = book.statut.toLowerCase() == 'publie';
    final statusColor = isPublished ? AppColors.success : AppColors.warning;
    final statusText = isPublished ? "Publié" : book.statut;

    return GestureDetector(
      onTap: () => _navigateToBookDetail(context, book),
      child: Container(
        margin: EdgeInsets.only(bottom: 14),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.textPrimary.withOpacity(0.04)),
          
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover Image
            Hero(
              tag: 'book_cover_${book.id}',
              child: Container(
                width: 72,
                height: 100,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  
                ),
                child:
                    book.imageCouverture != null &&
                        book.imageCouverture!.isNotEmpty &&
                        !book.imageCouverture!.contains('example.com')
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          book.imageCouverture!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildPlaceholderCover();
                          },
                        ),
                      )
                    : _buildPlaceholderCover(),
              ),
            ),
            SizedBox(width: 16),

            // Book Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    book.titre,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 6),
                  // Date + Status
                  Row(
                    children: [
                      Icon(
                        Iconsax.calendar_1,
                        size: 12,
                        color: AppColors.textPrimary.withOpacity(0.3),
                      ),
                      SizedBox(width: 4),
                      Text(
                        formattedDate,
                        style: GoogleFonts.poppins(
                          color: AppColors.textPrimary.withOpacity(0.4),
                          fontSize: 12,
                        ),
                      ),
                      SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
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
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "${book.prix} FCFA",
                          style: GoogleFonts.poppins(
                            color: AppColors.secondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Icon(
                        Iconsax.eye,
                        size: 14,
                        color: AppColors.textPrimary.withOpacity(0.3),
                      ),
                      SizedBox(width: 4),
                      Text(
                        "${book.telechargements} lectures",
                        style: GoogleFonts.poppins(
                          color: AppColors.textPrimary.withOpacity(0.4),
                          fontSize: 11,
                        ),
                      ),
                      if (book.noteMoyenne > 0) ...[
                        SizedBox(width: 12),
                        Icon(
                          Icons.star_rounded,
                          size: 14,
                          color: AppColors.warning,
                        ),
                        SizedBox(width: 2),
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

            // ── Three-dot menu (top right) ──
            PopupMenuButton<String>(
              color: AppColors.cardBackground,
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(maxWidth: 140),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: AppColors.textPrimary.withOpacity(0.06)),
              ),
              position: PopupMenuPosition.under,
              offset: const Offset(0, 4),
              onSelected: (value) async {
                switch (value) {
                  case 'edit':
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AjouterLivrePage(book: book),
                      ),
                    );
                    if (result == true && onBookUpdated != null) {
                      onBookUpdated!();
                    }
                    break;
                  case 'stats':
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => StatistiquesLivrePage(book: book),
                      ),
                    );
                    break;
                  case 'archive':
                    _handleArchive(context);
                    break;
                  case 'delete':
                    _handleDelete(context);
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'edit',
                  height: 32,
                  child: Row(
                    children: [
                      Icon(
                        Iconsax.edit_2,
                        color: AppColors.secondaryVariant,
                        size: 14,
                      ),
                      SizedBox(width: 8),
                      Text(
                        "modifier",
                        style: GoogleFonts.poppins(
                          color: AppColors.textPrimary,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'stats',
                  height: 32,
                  child: Row(
                    children: [
                      Icon(Iconsax.chart_1, color: AppColors.success, size: 14),
                      SizedBox(width: 8),
                      Text(
                        "statistiques",
                        style: GoogleFonts.poppins(
                          color: AppColors.textPrimary,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                const PopupMenuDivider(height: 1),
                PopupMenuItem(
                  value: 'archive',
                  height: 32,
                  child: Row(
                    children: [
                      Icon(
                        Iconsax.archive_2,
                        color: AppColors.textPrimary.withOpacity(0.5),
                        size: 14,
                      ),
                      SizedBox(width: 8),
                      Text(
                        "archiver",
                        style: GoogleFonts.poppins(
                          color: AppColors.textSecondary,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                const PopupMenuDivider(height: 1),
                PopupMenuItem(
                  value: 'delete',
                  height: 32,
                  child: Row(
                    children: [
                      Icon(
                        Iconsax.trash,
                        color: AppColors.error.withOpacity(0.7),
                        size: 14,
                      ),
                      SizedBox(width: 8),
                      Text(
                        "supprimer",
                        style: GoogleFonts.poppins(
                          color: AppColors.error,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              child: Padding(
                padding: EdgeInsets.all(2),
                child: Icon(
                  Iconsax.more,
                  color: AppColors.textPrimary.withOpacity(0.3),
                  size: 18,
                ),
              ),
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
            AppColors.secondaryVariant.withOpacity(0.15),
            AppColors.violet.withOpacity(0.1),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.secondaryVariant.withOpacity(0.15)),
      ),
      child: Center(
        child: Icon(Iconsax.book_1, color: AppColors.textHint, size: 28),
      ),
    );
  }

  void _handleArchive(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "Fonction d'archivage en cours de développement.",
          style: GoogleFonts.poppins(fontSize: 13),
        ),
        backgroundColor: AppColors.cardBackground,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _handleDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Iconsax.trash,
                  color: AppColors.error.withOpacity(0.8),
                  size: 32,
                ),
              ),
              SizedBox(height: 20),
              Text(
                "Supprimer l'œuvre",
                style: GoogleFonts.poppins(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 8),
              Text(
                "Êtes-vous sûr de vouloir supprimer \"${book.titre}\" ? Cette action est irréversible.",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: AppColors.textPrimary.withOpacity(0.5),
                  fontSize: 13,
                ),
              ),
              SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.textPrimary.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Text(
                            "Annuler",
                            style: GoogleFonts.poppins(
                              color: AppColors.textPrimary.withOpacity(0.6),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        Navigator.pop(context);
                        try {
                          final token = await TokenStorage.getToken();
                          if (token != null) {
                            await BookService().deleteBook(book.id, token);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    "Livre supprimé avec succès",
                                    style: GoogleFonts.poppins(fontSize: 13),
                                  ),
                                  backgroundColor: AppColors.success,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              );
                            }
                            if (onBookUpdated != null) {
                              onBookUpdated!();
                            }
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  "Erreur lors de la suppression : $e",
                                  style: GoogleFonts.poppins(fontSize: 13),
                                ),
                                backgroundColor: AppColors.error,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            );
                          }
                        }
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.error.withOpacity(0.3),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            "Supprimer",
                            style: GoogleFonts.poppins(
                              color: AppColors.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}