import 'package:flutter/material.dart';
import '../../../../themes/layout/navBarAll.dart';
import '../../../../themes/layout/recherche_bar.dart';
import '../../widgets/lecteur/markeplace/livre_card.dart';
import '../../widgets/lecteur/markeplace/section_titre.dart';
import '../../widgets/lecteur/markeplace/select_categorie.dart';
import '../../widgets/details/book_detail_page.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/bookService.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/bookModel.dart';

class MarketplacePage extends StatefulWidget {
  const MarketplacePage({super.key});

  @override
  State<MarketplacePage> createState() => _MarketplacePageState();
}

class _MarketplacePageState extends State<MarketplacePage> {
  final BookService _bookService = BookService();
  List<BookModel> _books = [];
  List<String> _categories = [];
  bool _isLoading = true;
  String? _error;

  // State variables for category filtering
  String _selectedCategory = "Tout";

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
      });

      // Fetch all published books
      final books = await _bookService.getAllBooks(statut: 'publie');

      if (mounted) {
        setState(() {
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

  List<String> get _displayCategories {
    if (_selectedCategory == "Tout") {
      return _categories;
    }
    return [_selectedCategory];
  }

  List<BookModel> _getBooksByCategory(String category) {
    return _books.where((book) => book.categorie?.nom == category).toList();
  }

  List<BookModel> _getPopularBooks() {
    // Return sorted by rating, take top 10
    final sortedBooks = List<BookModel>.from(_books)
      ..sort((a, b) => b.noteMoyenne.compareTo(a.noteMoyenne));
    return sortedBooks.take(10).toList();
  }

  List<BookModel> _getRecentBooks() {
    // Return sorted by created date descending, take top 10
    final sortedBooks = List<BookModel>.from(_books)
      ..sort((a, b) {
        if (a.creeLe == null && b.creeLe == null) return 0;
        if (a.creeLe == null) return 1;
        if (b.creeLe == null) return -1;
        return b.creeLe!.compareTo(a.creeLe!);
      });
    return sortedBooks.take(10).toList();
  }

  Widget _buildFeaturedBook(BuildContext context) {
    if (_books.isEmpty) return const SizedBox.shrink();

    // Pick a popular book or the first one as featured
    final featuredBook = _getPopularBooks().isNotEmpty
        ? _getPopularBooks().first
        : _books.first;

    return Container(
      width: double.infinity,
      height: 400, // Reduced from 480
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        image:
            featuredBook.imageCouverture != null &&
                featuredBook.imageCouverture!.isNotEmpty
            ? DecorationImage(
                image: NetworkImage(featuredBook.imageCouverture!),
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              )
            : null,
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withOpacity(0.1),
              Colors.black.withOpacity(0.8),
            ],
            stops: const [0.5, 0.7, 1.0],
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              featuredBook.titre,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 28, // Reduced from 32
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: [
                  Shadow(
                    blurRadius: 10,
                    color: Colors.black54,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              featuredBook.authorName,
              style: const TextStyle(
                fontSize: 14, // Reduced from 16
                fontWeight: FontWeight.w500,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            BookDetailPage(book: featuredBook, isOwned: false),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.play_arrow,
                    color: Colors.black,
                    size: 20,
                  ), // Reduced
                  label: const Text(
                    "Découvrir",
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 14, // Reduced from 16
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20, // Reduced from 24
                      vertical: 10, // Reduced from 12
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Ajouté à la liste")),
                    );
                  },
                  icon: const Icon(
                    Icons.add,
                    color: Colors.white,
                    size: 20,
                  ), // Reduced
                  label: const Text(
                    "Ma liste",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14, // Reduced from 16
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white, width: 2),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20, // Reduced from 24
                      vertical: 10, // Reduced from 12
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildBookSection(String title, List<BookModel> books) {
    if (books.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SectionTitle(title: title),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 200, // Reduced from 320
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: books.length,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemBuilder: (context, index) {
              final book = books[index];
              return Container(
                width: 120, // Reduced from 150
                margin: const EdgeInsets.only(right: 12),
                child: LivreCard(book: book),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40.0),
          child: CircularProgressIndicator(color: Color(0xFFF59E0B)),
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
              Text(_error!, style: const TextStyle(color: Color(0xFF1E293B))),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadBooks,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                ),
                child: const Text("Réessayer"),
              ),
            ],
          ),
        ),
      );
    } else if (_books.isEmpty) {
      return SizedBox(
        height: MediaQuery.of(context).size.height * 0.5,
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(40.0),
            child: Text("Aucun livre disponible."),
          ),
        ),
      );
    } else {
      return Column(
        children: [
          // Featured Hero Section
          _buildFeaturedBook(context),

          // Search Bar
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: CustomSearchBar(),
          ),
          const SizedBox(height: 20),

          // Filtre Catégories
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: SelectCategorie(
              categories: ["Tout", ..._categories],
              selectedCategory: _selectedCategory,
              onCategorySelected: _onCategorySelected,
            ),
          ),
          const SizedBox(height: 24),

          if (_selectedCategory == "Tout") ...[
            _buildBookSection("Les plus populaires", _getPopularBooks()),
            _buildBookSection("Les plus récents", _getRecentBooks()),
          ],

          // Sections par catégorie
          ..._displayCategories.map((category) {
            final categoryBooks = _getBooksByCategory(category);
            if (categoryBooks.isEmpty) return const SizedBox.shrink();
            return _buildBookSection(category, categoryBooks);
          }).toList(),

          // Espace bas de page
          const SizedBox(height: 40),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // En-tête fixe
          const NavBarAll(),
          // Contenu défilable
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadBooks,
              color: const Color(0xFFF59E0B),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.zero, // Edge to edge for hero
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
