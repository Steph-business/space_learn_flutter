import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../details/book_detail_page.dart';
import '../../details/purchase_page.dart';
import '../../../../data/model/bookModel.dart';

class RecommendationsSection extends StatelessWidget {
  final List<BookModel> books;

  const RecommendationsSection({super.key, required this.books});

  @override
  Widget build(BuildContext context) {
    if (books.isEmpty) {
      return Container(
        height: 100,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF1F5F9)),
        ),
        child: Center(
          child: Text(
            "Aucune recommandation pour le moment",
            style: GoogleFonts.poppins(color: const Color(0xFF64748B), fontSize: 13),
          ),
        ),
      );
    }

    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: books.length,
        itemBuilder: (context, index) {
          final book = books[index];
          return Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _BookCard(
              book: book,
              onTap: () => _navigateToBookDetail(context, book),
            ),
          );
        },
      ),
    );
  }

  void _navigateToBookDetail(BuildContext context, BookModel book) {
    // Dans une vraie app, on vérifierait si l'utilisateur possède déjà le livre
    // Pour l'instant, on redirige vers PurchasePage par défaut ou BookDetailPage si on simule
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PurchasePage(book: book.toJson())),
    );
  }
}

class _BookCard extends StatelessWidget {
  final BookModel book;
  final VoidCallback? onTap;

  const _BookCard({
    required this.book,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = Colors.primaries[book.id.hashCode % Colors.primaries.length];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: const Color(0xFFF1F5F9), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: book.imageCouverture != null && 
                       book.imageCouverture!.isNotEmpty && 
                       !book.imageCouverture!.contains('example.com')
                    ? ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                        child: Image.network(
                          book.imageCouverture!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Center(
                              child: Icon(Icons.book_rounded, color: color, size: 40),
                            );
                          },
                        ),
                      )
                    : Center(
                        child: Icon(Icons.book_rounded, color: color, size: 40),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.titre,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: const Color(0xFF1E293B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    book.authorName,
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF64748B),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 14),
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
