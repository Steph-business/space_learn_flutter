import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:space_learn_flutter/core/themes/layout/nav_bar_all.dart';
import 'package:space_learn_flutter/core/themes/layout/recherche_bar.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/lecteur/bibliotheque/filtre_livres.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/lecteur/bibliotheque/livre_card.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/details/book_detail_page.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/libraryService.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/library_model.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/bookService.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/authServices.dart';
import 'package:space_learn_flutter/core/utils/token_storage.dart';

import 'package:space_learn_flutter/core/utils/api_routes.dart';
import 'package:space_learn_flutter/core/themes/layout/nav_bar_lecteur.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/readingProgressService.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/book_model.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/readingActivityModel.dart';

class BibliothequePage extends StatefulWidget {
  const BibliothequePage({super.key});

  @override
  State<BibliothequePage> createState() => _BibliothequePageState();
}

class _BibliothequePageState extends State<BibliothequePage> {
  String filtreActif = "Tous";
  final LibraryService _libraryService = LibraryService();
  final BookService _bookService = BookService();
  final AuthService _authService = AuthService();
  final ReadingProgressService _progressService = ReadingProgressService();
  List<LibraryModel> _libraryItems = [];
  List<String> _categories = ["Tous"];
  bool _isLoading = true;
  String? _error;
  String _userName = "Lecteur";

  @override
  void initState() {
    super.initState();
    _loadLibrary();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    try {
      final token = await TokenStorage.getToken();
      if (token != null) {
        final user = await _authService.getUser(token);
        if (user != null && mounted) {
          setState(() {
            _userName = user.nomComplet.split(' ')[0];
          });
        }
      }
    } catch (e) {
      print("Error loading user info: $e");
    }
  }

  Future<void> _loadLibrary() async {
    try {
      print("🔄 Chargement de la bibliothèque...");
      if (mounted) {
        setState(() {
          _isLoading = true;
          _error = null;
        });
      }

      final token = await TokenStorage.getToken();
      if (token == null) throw Exception("Non connecté");

      print("📡 Appel API: ${ApiRoutes.library}");
      final items = await _libraryService.getUserLibrary(token);
      print("📚 Bibliothèque chargée : ${items.length} livres trouvés");

      // If the library items don't include the full `livre` object (backend may
      // return only `livre_id`), fetch missing book details so we can display
      // author names and other metadata.
      final List<LibraryModel> enriched = [];
      for (var i = 0; i < items.length; i++) {
        final item = items[i];
        print("📖 Item $i: ID=${item.id}, LivreID=${item.livreId}");
        // If the backend returned no nested book, or returned a placeholder
        // empty book (some backends return zero-uuid placeholders), try to
        // fetch the real book details by id so we can show the author name.
        final bool hasPlaceholderLivre =
            item.livre != null &&
            (item.livre!.id.isEmpty ||
                item.livre!.id == '00000000-0000-0000-0000-000000000000' ||
                item.livre!.titre.isEmpty);

        if ((item.livre == null || hasPlaceholderLivre) &&
            item.livreId.isNotEmpty) {
          try {
            final token = await TokenStorage.getToken();
            final book = await _bookService.getBookById(
              item.livreId,
              authToken: token,
            );
            print("✅ Fetched book for livreId=${item.livreId}: ${book.titre}");
            enriched.add(
              LibraryModel(
                id: item.id,
                utilisateurId: item.utilisateurId,
                livreId: item.livreId,
                acquisVia: item.acquisVia,
                creeLe: item.creeLe,
                livre: book,
              ),
            );
            continue;
          } catch (e) {
            print('⚠️ Failed to fetch book for ${item.livreId}: $e');
            // fall through and add original item (without livre)
          }
        }
        enriched.add(item);
      }

      // 🔄 Fetch all reading progressions for the user to ensure we have them
      List<ReadingActivityModel> allProgress = [];
      try {
        allProgress = await _progressService.getAllProgressions(token);
      } catch (e) {
        print("⚠️ Could not fetch all progressions: $e");
      }

      final Map<String, ReadingActivityModel> progressMap = {
        for (var p in allProgress) p.livreId: p,
      };

      // 💉 Map progressions to books
      final finalItems = enriched.map((item) {
        if (item.livre != null) {
          final p = progressMap[item.livre!.id];
          if (p != null) {
            // Reconstruct book with progress if found
            return LibraryModel(
              id: item.id,
              utilisateurId: item.utilisateurId,
              livreId: item.livreId,
              acquisVia: item.acquisVia,
              creeLe: item.creeLe,
              livre: BookModel(
                id: item.livre!.id,
                auteurId: item.livre!.auteurId,
                titre: item.livre!.titre,
                description: item.livre!.description,
                imageCouverture: item.livre!.imageCouverture,
                fichierUrl: item.livre!.fichierUrl,
                format: item.livre!.format,
                prix: item.livre!.prix,
                stock: item.livre!.stock,
                statut: item.livre!.statut,
                categorieId: item.livre!.categorieId,
                noteMoyenne: item.livre!.noteMoyenne,
                telechargements: item.livre!.telechargements,
                categorie: item.livre!.categorie,
                auteur: item.livre!.auteur,
                progressions: [p],
              ),
            );
          }
        }
        return item;
      }).toList();

      if (mounted) {
        setState(() {
          _libraryItems = finalItems;

          // Extract unique categories
          final Set<String> categorySet = {"Tous"};
          for (var item in enriched) {
            if (item.livre?.categorie != null &&
                item.livre!.categorie!.nom.isNotEmpty) {
              categorySet.add(item.livre!.categorie!.nom);
            }
          }
          _categories = categorySet.toList();

          _isLoading = false;
        });
      }
    } catch (e) {
      print("❌ Erreur chargement bibliothèque : $e");
      if (mounted) {
        setState(() {
          _error = "Erreur lors du chargement de la bibliothèque";
          _isLoading = false;
        });
      }
    }
  }

  List<LibraryModel> _getFilteredBooks() {
    if (filtreActif == "Tous") {
      return _libraryItems;
    }
    return _libraryItems
        .where((item) => item.livre?.categorie?.nom == filtreActif)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          // Background Gradient for the top half
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
              NavBarAll(userName: _userName),
              // Contenu défilable
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadLibrary,
                  color: const Color(0xFFF59E0B),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Section
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Ma Bibliothèque",
                                  style: GoogleFonts.poppins(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                Text(
                                  "Continuez vos lectures en cours",
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.grey[400],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.grid_view_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Search and Filter
                        const CustomSearchBar(),
                        const SizedBox(height: 20),
                        FiltreLivres(
                          filtreActif: filtreActif,
                          categories: _categories,
                          onFiltreChange: (f) =>
                              setState(() => filtreActif = f),
                        ),
                        const SizedBox(height: 24),

                        if (_isLoading)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(60.0),
                              child: CircularProgressIndicator(
                                color: Color(0xFFF59E0B),
                                strokeWidth: 3,
                              ),
                            ),
                          )
                        else if (_error != null)
                          _buildErrorState()
                        else if (_libraryItems.isEmpty)
                          _buildEmptyState()
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _getFilteredBooks().length,
                            itemBuilder: (context, index) {
                              final item = _getFilteredBooks()[index];
                              final book = item.livre;

                              if (book == null) return const SizedBox.shrink();

                              return GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => BookDetailPage(
                                        book: book,
                                        isOwned: true,
                                      ),
                                    ),
                                  );
                                },
                                child: LivreCard(
                                  titre: book.titre,
                                  auteur: book.authorName,
                                  categorie: book.categorie?.nom,
                                  progression:
                                      (book.progressions != null &&
                                          book.progressions!.isNotEmpty)
                                      ? book.progressions!.first.pourcentage
                                            .toInt()
                                      : 0,
                                  couleurs: const [
                                    Color(0xFF6A5AE0),
                                    Color(0xFF8B82F6),
                                  ],
                                  imageUrl: book.imageCouverture,
                                  dateAcquisition: item.creeLe,
                                ),
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
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.library_books_rounded,
                size: 48,
                color: const Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "Votre bibliothèque est vide",
              style: GoogleFonts.poppins(
                fontSize: 18,
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Explorez le marketplace pour ajouter des livres",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[400],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                // Naviguer vers le marketplace
                MainNavBar.mainNavBarKey.currentState?.navigateToMarketplace();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF06B6D4),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text("Découvrir des livres"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 16),
            Text(_error!, style: GoogleFonts.poppins(color: Colors.white)),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _loadLibrary,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text("Réessayer"),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF06B6D4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
