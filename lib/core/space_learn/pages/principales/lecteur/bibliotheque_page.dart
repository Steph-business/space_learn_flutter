import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:space_learn_flutter/core/themes/layout/nav_bar_all.dart';
import 'package:space_learn_flutter/core/themes/layout/recherche_bar.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/lecteur/bibliotheque/livre_card.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/details/book_detail_page.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/libraryService.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/library_model.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/bookService.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/authServices.dart';
import 'package:space_learn_flutter/core/utils/token_storage.dart';

import 'package:space_learn_flutter/core/themes/layout/nav_bar_lecteur.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/readingProgressService.dart';
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
  String _statusFiltre = "Tous";
  String _sortOption = "Dernière lecture";
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();
  bool _isGridView = false;

  @override
  void initState() {
    super.initState();
    _loadLibrary();
    _loadUserInfo();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUserInfo() async {
    try {
      final token = await TokenStorage.getToken();
      if (token != null) {
        final user = await _authService.getUser(token);
        if (user != null && mounted) {
          setState(() {
            _userName = user.nomComplet;
          });
        }
      }
    } catch (e) {
    }
  }

  Future<void> _loadLibrary() async {
    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _error = null;
        });
      }

      final token = await TokenStorage.getToken();
      if (token == null) throw Exception("Non connecté");
      final items = await _libraryService.getUserLibrary(token);
      // If the library items don't include the full `livre` object (backend may
      // return only `livre_id`), fetch missing book details so we can display
      // author names and other metadata.
      final List<LibraryModel> enriched = [];
      for (var i = 0; i < items.length; i++) {
        final item = items[i];
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
      }

      final Map<String, ReadingActivityModel> progressMap = {
        for (var p in allProgress) p.livreId: p,
      };

      // 💉 Map progressions to books using a robust approach
      final finalItems = enriched.map((item) {
        if (item.livre != null) {
          final p = progressMap[item.livre!.id];
          if (p != null) {
            // Use copyWith to preserve all book fields while updating progressions
            return LibraryModel(
              id: item.id,
              utilisateurId: item.utilisateurId,
              livreId: item.livreId,
              acquisVia: item.acquisVia,
              creeLe: item.creeLe,
              livre: item.livre!.copyWith(progressions: [p]),
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
      if (mounted) {
        setState(() {
          _error = "Erreur lors du chargement de la bibliothèque";
          _isLoading = false;
        });
      }
    }
  }

  List<LibraryModel> _getFilteredBooks() {
    List<LibraryModel> filtered = List.from(_libraryItems);

    // Apply Search Filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((item) {
        final title = item.livre?.titre.toLowerCase() ?? "";
        return title.contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // Apply Status Filter
    if (_statusFiltre != "Tous") {
      filtered = filtered.where((item) {
        final progress =
            (item.livre?.progressions != null &&
                item.livre!.progressions!.isNotEmpty)
            ? item.livre!.progressions!.first.pourcentage.toDouble()
            : 0.0;
        if (_statusFiltre == "En cours") {
          return progress > 0 && progress < 100;
        } else if (_statusFiltre == "Terminés") {
          return progress >= 100;
        }
        return true;
      }).toList();
    }

    // Apply Category Filter
    if (filtreActif != "Tous") {
      filtered = filtered
          .where((item) => item.livre?.categorie?.nom == filtreActif)
          .toList();
    }

    // Apply Sorting
    if (_sortOption == "Dernière lecture") {
      filtered.sort((a, b) {
        final dateA =
            (a.livre?.progressions != null && a.livre!.progressions!.isNotEmpty)
            ? a.livre!.progressions!.first.majLe ?? DateTime(0)
            : a.creeLe ?? DateTime(0);
        final dateB =
            (b.livre?.progressions != null && b.livre!.progressions!.isNotEmpty)
            ? b.livre!.progressions!.first.majLe ?? DateTime(0)
            : b.creeLe ?? DateTime(0);
        return dateB.compareTo(dateA); // Newest first
      });
    } else if (_sortOption == "A-Z") {
      filtered.sort((a, b) {
        final titleA = a.livre?.titre.toLowerCase() ?? "";
        final titleB = b.livre?.titre.toLowerCase() ?? "";
        return titleA.compareTo(titleB);
      });
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: Column(
        children: [
          // En-tête fixe
          NavBarAll(userName: _userName),
          // Contenu défilable
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadLibrary,
              color: AppColors.warning,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Row with Search and Views Toggle
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
                        SizedBox(width: 16),
                        GestureDetector(
                          onTap: () =>
                              setState(() => _isGridView = !_isGridView),
                          child: Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.cardBackground,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _isGridView
                                    ? AppColors.primary
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
                    SizedBox(height: 12),

                    // Status Filter Tabs
                    Row(
                      children: [
                        _buildStatusTab("Tous"),
                        SizedBox(width: 32),
                        _buildStatusTab("En cours"),
                        SizedBox(width: 32),
                        _buildStatusTab("Terminés"),
                      ],
                    ),
                    SizedBox(height: 24),

                    // Sort and Genre Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          _buildSortChip("Dernière lecture", Icons.swap_vert),
                          SizedBox(width: 12),
                          _buildGenreChip(),
                          SizedBox(width: 12),
                          _buildSortChip("A-Z", Icons.sort_by_alpha),
                        ],
                      ),
                    ),
                    SizedBox(height: 24),

                    if (_isLoading)
                      Center(
                        child: Padding(
                          padding: EdgeInsets.all(60.0),
                          child: Text(
                            "Chargement...",
                            style: GoogleFonts.poppins(color: AppColors.textSecondary),
                          ),
                        ),
                      )
                    else if (_error != null)
                      _buildErrorState()
                    else if (_libraryItems.isEmpty)
                      _buildEmptyState()
                    else if (_isGridView)
                      GridView.builder(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.7,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                            ),
                        itemCount: _getFilteredBooks().length,
                        itemBuilder: (context, index) {
                          final item = _getFilteredBooks()[index];
                          final book = item.livre;
                          if (book == null) return const SizedBox.shrink();

                          return GestureDetector(
                            onTap: () => _openBookDetails(book),
                            child: LivreGridCard(
                              titre: book.titre,
                              auteur: book.authorName,
                              progression:
                                  (book.progressions != null &&
                                      book.progressions!.isNotEmpty)
                                  ? book.progressions!.first.pourcentage.toInt()
                                  : 0,
                              couleurs: [
                                AppColors.purple,
                                AppColors.indigoLight,
                              ],
                              imageUrl: book.imageCouverture,
                            ),
                          );
                        },
                      )
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
                            onTap: () => _openBookDetails(book),
                            child: LivreCard(
                              titre: book.titre,
                              auteur: book.authorName,
                              categorie: book.categorie?.nom,
                              progression:
                                  (book.progressions != null &&
                                      book.progressions!.isNotEmpty)
                                  ? book.progressions!.first.pourcentage.toInt()
                                  : 0,
                              couleurs: [
                                AppColors.purple,
                                AppColors.indigoLight,
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
    );
  }

  void _openBookDetails(dynamic book) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookDetailPage(book: book, isOwned: true),
      ),
    ).then((_) {
      // Refresh library to show updated progress
      _loadLibrary();
    });
  }

  Widget _buildStatusTab(String label) {
    bool isSelected = _statusFiltre == label;
    return GestureDetector(
      onTap: () => setState(() => _statusFiltre = label),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppColors.primaryLight : AppColors.textSecondary,
              ),
            ),
          ),
          if (isSelected)
            Container(
              height: 3,
              width: (label.length * 8.0) + 8, // Simple heuristic for width
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(2),
              ),
            )
          else
            SizedBox(height: 3),
        ],
      ),
    );
  }

  Widget _buildSortChip(String label, IconData icon) {
    bool isActive = _sortOption == label;
    return GestureDetector(
      onTap: () => setState(() => _sortOption = label),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? AppColors.cardBackground : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? AppColors.primaryLight : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? AppColors.primaryLight : AppColors.textPrimary,
              size: 18,
            ),
            SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                color: isActive ? AppColors.primaryLight : AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenreChip() {
    bool hasActiveGenre = filtreActif != "Tous";
    return GestureDetector(
      onTap: _showGenrePicker,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasActiveGenre ? AppColors.primaryLight : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.tune_rounded,
              color: hasActiveGenre ? AppColors.primaryLight : AppColors.textPrimary,
              size: 18,
            ),
            SizedBox(width: 8),
            Text(
              hasActiveGenre ? "Genre: $filtreActif" : "Genre",
              style: GoogleFonts.poppins(
                color: hasActiveGenre ? AppColors.primaryLight : AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showGenrePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.scaffoldBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Sélectionner un Genre",
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 16),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    final isSelected = cat == filtreActif;
                    return ListTile(
                      title: Text(
                        cat,
                        style: GoogleFonts.poppins(
                          color: isSelected
                              ? AppColors.primaryLight
                              : Colors.white,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(
                              Icons.check,
                              color: AppColors.primaryLight,
                            )
                          : null,
                      onTap: () {
                        setState(() => filtreActif = cat);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
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
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.library_books_rounded,
                size: 48,
                color: AppColors.slateLight,
              ),
            ),
            SizedBox(height: 24),
            Text(
              "Votre bibliothèque est vide",
              style: GoogleFonts.poppins(
                fontSize: 18,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 8),
            Text(
              "Explorez le marketplace pour ajouter des livres",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                // Naviguer vers le marketplace
                MainNavBar.mainNavBarKey.currentState?.navigateToMarketplace();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Text("Découvrir des livres"),
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
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: Colors.redAccent,
            ),
            SizedBox(height: 16),
            Text(_error!, style: GoogleFonts.poppins(color: AppColors.textPrimary)),
            SizedBox(height: 16),
            TextButton.icon(
              onPressed: _loadLibrary,
              icon: Icon(Icons.refresh_rounded),
              label: Text("Réessayer"),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}