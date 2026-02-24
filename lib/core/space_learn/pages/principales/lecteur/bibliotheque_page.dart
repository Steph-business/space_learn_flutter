import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:space_learn_flutter/core/themes/layout/nav_bar_all.dart';
import 'package:space_learn_flutter/core/themes/layout/recherche_bar.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/lecteur/bibliotheque/livre_grid_card.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/lecteur/bibliotheque/ajouter_grid_card.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/details/book_detail_page.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/libraryService.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/library_model.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/bookService.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/authServices.dart';
import 'package:space_learn_flutter/core/utils/token_storage.dart';

import 'package:space_learn_flutter/core/utils/api_routes.dart';
import 'package:space_learn_flutter/core/themes/layout/nav_bar_lecteur.dart';

class BibliothequePage extends StatefulWidget {
  const BibliothequePage({super.key});

  @override
  State<BibliothequePage> createState() => _BibliothequePageState();
}

class _BibliothequePageState extends State<BibliothequePage> {
  final LibraryService _libraryService = LibraryService();
  final BookService _bookService = BookService();
  final AuthService _authService = AuthService();
  List<LibraryModel> _libraryItems = [];

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

      if (mounted) {
        setState(() {
          _libraryItems = enriched;

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

  String _selectedTab = "Tous";
  String _sortOption = "Dernière lecture";

  List<LibraryModel> _getFilteredBooks() {
    List<LibraryModel> result = _libraryItems;

    // Filter by Search if we had it, but for now we focus on tabs
    // Filter by tab
    if (_selectedTab == "En cours") {
      result = result.where((item) {
        final progress =
            (item.livre?.progressions != null &&
                item.livre!.progressions!.isNotEmpty)
            ? item.livre!.progressions!.first.pourcentage
            : 0;
        return progress > 0 && progress < 100;
      }).toList();
    } else if (_selectedTab == "Terminés") {
      result = result.where((item) {
        final progress =
            (item.livre?.progressions != null &&
                item.livre!.progressions!.isNotEmpty)
            ? item.livre!.progressions!.first.pourcentage
            : 0;
        return progress >= 100;
      }).toList();
    }

    // Sort
    if (_sortOption == "A-Z") {
      result.sort(
        (a, b) => (a.livre?.titre ?? "").compareTo(b.livre?.titre ?? ""),
      );
    }

    return result;
  }

  Widget _buildTopTabs() {
    final tabs = ["Tous", "En cours", "Terminés"];
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF1E293B), width: 1)),
      ),
      child: Row(
        children: tabs.map((tab) {
          final isSelected = _selectedTab == tab;
          return GestureDetector(
            onTap: () => setState(() => _selectedTab = tab),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              margin: const EdgeInsets.only(right: 24),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isSelected
                        ? const Color(0xFF0EA5E9)
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              child: Text(
                tab,
                style: GoogleFonts.poppins(
                  color: isSelected ? Colors.white : Colors.grey[500],
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 15,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFilterRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildActionChip(
            "Dernière lecture",
            Icons.swap_vert,
            isSelected: _sortOption == "Dernière lecture",
            onTap: () => setState(() => _sortOption = "Dernière lecture"),
          ),
          const SizedBox(width: 12),
          _buildActionChip(
            "Genre",
            Icons.filter_list,
            isSelected: false,
            onTap: () {},
          ),
          const SizedBox(width: 12),
          _buildActionChip(
            "A-Z",
            Icons.sort_by_alpha,
            isSelected: _sortOption == "A-Z",
            onTap: () => setState(() => _sortOption = "A-Z"),
          ),
        ],
      ),
    );
  }

  Widget _buildActionChip(
    String label,
    IconData icon, {
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E293B) : const Color(0xFF192336),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.grey[300], size: 16),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                color: Colors.grey[300],
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
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
                        const SizedBox(height: 16),

                        // Tabs
                        _buildTopTabs(),
                        const SizedBox(height: 16),

                        // Filters Action Chips
                        _buildFilterRow(),
                        const SizedBox(height: 24),

                        if (_isLoading)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(60.0),
                              child: CircularProgressIndicator(
                                color: Color(0xFF0EA5E9),
                                strokeWidth: 3,
                              ),
                            ),
                          )
                        else if (_error != null)
                          _buildErrorState()
                        else if (_libraryItems.isEmpty)
                          _buildEmptyState()
                        else
                          GridView.builder(
                            shrinkWrap: true,
                            padding: const EdgeInsets.only(bottom: 40),
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 24,
                                  childAspectRatio: 0.55,
                                ),
                            itemCount: _getFilteredBooks().length + 1,
                            itemBuilder: (context, index) {
                              if (index == _getFilteredBooks().length) {
                                return AjouterGridCard(
                                  onTap: () {
                                    MainNavBar.mainNavBarKey.currentState
                                        ?.navigateToMarketplace();
                                  },
                                );
                              }

                              final item = _getFilteredBooks()[index];
                              final book = item.livre;

                              return GestureDetector(
                                onTap: () {
                                  if (book == null) return;
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
                                child: LivreGridCard(
                                  titre: book?.titre ?? "Inconnu",
                                  auteur: book?.authorName ?? "Auteur inconnu",
                                  progression:
                                      (book?.progressions != null &&
                                          book!.progressions!.isNotEmpty)
                                      ? book.progressions!.first.pourcentage
                                      : 0,
                                  couleurs: const [
                                    Color(0xFF6A5AE0),
                                    Color(0xFF8B82F6),
                                  ],
                                  imageUrl: book?.imageCouverture,
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
