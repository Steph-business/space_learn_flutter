import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/themes/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/favoriteModel.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/favoriteService.dart';
import 'package:space_learn_flutter/core/utils/token_storage.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/details/book_detail_page.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({Key? key}) : super(key: key);

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  final FavoriteService _favoriteService = FavoriteService();
  List<FavoriteModel> _favorites = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    try {
      final token = await TokenStorage.getToken();
      if (token != null) {
        final docs = await _favoriteService.getFavorites(token);
        if (mounted) {
          setState(() {
            _favorites = docs;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      print("Erreur loading favorie : $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _removeFavorite(String livreId) async {
    try {
      final token = await TokenStorage.getToken();
      if (token != null) {
        await _favoriteService.removeFavorite(livreId, token);
        setState(() {
          _favorites.removeWhere((f) => f.livreId == livreId);
        });
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("Retiré de ma favorie")));
        }
      }
    } catch (e) {
      print("Erreur remove favorie : $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkSurface,
      appBar: AppBar(
        title: Text(
          "Ma Favorie",
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.surfaceVariant,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? Center(
              child: Text(
                "Chargement...",
                style: GoogleFonts.poppins(color: Colors.white70),
              ),
            )
          : _favorites.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.favorite_border,
                    size: 80,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Aucune favorie pour le moment.",
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _favorites.length,
              itemBuilder: (context, index) {
                final fav = _favorites[index];
                final book = fav.livre;
                if (book == null) return const SizedBox.shrink();

                return Card(
                  color: AppColors.surfaceVariant,
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              BookDetailPage(book: book, isOwned: false),
                        ),
                      ).then((_) => _loadFavorites());
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child:
                                book.imageCouverture != null &&
                                    book.imageCouverture!.isNotEmpty
                                ? Image.network(
                                    book.imageCouverture!,
                                    width: 70,
                                    height: 100,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        _fallbackImage(),
                                  )
                                : _fallbackImage(),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  book.titre,
                                  style: AppTextStyles.subtitle,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  book.authorName,
                                  style: AppTextStyles.grey13,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "${book.prix} FCFA",
                                  style: GoogleFonts.poppins(
                                    color: AppColors.primaryLight,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.favorite, color: Colors.red),
                            onPressed: () => _removeFavorite(fav.livreId),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _fallbackImage() {
    return Container(
      width: 70,
      height: 100,
      color: Colors.grey[800],
      child: const Icon(Icons.book, color: Colors.grey),
    );
  }
}
