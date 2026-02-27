import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/themes/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../data/model/library_model.dart';
import '../../details/book_detail_page.dart';

class QuickLibrarySection extends StatelessWidget {
  final List<LibraryModel> library;
  final VoidCallback? onSeeAll;

  const QuickLibrarySection({super.key, required this.library, this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    // Filtrer uniquement les items qui ont un livre valide
    final validItems = library.where((item) => item.livre != null).toList();

    if (validItems.isEmpty) {
      return GestureDetector(
        onTap: onSeeAll,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.transparent),
            boxShadow: [
              BoxShadow(
                color: AppColors.indigo.withOpacity(0.06),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.indigo, AppColors.violet],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.library_books_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bibliothèque vide',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Achetez des livres pour les retrouver ici',
                      style: GoogleFonts.poppins(
                        color: AppColors.slateLight,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: AppColors.primary,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Scrollable horizontal list
        SizedBox(
          height: 210,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: validItems.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(right: 14),
                child: _QuickLibraryCard(
                  libraryItem: validItems[index],
                  colorIndex: index,
                ),
              );
            },
          ),
        ),
        if (validItems.length > 3) ...[
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onSeeAll,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.transparent),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Voir tous mes livres (${validItems.length})',
                    style: AppTextStyles.linkBold,
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _QuickLibraryCard extends StatelessWidget {
  final LibraryModel libraryItem;
  final int colorIndex;

  static const List<List<Color>> _placeholderGradients = [
    [AppColors.indigo, AppColors.indigoDeep],
    [AppColors.violet, AppColors.violetDark],
    [AppColors.primary, AppColors.primaryDark],
    [AppColors.pinkVivid, AppColors.pinkDark],
    [AppColors.warning, AppColors.orange],
    [AppColors.success, AppColors.success],
  ];

  const _QuickLibraryCard({
    required this.libraryItem,
    required this.colorIndex,
  });

  @override
  Widget build(BuildContext context) {
    final book = libraryItem.livre!; // already filtered for non-null
    final gradient =
        _placeholderGradients[colorIndex % _placeholderGradients.length];

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BookDetailPage(book: book, isOwned: true),
          ),
        );
      },
      child: Container(
        width: 135,
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: gradient[0].withOpacity(0.15),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(color: Colors.transparent),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image
            Expanded(
              flex: 7,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(18),
                      topRight: Radius.circular(18),
                    ),
                    child:
                        book.imageCouverture != null &&
                            book.imageCouverture!.isNotEmpty &&
                            !book.imageCouverture!.contains('example.com')
                        ? Image.network(
                            book.imageCouverture!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                _buildPlaceholder(gradient),
                          )
                        : _buildPlaceholder(gradient),
                  ),
                  // Badge "Possédé"
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 10,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            'Possédé',
                            style: GoogleFonts.poppins(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Info
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 7, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      book.titre,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(
                          Icons.edit_rounded,
                          size: 9,
                          color: book.auteur != null
                              ? AppColors.slateLight
                              : AppColors.slateBorder,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            book.auteur != null
                                ? book.authorName
                                : 'Auteur inconnu',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: book.auteur != null
                                  ? AppColors.slateLight
                                  : AppColors.slateBorder,
                              fontStyle: book.auteur != null
                                  ? FontStyle.normal
                                  : FontStyle.italic,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(List<Color> gradient) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(Icons.menu_book_rounded, color: Colors.white, size: 36),
      ),
    );
  }
}
