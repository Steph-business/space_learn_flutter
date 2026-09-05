import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/utils/app_notifications.dart';
import 'package:space_learn_flutter/core/themes/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:space_learn_flutter/core/themes/app_dimensions.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/favoriteModel.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/favoriteService.dart';
import 'package:space_learn_flutter/core/utils/token_storage.dart';
import 'package:space_learn_flutter/core/utils/message_erreur.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/details/book_detail_page.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/lecteur/boutique/livre_card.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  final FavoriteService _favoriteService = FavoriteService();
  List<FavoriteModel> _favorites = [];
  bool _isLoading = true;

  /// Ce qui a empêché le chargement d'aboutir.
  ///
  /// Le catch se contentait de couper l'indicateur : une panne réseau
  /// laissait `_favorites` vide et l'écran affirmait « Aucune favorie pour le
  /// moment » — des favoris existants passaient pour absents, sans Réessayer.
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
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
        // Sans jeton, la liste n'a pas pu être demandée : ce n'est pas un
        // vide, c'est une session finie.
        if (mounted) {
          setState(() {
            _error = "Votre session a expiré. Reconnectez-vous.";
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = messageLisible(
            e,
            repli: "Impossible de charger vos favoris.",
          );
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _removeFavorite(String livreId) async {
    try {
      final token = await TokenStorage.getToken();
      if (token == null) {
        // Sortir en silence rendait l'appui sur le cœur strictement sans
        // effet : ni retrait, ni message — le défaut que le catch a supprimé
        // pour la panne réseau, resté intact pour la session expirée. Le
        // chargement de la liste dit déjà « Votre session a expiré » dans la
        // même situation : les deux moitiés de l'écran parlent d'une voix.
        if (!mounted) return;
        AppNotifications.showSnackBar(
          context,
          message: "Votre session a expiré. Reconnectez-vous.",
          isError: true,
        );
        return;
      }
      await _favoriteService.removeFavorite(livreId, token);
      // `mounted` AVANT le setState : quitter la page pendant la requête
      // déclenchait « setState() called after dispose() ».
      if (!mounted) return;
      setState(() {
        _favorites.removeWhere((f) => f.livreId == livreId);
      });
      AppNotifications.showSnackBar(context, message: "Retiré de ma favorie");
    } catch (e) {
      // Le `catch (e) {}` d'avant rendait l'échec invisible : le cœur restait
      // rouge, rien ne se passait, et la personne croyait n'avoir jamais
      // appuyé. Le livre reste dans la liste — il est toujours favori côté
      // serveur — et l'échec se dit avec le message du serveur.
      if (!mounted) return;
      AppNotifications.showSnackBar(
        context,
        message: messageLisible(
          e,
          repli: "Ce livre n'a pas pu être retiré de vos favoris.",
        ),
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    AppColors.suivreLeTheme(context);
    return Scaffold(
      backgroundColor: AppColors.darkSurface,
      appBar: AppBar(
        title: Text(
          "Ma Favorie",
          style: GoogleFonts.poppins(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.surfaceVariant,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      body: _isLoading
          ? Center(
              child: Text(
                "Chargement...",
                style: GoogleFonts.poppins(color: AppColors.textSecondary),
              ),
            )
          // La panne AVANT le vide : sinon un échec réseau s'affiche
          // « Aucune favorie pour le moment », ce qui est un mensonge.
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 48,
                      color: AppColors.error,
                    ),
                    SizedBox(height: 16),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(color: AppColors.textPrimary),
                    ),
                    SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _loadFavorites,
                      child: const Text("Réessayer"),
                    ),
                  ],
                ),
              ),
            )
          : _favorites.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.favorite_border,
                    size: 80,
                    color: AppColors.textSecondary,
                  ),
                  SizedBox(height: 16),
                  Text(
                    "Aucune favorie pour le moment.",
                    style: GoogleFonts.poppins(
                      color: AppColors.textPrimary,
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
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusInner,
                    ),
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
                            borderRadius: BorderRadius.circular(
                              AppDimensions.radiusSmall,
                            ),
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
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(book.titre, style: AppTextStyles.subtitle),
                                SizedBox(height: 4),
                                Text(
                                  book.authorName,
                                  style: AppTextStyles.grey13,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  LivreCard.formatPrix(book.prix),
                                  style: GoogleFonts.poppins(
                                    color: AppColors.accentInk,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.favorite, color: AppColors.error),
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
      color: AppColors.textSecondary,
      child: Icon(Icons.book, color: AppColors.textSecondary),
    );
  }
}
