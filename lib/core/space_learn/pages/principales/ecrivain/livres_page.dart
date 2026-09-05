import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:space_learn_flutter/core/themes/layout/recherche_bar.dart';
import 'package:space_learn_flutter/core/themes/app_dimensions.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';

import 'package:space_learn_flutter/core/space_learn/pages/widgets/auteur/livres/publications_liste.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/ecrivain/ajouter_livre_page.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/auth/login.dart';
import 'package:space_learn_flutter/core/themes/layout/nav_bar_all.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/bookService.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/authServices.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/book_model.dart';
import 'package:space_learn_flutter/core/services/session_service.dart';
import 'package:space_learn_flutter/core/utils/message_erreur.dart';
import 'package:space_learn_flutter/core/utils/token_storage.dart';

class LivresPage extends StatefulWidget {
  final VoidCallback? onBackPressed;

  const LivresPage({super.key, this.onBackPressed});

  @override
  State<LivresPage> createState() => _LivresPageState();
}

class _LivresPageState extends State<LivresPage> {
  final BookService _bookService = BookService();
  final AuthService _authService = AuthService();

  List<BookModel> _books = [];
  String? _authorName;
  bool _isLoading = true;
  String? _error;
  String _searchQuery = "";
  String _selectedFilter = "Tous";

  final List<String> _filters = ["Tous", "Publiés", "Brouillons", "Populaires"];

  /// Vrai quand l'erreur est liée à la session (jeton absent / expiré).
  ///
  /// Ce drapeau est posé à la source. Il se déduisait du texte de `_error`, en
  /// cherchant « Session » avec une majuscule : dès que le message vient du
  /// serveur — « Votre session a expiré. » —, la recherche échouait et l'écran
  /// proposait « Réessayer » à quelqu'un qui devait se reconnecter.
  bool _erreurDeSession = false;
  bool get _isSessionError => _erreurDeSession;

  @override
  void initState() {
    super.initState();
    _loadBooks();
  }

  Future<void> _loadBooks() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
        _erreurDeSession = false;
      });

      final token = await TokenStorage.getToken();
      if (!mounted) return;
      if (token == null) {
        setState(() {
          _erreurDeSession = true;
          _error = "Session expirée. Veuillez vous reconnecter.";
          _isLoading = false;
        });
        return;
      }

      final user = await _authService.getUser(token);
      if (!mounted) return;
      if (user == null) {
        setState(() {
          _error = "Votre compte n'a pas pu être chargé.";
          _isLoading = false;
        });
        return;
      }

      final books = await _bookService.getBooksByAuthorId(user.id);

      if (mounted) {
        setState(() {
          _books = books;
          _authorName = user.nomComplet;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          // La cause, telle que le serveur l'a dite. « Erreur lors du
          // chargement des livres. » cachait aussi bien une session expirée
          // qu'un réseau coupé, et l'auteur ne pouvait qu'appuyer à nouveau.
          _erreurDeSession = estSessionExpiree(e);
          _error = messageLisible(
            e,
            repli: "Vos livres n'ont pas pu être chargés.",
          );
          _isLoading = false;
        });
      }
    }
  }

  /// Fin de session complète, puis retour à l'écran de connexion.
  ///
  /// Ce bouton n'effaçait que le jeton : le cache des livres téléchargés et le
  /// profil sélectionné restaient sur l'appareil, et le compte suivant y
  /// retrouvait la bibliothèque du précédent — lisible en entier depuis
  /// Paramètres → Téléchargements. SessionService.terminer() est le point de
  /// nettoyage unique que tous les autres chemins de déconnexion empruntent.
  Future<void> _seReconnecter() async {
    await SessionService.terminer();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  List<BookModel> get _filteredBooks {
    var books = _books;

    // Filter by search
    if (_searchQuery.isNotEmpty) {
      books = books
          .where((b) => b.titre.toLowerCase().contains(_searchQuery))
          .toList();
    }

    // Filter by status
    switch (_selectedFilter) {
      case "Publiés":
        books = books.where((b) => b.statut.toLowerCase() == "publie").toList();
        break;
      case "Brouillons":
        books = books
            .where((b) => b.statut.toLowerCase() == "brouillon")
            .toList();
        break;
      case "Populaires":
        // Le tri portait sur `telechargements`, que le modèle remplissait avec
        // le NOMBRE D'AVIS : il classait donc déjà sur les avis, sous un nom
        // qui laissait croire au contraire. Les deux grandeurs sont désormais
        // séparées et `telechargements` reste à zéro faute de compteur côté
        // serveur — trier dessus ne classerait plus rien du tout. On trie sur
        // la seule grandeur que le serveur donne vraiment.
        books = List.from(books)
          ..sort((a, b) => b.nombreAvis.compareTo(a.nombreAvis));
        break;
    }

    return books;
  }

  @override
  Widget build(BuildContext context) {
    AppColors.suivreLeTheme(context);
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: Column(
        children: [
          const NavBarAll(role: 'auteur'),
          Expanded(
            child: Column(
              children: [
                // ── Stats Sessions (Three individual cards) ──
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      _buildStatSession(
                        "${_books.length}",
                        "Total",
                        Iconsax.book_1,
                        AppColors.secondaryVariant,
                      ),
                      SizedBox(width: 10),
                      _buildStatSession(
                        "${_books.where((b) => b.statut.toLowerCase() == 'publie').length}",
                        "Publiés",
                        Iconsax.verify,
                        AppColors.success,
                      ),
                      SizedBox(width: 10),
                      // « Lectures » nourri par `telechargements` était un
                      // mensonge : le serveur n'envoie aucun compteur de
                      // lectures dans cette liste, et le modèle y versait le
                      // nombre d'AVIS — un auteur lu 500 fois mais noté 2 fois
                      // lisait « 2 lectures ». On affiche donc la grandeur
                      // réellement reçue, sous son vrai nom.
                      _buildStatSession(
                        "${_books.fold<int>(0, (sum, b) => sum + b.nombreAvis)}",
                        "Avis",
                        Iconsax.star_1,
                        AppColors.warning,
                      ),
                    ],
                  ),
                ),

                // ── Search + Filter ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      // Search bar (Sleek)
                      CustomSearchBar(
                        hintText: "Rechercher par titre...",
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value.toLowerCase();
                          });
                        },
                      ),
                      SizedBox(height: 12),

                      // Filter chips
                      SizedBox(
                        height: 38,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _filters.length,
                          separatorBuilder: (_, __) => SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final filter = _filters[index];
                            final isSelected = _selectedFilter == filter;
                            return GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedFilter = filter),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOutCubic,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                decoration: BoxDecoration(
                                  border: isSelected
                                      ? Border(
                                          bottom: BorderSide(
                                            color: AppColors.secondaryVariant,
                                            width: 2,
                                          ),
                                        )
                                      : null,
                                ),
                                child: Center(
                                  child: Text(
                                    filter,
                                    style: GoogleFonts.poppins(
                                      color: isSelected
                                          ? AppColors.secondaryVariant
                                          : AppColors.textHint,
                                      fontSize: 12,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 12),

                // ── Books List ──
                Expanded(
                  child: _isLoading
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.secondaryVariant,
                                ),
                              ),
                              SizedBox(height: 16),
                              Text(
                                "Chargement de vos livres...",
                                style: GoogleFonts.poppins(
                                  color: AppColors.textPrimary.withOpacity(0.4),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        )
                      : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Icône contextuelle
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color:
                                        (_isSessionError
                                                ? AppColors.warning
                                                : AppColors.error)
                                            .withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _isSessionError
                                        ? Iconsax.lock
                                        : Iconsax.wifi_square,
                                    size: 32,
                                    color: _isSessionError
                                        ? AppColors.warning
                                        : AppColors.error,
                                  ),
                                ),
                                SizedBox(height: 20),
                                // Titre de l'erreur
                                Text(
                                  _isSessionError
                                      ? "Session expirée"
                                      : "Oups !",
                                  style: GoogleFonts.poppins(
                                    color: AppColors.textPrimary,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 8),
                                // Sous-texte explicatif
                                Text(
                                  _isSessionError
                                      ? "Votre session a expiré.\nReconnectez-vous pour continuer."
                                      : _error!,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                    height: 1.5,
                                  ),
                                ),
                                SizedBox(height: 24),
                                // Bouton contextuel — filled
                                GestureDetector(
                                  onTap: _isSessionError
                                      ? _seReconnecter
                                      : _loadBooks,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 28,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.secondaryVariant,
                                      borderRadius: BorderRadius.circular(
                                        AppDimensions.radiusInner,
                                      ),
                                    ),
                                    child: Text(
                                      _isSessionError
                                          ? "Se reconnecter"
                                          : "Réessayer",
                                      style: GoogleFonts.poppins(
                                        color: AppColors.onAccent,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _filteredBooks.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Iconsax.book,
                                size: 64,
                                color: AppColors.textPrimary.withOpacity(0.1),
                              ),
                              SizedBox(height: 16),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? "Aucun résultat trouvé"
                                    : "Vous n'avez pas encore publié de livres.",
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  color: AppColors.textPrimary.withOpacity(0.4),
                                ),
                              ),
                              if (_searchQuery.isEmpty) ...[
                                SizedBox(height: 20),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const AjouterLivrePage(),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.secondaryVariant
                                          .withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(
                                        AppDimensions.radiusInner,
                                      ),
                                      border: Border.all(
                                        color: AppColors.secondaryVariant
                                            .withOpacity(0.3),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Iconsax.add_circle,
                                          color: AppColors.secondaryVariant,
                                          size: 18,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          "Publier mon premier livre",
                                          style: GoogleFonts.poppins(
                                            color: AppColors.secondaryVariant,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadBooks,
                          color: AppColors.secondaryVariant,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              children: [
                                PublicationsList(
                                  books: _filteredBooks,
                                  authorName: _authorName,
                                  onBookUpdated: _loadBooks,
                                ),
                                SizedBox(height: 100),
                              ],
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatSession(
    String value,
    String label,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 14, color: color),
            SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.poppins(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.poppins(
                color: AppColors.textPrimary.withOpacity(0.3),
                fontSize: 9,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
