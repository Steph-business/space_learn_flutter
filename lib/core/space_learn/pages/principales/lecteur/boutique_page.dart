import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/themes/app_dimensions.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../themes/layout/recherche_bar.dart';
import '../../widgets/lecteur/boutique/livre_card.dart';
import '../../widgets/lecteur/boutique/select_categorie.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/bookService.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/book_model.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/libraryService.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/library_model.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/review_service.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/review_model.dart';
import 'package:space_learn_flutter/core/themes/layout/nav_bar_all.dart';
import 'package:space_learn_flutter/core/utils/token_storage.dart';

class MarketplacePage extends StatefulWidget {
  const MarketplacePage({super.key});

  @override
  State<MarketplacePage> createState() => _MarketplacePageState();
}

class _MarketplacePageState extends State<MarketplacePage> {
  final BookService _bookService = BookService();
  final LibraryService _libraryService = LibraryService();
  final ReviewService _reviewService = ReviewService();
  List<BookModel> _books = [];
  List<String> _categories = [];
  Set<String> _ownedBookIds = {};
  bool _isLoading = true;
  String? _error;

  // State variables for category filtering
  String _selectedCategory = "Tout";
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();
  bool _isGridView = true;


  @override
  void initState() {
    super.initState();
    _loadBooks();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBooks() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final token = await TokenStorage.getToken();

      final results = await Future.wait([
        _bookService.getAllBooks(statut: 'publie', authToken: token),
        token != null
            ? _libraryService.getUserLibrary(token)
            : Future.value(<LibraryModel>[]),
        token != null
            ? _reviewService.getUserReviews(token)
            : Future.value(<ReviewModel>[]),
      ]);

      List<BookModel> books = results[0] as List<BookModel>;
      final library = results[1] as List<LibraryModel>;
      final userReviews = results[2] as List<ReviewModel>;

      if (mounted) {
        setState(() {
          _ownedBookIds = library.map((e) => e.livreId).toSet();

          // Enrichment: Update books with data from library and user's own ratings
          final Map<String, BookModel> libraryBooks = {};
          for (var item in library) {
            if (item.livre != null) {
              libraryBooks[item.livreId] = item.livre!;
            }
          }

          final Map<String, double> userRatings = {};
          for (var review in userReviews) {
            userRatings[review.livreId] = review.note.toDouble();
          }

          books = books.map((b) {
            var updatedBook = libraryBooks[b.id] ?? b;
            if (userRatings.containsKey(b.id)) {
              // Create a copy with the user's specific rating if they reviewed it
              updatedBook = updatedBook.copyWith(
                noteMoyenne: userRatings[b.id],
              );
            }
            return updatedBook;
          }).toList();

          _books = books;

          // Extract unique categories (excluding "Tout")
          final Set<String> categorySet = {};
          for (var book in books) {
            if (book.categorie != null && book.categorie!.nom.isNotEmpty) {
              categorySet.add(book.categorie!.nom);
            }
          }
          _categories = categorySet.toList()..sort();

          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Erreur lors du chargement des livres.";
          _isLoading = false;
        });
      }
    }
  }

  /// Recherche ou filtre sans resultat.
  ///
  /// La grille se contentait de ne rien afficher : une page vide ressemble a
  /// un chargement qui n'a pas abouti, et rien n'indiquait qu'il suffisait de
  /// changer de mot.
  Widget _aucunResultat() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 60, 40, 60),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, size: 44, color: AppColors.textHint),
          const SizedBox(height: 14),
          Text(
            _searchQuery.isNotEmpty
                ? "Aucun livre ne correspond à « $_searchQuery »."
                : "Aucun livre dans cette catégorie.",
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          if (_searchQuery.isNotEmpty || _selectedCategory != "Tout") ...[
            const SizedBox(height: 14),
            TextButton(
              onPressed: () => setState(() {
                _searchQuery = '';
                _searchController.clear();
                _selectedCategory = "Tout";
              }),
              child: Text(
                "Voir tout le catalogue",
                style: GoogleFonts.poppins(
                  color: AppColors.accentInk,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _onCategorySelected(String category) {
    setState(() {
      _selectedCategory = category;
    });
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(40.0),
          child: Text(
            "Chargement de la boutique...",
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    } else if (_error != null) {
      return SizedBox(
        height: 300,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: AppColors.error,
              ),
              SizedBox(height: 16),
              Text(_error!, style: TextStyle(color: AppColors.textPrimary)),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadBooks,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryLight,
                ),
                child: Text("Réessayer"),
              ),
            ],
          ),
        ),
      );
    } else if (_books.isEmpty) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: Text(
          "Aucun livre disponible.",
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    } else {
      // Filter books based on category and search
      final filteredBooks = _books.where((b) {
        final matchesCategory =
            _selectedCategory == "Tout" ||
            b.categorie?.nom == _selectedCategory;
        final matchesSearch =
            _searchQuery.isEmpty ||
            b.titre.toLowerCase().contains(_searchQuery.toLowerCase());
        return matchesCategory && matchesSearch;
      }).toList();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 8),
          // Search & Filter Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: CustomSearchBar(
                        controller: _searchController,
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => setState(() => _isGridView = !_isGridView),
                      child: Container(
                        height: 48,
                        width: 48,
                        decoration: BoxDecoration(
                          color: AppColors.cardBackground,
                          borderRadius: BorderRadius.circular(
                            AppDimensions.radiusCard,
                          ),
                          border: Border.all(
                            color: _isGridView
                                ? AppColors.accentInk
                                : Colors.transparent,
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          _isGridView
                              ? Icons.list_rounded
                              : Icons.grid_view_rounded,
                          color: AppColors.textPrimary,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 22),
                SelectCategorie(
                  categories: ["Tout", ..._categories],
                  selectedCategory: _selectedCategory,
                  onCategorySelected: _onCategorySelected,
                ),
                SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _selectedCategory == "Tout"
                          ? "Tous les livres"
                          : _selectedCategory,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      "${filteredBooks.length} livres",
                      style: GoogleFonts.poppins(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Sans resultat, on remplace la grille — et elle seule. Un retour
          // anticipe emporterait la barre de recherche et les categories avec
          // lui, laissant le lecteur sans moyen d'effacer ce qu'il a tape.
          if (filteredBooks.isEmpty)
            _aucunResultat()
          else if (_isGridView)
            // La grille se cale sur la carte, et non l'inverse.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: LayoutBuilder(
                builder: (context, contraintes) {
                  const colonnes = 2;
                  const ecart = 14.0;
                  final largeurCarte =
                      (contraintes.maxWidth - ecart * (colonnes - 1)) /
                      colonnes;
                  final hauteurCarte = LivreCard.hauteurPour(largeurCarte);

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: colonnes,
                      childAspectRatio: largeurCarte / hauteurCarte,
                      crossAxisSpacing: ecart,
                      mainAxisSpacing: ecart,
                    ),
                    itemCount: filteredBooks.length,
                    itemBuilder: (context, index) {
                      final book = filteredBooks[index];
                      return LivreCard(
                        book: book,
                        isOwned: _ownedBookIds.contains(book.id),
                      );
                    },
                  );
                },
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredBooks.length,
                itemBuilder: (context, index) {
                  final book = filteredBooks[index];
                  return LivreListCard(
                    book: book,
                    isOwned: _ownedBookIds.contains(book.id),
                  );
                },
              ),
            ),
          SizedBox(height: 100),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    AppColors.suivreLeTheme(context);
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: Column(
        children: [
          const NavBarAll(role: 'lecteur'),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadBooks,
              color: AppColors.accentInk,
              backgroundColor: AppColors.cardBackground,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [_buildBody(context)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
