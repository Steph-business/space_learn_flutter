import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/ecrivain/livrePage.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/bookService.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/bookModel.dart';
import 'package:space_learn_flutter/core/utils/tokenStorage.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/authServices.dart';

class AuteurLivresRecents extends StatefulWidget {
  const AuteurLivresRecents({super.key});

  @override
  State<AuteurLivresRecents> createState() => _AuteurLivresRecentsState();
}

class _AuteurLivresRecentsState extends State<AuteurLivresRecents> {
  final BookService _bookService = BookService();
  final AuthService _authService = AuthService();
  List<BookModel> _books = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBooks();
  }

  Future<void> _loadBooks() async {
    try {
      final token = await TokenStorage.getToken();
      if (token != null) {
        final user = await _authService.getUser(token);
        if (user != null) {
          final books = await _bookService.getBooksByAuthor(user.id);
          if (mounted) {
            setState(() {
              // Sort by creation date descending and take top 3
              books.sort(
                (a, b) => (b.creeLe ?? DateTime(0)).compareTo(
                  a.creeLe ?? DateTime(0),
                ),
              );
              _books = books.take(3).toList();
              _isLoading = false;
            });
          }
        }
      }
    } catch (e) {
      print("Error loading recent books: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_books.isEmpty) {
      return Center(
        child: Text(
          "Aucun livre publié récemment.",
          style: GoogleFonts.poppins(color: Colors.grey),
        ),
      );
    }

    return Column(
      children: _books.map((book) {
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const LivresPage()),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    image:
                        (book.imageCouverture != null &&
                            book.imageCouverture!.isNotEmpty)
                        ? DecorationImage(
                            image: NetworkImage(book.imageCouverture!),
                            fit: BoxFit.cover,
                          )
                        : null,
                    color:
                        (book.imageCouverture == null ||
                            book.imageCouverture!.isEmpty)
                        ? const Color(0xFF818CF8)
                        : null,
                  ),
                  child:
                      (book.imageCouverture == null ||
                          book.imageCouverture!.isEmpty)
                      ? const Icon(Icons.book, color: Colors.white, size: 24)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book.titre,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: const Color(0xFF1E293B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0F2FE),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              "${book.telechargements} ventes",
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: const Color(0xFF1565C0),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber[50],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.star,
                                  size: 14,
                                  color: Color(0xFFF57C00),
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  (book.noteMoyenne ?? 0.0).toStringAsFixed(1),
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFFF57C00),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    "Publié",
                    style: GoogleFonts.poppins(
                      color: Colors.green[800],
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
