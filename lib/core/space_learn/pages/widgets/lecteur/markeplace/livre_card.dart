import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../details/purchase_page.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/bookModel.dart';

class LivreCard extends StatelessWidget {
  final BookModel book;

  const LivreCard({
    super.key,
    required this.book,
  });

  @override
  Widget build(BuildContext context) {
    // Data pour la page d'achat
    final bookData = {
      'id': book.id,
      'title': book.titre,
      'author': book.authorName,
      'price': book.prix,
      'description': book.description,
      'image': book.imageCouverture,
      'format': book.format,
      'note_moyenne': book.noteMoyenne ?? 0.0,
      'telechargements': book.telechargements ?? 0,
      'cree_le': book.creeLe,
      'chapters': [],
    };

    final String formattedDate = book.creeLe != null
        ? "${book.creeLe!.day}/${book.creeLe!.month}/${book.creeLe!.year}"
        : "N/A";

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => PurchasePage(book: bookData)),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(color: const Color(0xFFF1F5F9), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Section with Price Tag
            Stack(
              children: [
                Hero(
                  tag: 'book-image-${book.id}',
                  child: Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                    ),
                    child: book.imageCouverture != null &&
                            book.imageCouverture!.isNotEmpty &&
                            !book.imageCouverture!.contains('example.com')
                        ? ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(24),
                            ),
                            child: Image.network(
                              book.imageCouverture!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
                            ),
                          )
                        : _buildPlaceholder(),
                  ),
                ),
                // Price Tag with Gradient
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2563EB).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${book.prix} ',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                          TextSpan(
                            text: 'FCFA',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w400,
                              fontSize: 9,
                            ),
                          ),
                        ],
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // Info Section
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.titre,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: const Color(0xFF1E293B),
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    book.authorName,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w500,
                      fontSize: 11,
                      color: const Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  // Stats Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 16),
                          const SizedBox(width: 4),
                          Text(
                            (book.noteMoyenne ?? 0.0).toStringAsFixed(1),
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const Icon(Icons.download_rounded, color: Color(0xFF94A3B8), size: 14),
                          const SizedBox(width: 4),
                          Text(
                            "${book.telechargements ?? 0}",
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
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
      child: Icon(
        Icons.book_rounded,
        color: Color(0xFFCBD5E1),
        size: 48,
      ),
    );
  }
}
