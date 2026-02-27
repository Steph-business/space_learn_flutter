import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../themes/layout/nav_bar_all.dart';
import '../../../../themes/layout/recherche_bar.dart';
import '../../widgets/lecteur/boutique/livre_card.dart';
import '../../widgets/lecteur/boutique/select_categorie.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/bookService.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/book_model.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/libraryService.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/library_model.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/review_service.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/review_model.dart';
import 'package:space_learn_flutter/core/utils/token_storage.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/user_model.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/authServices.dart';

class MarketplacePage extends StatefulWidget {
  const MarketplacePage({super.key});

  @override
  State<MarketplacePage> createState() => _MarketplacePageState();
}

class _MarketplacePageState extends State<MarketplacePage> {
  final BookService _bookService = BookService();
  final LibraryService _libraryService = LibraryService();
  final ReviewService _reviewService = ReviewService();
  final AuthService _authService = AuthService();
  List<BookModel> _books = [];
  String _userName = "Lecteur";
  List<String> _categories = [];
  Set<String> _ownedBookIds = {};
  bool _isLoading = true;
  String? _error;

  // State variables for category filtering
  String _selectedCategory = "Tout";
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

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
        token != null ? _authService.getUser(token) : Future.value(null),
      ]);

      List<BookModel> books = results[0] as List<BookModel>;
      final library = results[1] as List<LibraryModel>;
      final userReviews = results[2] as List<ReviewModel>;
      final user = results[3];

      if (mounted) {
        setState(() {
          _ownedBookIds = library.map((e) => e.livreId).toSet();
          if (user != null && user is UserModel && user.nomComplet.isNotEmpty) {
            _userName = user.nomComplet;
          }

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
      print('❌ Error loading marketplace books: $e');
      if (mounted) {
        setState(() {
          _error = "Erreur lors du chargement des livres.";
          _isLoading = false;
        });
      }
    }
  }

  void _onCategorySelected(String category) {
    setState(() {
      _selectedCategory = category;
    });
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40.0),
          child: Text(
            "Chargement de la boutique...",
            style: TextStyle(color: Colors.white70),
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
              const Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadBooks,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryLight,
                ),
                child: const Text("Réessayer"),
              ),
            ],
          ),
        ),
      );
    } else if (_books.isEmpty) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: const Text(
          "Aucun livre disponible.",
          style: TextStyle(color: Colors.white70),
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
          const SizedBox(height: 8),
          // Search & Filter Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomSearchBar(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
                const SizedBox(height: 22),
                SelectCategorie(
                  categories: ["Tout", ..._categories],
                  selectedCategory: _selectedCategory,
                  onCategorySelected: _onCategorySelected,
                ),
                const SizedBox(height: 28),
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
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      "${filteredBooks.length} livres",
                      style: GoogleFonts.poppins(
                        color: Colors.grey[500],
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Books Grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.5,
                crossAxisSpacing: 16,
                mainAxisSpacing: 12,
              ),
              itemCount: filteredBooks.length,
              itemBuilder: (context, index) {
                final book = filteredBooks[index];
                return LivreCard(
                  book: book,
                  isOwned: _ownedBookIds.contains(book.id),
                );
              },
            ),
          ),
          const SizedBox(height: 100),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.45,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.slate, // Lighter slate gray
                    AppColors.scaffoldBackground, // Dark background matching Scaffold
                  ],
                ),
              ),
            ),
          ),
          Column(
            children: [
              // En-tête fixe
              NavBarAll(userName: _userName, showCart: true),
              // Contenu défilable
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadBooks,
                  color: AppColors.primary,
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
        ],
      ),
    );
  }
}
