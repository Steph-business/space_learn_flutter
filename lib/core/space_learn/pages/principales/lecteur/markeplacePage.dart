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
            child: SingleChildScrollView(
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
                  const SelectCategorie(),

                  const SizedBox(height: 26),

                  // Titre section
                  const SectionTitle(title: "Livres populaires"),

                  const SizedBox(height: 2),

                  // Grille de livres
                  if (_isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40.0),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_error != null)
                    Center(
                      child: Column(
                        children: [
                          Text(_error!, style: const TextStyle(color: Colors.red)),
                          ElevatedButton(
                            onPressed: _loadBooks,
                            child: const Text("Réessayer"),
                          ),
                        ],
                      ),
                    )
                  else if (_books.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40.0),
                        child: Text("Aucun livre disponible pour le moment."),
                      ),
                    )
                  else
                    GridView.builder(
                      itemCount: _books.length,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.75,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                      ),
                      itemBuilder: (context, index) {
                        final book = _books[index];
                        return LivreCard(
                          book: book,
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
