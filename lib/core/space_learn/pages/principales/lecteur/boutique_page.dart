import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../themes/layout/nav_bar_all.dart';
import '../../../../themes/layout/recherche_bar.dart';
import '../../widgets/lecteur/boutique/livre_card.dart';
import '../../widgets/lecteur/boutique/select_categorie.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/bookService.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/book_model.dart';

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

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40.0),
          child: CircularProgressIndicator(color: Color(0xFF22D3EE)),
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
                  backgroundColor: const Color(0xFF22D3EE),
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
      // Filter books based on category
      final filteredBooks = _selectedCategory == "Tout"
          ? _books
          : _books.where((b) => b.categorie?.nom == _selectedCategory).toList();

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
                const CustomSearchBar(),
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
                return LivreCard(book: filteredBooks[index]);
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
      backgroundColor: const Color(0xFF0F172A),
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
                    Color(0xFF475569), // Lighter slate gray
                    Color(0xFF0F172A), // Dark background matching Scaffold
                  ],
                ),
              ),
            ),
          ),
          Column(
            children: [
              // En-tête fixe
              const NavBarAll(),
              // Contenu défilable
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadBooks,
                  color: const Color(0xFF06B6D4),
                  backgroundColor: const Color(0xFF1E293B),
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
