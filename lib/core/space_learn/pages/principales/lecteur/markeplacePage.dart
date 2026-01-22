import 'package:flutter/material.dart';


import '../../../../themes/layout/navBarAll.dart';
import '../../../../themes/layout/recherche_bar.dart';
import '../../widgets/lecteur/markeplace/livre_card.dart';
import '../../widgets/lecteur/markeplace/section_titre.dart';
import '../../widgets/lecteur/markeplace/select_categorie.dart';

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
  List<String> _categories = ["Tout"];
  String _selectedCategory = "Tout";
  bool _isLoading = true;
  String? _error;

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
          
          // Extract unique categories
          final Set<String> categorySet = {"Tout"};
          for (var book in books) {
            if (book.categorie != null && book.categorie!.nom.isNotEmpty) {
              categorySet.add(book.categorie!.nom);
            }
          }
          _categories = categorySet.toList();
          
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

  List<BookModel> _getFilteredBooks() {
    if (_selectedCategory == "Tout") {
      return _books;
    }
    return _books.where((book) => book.categorie?.nom == _selectedCategory).toList();
  }

  void _onCategorySelected(String category) {
    setState(() {
      _selectedCategory = category;
    });
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Titre principal
                    const SizedBox(height: 10),

                    // Barre de recherche
                    const CustomSearchBar(),

                    const SizedBox(height: 20),

                    // Catégories
                    SelectCategorie(
                      categories: _categories,
                      selectedCategory: _selectedCategory,
                      onCategorySelected: _onCategorySelected,
                    ),

                    const SizedBox(height: 26),

                    // Titre section
                    const SectionTitle(title: "Livres populaires"),

                    const SizedBox(height: 2),

                    // Grille de livres
                    if (_isLoading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(40.0),
                          child: CircularProgressIndicator(color: Color(0xFFF59E0B)),
                        ),
                      )
                    else if (_error != null)
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.5,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
                              const SizedBox(height: 16),
                              Text(_error!, style: const TextStyle(color: Color(0xFF1E293B))),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadBooks,
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B)),
                                child: const Text("Réessayer"),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (_getFilteredBooks().isEmpty)
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.5,
                        child: const Center(
                          child: Padding(
                            padding: EdgeInsets.all(40.0),
                            child: Text("Aucun livre disponible dans cette catégorie."),
                          ),
                        ),
                      )
                    else
                      GridView.builder(
                        itemCount: _getFilteredBooks().length,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.65,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                        ),
                        itemBuilder: (context, index) {
                          final book = _getFilteredBooks()[index];
                          return LivreCard(
                            book: book,
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
