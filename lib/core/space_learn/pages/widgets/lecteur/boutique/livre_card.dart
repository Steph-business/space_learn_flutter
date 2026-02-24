import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/cart_provider.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/details/book_detail_page.dart';
import '../../../../data/model/book_model.dart';

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
          color: const Color(0xFF1E293B), // Dark card background
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
                  color: const Color(0xFF0F172A),
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
                      color: const Color(0xFF94A3B8), // Slate-400 for author
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  // Rating
                  Row(
                    children: [
                      Row(
                        children: List.generate(
                          5,
                          (index) => Icon(
                            index < 4
                                ? Icons.star_rounded
                                : Icons.star_half_rounded,
                            color: const Color(0xFFF59E0B),
                            size: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '4.5',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Price
                  Text(
                    '${book.prix} FCFA',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: const Color(0xFF06B6D4), // Cyan for price
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Button Row
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 38,
                          child: ElevatedButton(
                            onPressed: () {
                              context.read<CartProvider>().addItem(book);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    "${book.titre} ajouté au panier",
                                  ),
                                  duration: const Duration(seconds: 2),
                                  backgroundColor: const Color(0xFF06B6D4),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF06B6D4),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              "Acheter",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        height: 38,
                        width: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFF334155),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            context.read<CartProvider>().addItem(book);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("${book.titre} ajouté au panier"),
                                duration: const Duration(seconds: 2),
                                backgroundColor: const Color(0xFF06B6D4),
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.shopping_cart_outlined,
                            size: 18,
                            color: Colors.white,
                          ),
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

  Widget _buildPlaceholder() {
    return const Center(
      child: Icon(Icons.book_rounded, color: Color(0xFF334155), size: 40),
    );
  }
}
