import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';

import 'package:space_learn_flutter/core/space_learn/pages/widgets/auteur/livres/publications_liste.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/ecrivain/ajouter_livre_page.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/bookService.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/authServices.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/book_model.dart';
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

      final token = await TokenStorage.getToken();
      if (token == null) {
        setState(() {
          _error = "Session expirée. Veuillez vous reconnecter.";
          _isLoading = false;
        });
        return;
      }

      final user = await _authService.getUser(token);
      if (user == null) {
        setState(() {
          _error = "Utilisateur non trouvé.";
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
          _error = "Erreur lors du chargement des livres.";
          _isLoading = false;
        });
      }
    }
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
        books = List.from(books)
          ..sort((a, b) => b.telechargements.compareTo(a.telechargements));
        break;
    }

    return books;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.scaffoldBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Iconsax.arrow_left_2, color: AppColors.textPrimary, size: 20),
          onPressed: () {
            if (widget.onBackPressed != null) {
              widget.onBackPressed!();
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
        title: Text(
          "MES LIVRES",
          style: GoogleFonts.poppins(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AjouterLivrePage(),
                  ),
                );
                if (result == true) _loadBooks();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.secondaryVariant.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.secondaryVariant.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Iconsax.add,
                      size: 16,
                      color: AppColors.secondaryVariant,
                    ),
                    SizedBox(width: 6),
                    Text(
                      "Publier",
                      style: GoogleFonts.poppins(
                        color: AppColors.secondaryVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Stats Sessions (Three individual cards) ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  _buildStatSession(
                    "${_books.fold<int>(0, (sum, b) => sum + b.telechargements)}",
                    "Lectures",
                    Iconsax.eye,
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
                  Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.textPrimary.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.textPrimary.withOpacity(0.06)),
                    ),
                    child: TextField(
                      style: GoogleFonts.poppins(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value.toLowerCase();
                        });
                      },
                      decoration: InputDecoration(
                        hintText: "Rechercher par titre...",
                        hintStyle: GoogleFonts.poppins(
                          color: AppColors.textPrimary.withOpacity(0.2),
                          fontSize: 14,
                        ),
                        prefixIcon: Icon(
                          Iconsax.search_status,
                          color: AppColors.textPrimary.withOpacity(0.3),
                          size: 20,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 14,
                        ),
                      ),
                    ),
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
                          onTap: () => setState(() => _selectedFilter = filter),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: const BoxDecoration(),
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
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Iconsax.warning_2,
                            size: 48,
                            color: AppColors.error.withOpacity(0.6),
                          ),
                          SizedBox(height: 16),
                          Text(
                            _error!,
                            style: GoogleFonts.poppins(
                              color: AppColors.error,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 16),
                          GestureDetector(
                            onTap: _loadBooks,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.secondaryVariant.withOpacity(
                                  0.15,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                "Réessayer",
                                style: GoogleFonts.poppins(
                                  color: AppColors.secondaryVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
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
                                  color: AppColors.secondaryVariant.withOpacity(
                                    0.15,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
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
                  : SingleChildScrollView(
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
          ],
        ),
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
          color: AppColors.textPrimary.withOpacity(0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.textPrimary.withOpacity(0.06)),
          
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