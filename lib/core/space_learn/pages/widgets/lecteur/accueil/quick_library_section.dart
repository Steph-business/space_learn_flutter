import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../data/model/libraryModel.dart';
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
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.transparent),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6366F1).withOpacity(0.06),
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
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
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
                        color: const Color(0xFF94A3B8),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Color(0xFF06B6D4),
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
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.transparent),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Voir tous mes livres (${validItems.length})',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF06B6D4),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: Color(0xFF06B6D4),
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
    [Color(0xFF6366F1), Color(0xFF4F46E5)],
    [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
    [Color(0xFF06B6D4), Color(0xFF0891B2)],
    [Color(0xFFEC4899), Color(0xFFDB2777)],
    [Color(0xFFF59E0B), Color(0xFFD97706)],
    [Color(0xFF10B981), Color(0xFF059669)],
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
          color: const Color(0xFF1E293B),
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
                        color: const Color(0xFF10B981),
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
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFFCBD5E1),
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
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFFCBD5E1),
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
