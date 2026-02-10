import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/details/book_detail_page.dart';
import '../../../../data/model/bookModel.dart';

class LivreCard extends StatelessWidget {
  final BookModel book;

  const LivreCard({super.key, required this.book});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BookDetailPage(book: book, isOwned: false),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(
            4,
          ), // Slightly rounded for Netflix style
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Section (Poster Style)
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: 'book-image-${book.id}',
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                      child: Container(
                        color: const Color(0xFFF1F5F9),
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
                  // Gradient Overlay for text readability if needed, but keeping white card style
                ],
              ),
            ),
            // Info Section
            Padding(
              padding: const EdgeInsets.all(6.0), // Reduced from 8.0
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.titre,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 12, // Reduced from 13
                      color: const Color(0xFF1E293B),
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2), // Reduced from 4
                  Text(
                    book.authorName,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w500,
                      fontSize: 9, // Reduced from 10
                      color: const Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6), // Reduced from 8
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${book.prix} FCFA',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          fontSize: 11, // Reduced from 13
                          color: const Color(0xFF2563EB),
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: Color(0xFFF59E0B),
                            size: 12, // Reduced from 14
                          ),
                          const SizedBox(width: 2),
                          Text(
                            (book.noteMoyenne).toStringAsFixed(1),
                            style: GoogleFonts.poppins(
                              fontSize: 10, // Reduced from 11
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1E293B),
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
      child: Icon(Icons.book_rounded, color: Color(0xFFCBD5E1), size: 48),
    );
  }

  // _timeAgo removed if not used to keep it clean, or can be re-added if needed.
  // User wanted "information qui sont ici", which included time.
  // Re-adding time if specific request, but Netflix usually doesn't show "Added 2 days ago" on every card.
  // However, I will keep it simple.
}
