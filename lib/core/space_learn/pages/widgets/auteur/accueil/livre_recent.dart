import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/themes/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/ecrivain/livres_page.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/bookService.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/book_model.dart';
import 'package:space_learn_flutter/core/utils/token_storage.dart';
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (_books.isEmpty) {
      return Center(
        child: Text(
          "Aucun livre publié récemment.",
          style: GoogleFonts.poppins(color: AppColors.textHint),
        ),
      );
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Mes livres publiés (${_books.length})",
              style: AppTextStyles.sectionTitle,
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LivresPage()),
                );
              },
              child: Text(
                "Voir tout",
                style: GoogleFonts.poppins(
                  color: AppColors.primaryLight,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 10),
        ..._books.map((book) => _buildBookCard(book)),
      ],
    );
  }

  Widget _buildBookCard(BookModel book) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 60,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  image:
                      (book.imageCouverture != null &&
                          book.imageCouverture!.isNotEmpty)
                      ? DecorationImage(
                          image: NetworkImage(book.imageCouverture!),
                          fit: BoxFit.cover,
                        )
                      : null,
                  color: AppColors.border,
                ),
                child:
                    (book.imageCouverture == null ||
                        book.imageCouverture!.isEmpty)
                    ? Icon(Icons.book, color: AppColors.textHint, size: 30)
                    : null,
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.titre,
                      style: AppTextStyles.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Text(
                      "${book.categorieId ?? 'Fiction'} • ${book.telechargements} lectures",
                      style: AppTextStyles.bodyFaded12,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildButton(
                  "MODIFIER",
                  AppColors.border.withOpacity(0.5),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildButton(
                  "STATS",
                  AppColors.border.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildButton(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(
          label,
          style: GoogleFonts.poppins(
            color: AppColors.primaryLight.withOpacity(0.8),
            fontWeight: FontWeight.bold,
            fontSize: 12,
            letterSpacing: 1.1,
          ),
        ),
      ),
    );
  }
}