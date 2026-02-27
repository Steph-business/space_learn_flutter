import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/themes/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/bookService.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/book_model.dart';
import '../../widgets/details/book_detail_page.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/libraryService.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/library_model.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/user_model.dart';
import 'package:space_learn_flutter/core/utils/token_storage.dart';

class RecherchePage extends StatefulWidget {
  const RecherchePage({super.key});

  @override
  State<RecherchePage> createState() => _RecherchePageState();
}

class _RecherchePageState extends State<RecherchePage> {
  final _searchController = TextEditingController();
  final _bookService = BookService();
  final _libraryService = LibraryService();
  List<BookModel> _searchResults = [];
  Set<String> _ownedBookIds = {};
  bool _isLoading = false;
  String _query = "";

  void _onSearch(String value) async {
    if (value.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _query = "";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _query = value;
    });

    try {
      final token = await TokenStorage.getToken();
      final futures = [
        _bookService.getAllBooks(),
        if (token != null)
          _libraryService.getUserLibrary(token)
        else
          Future.value(<LibraryModel>[]),
      ];

      final results = await Future.wait(futures);
      final allBooks = results[0] as List<BookModel>;
      final library = results[1] as List<LibraryModel>;

      // Enrich author names using library data
      final Map<String, String> authorNames = {};
      for (var item in library) {
        if (item.auteurNom != null && item.auteurNom!.isNotEmpty) {
          authorNames[item.livreId] = item.auteurNom!;
        } else if (item.livre?.auteur != null) {
          authorNames[item.livreId] = item.livre!.auteur!.nomComplet;
        }
      }

      final enrichedBooks = allBooks.map((book) {
        if (authorNames.containsKey(book.id) &&
            (book.auteur == null ||
                book.auteur!.nomComplet == 'Auteur inconnu')) {
          return book.copyWith(
            auteur: UserModel(
              id: book.auteurId,
              profilId: book.auteurId,
              email: '',
              nomComplet: authorNames[book.id]!,
              isProfileComplete: false,
            ),
          );
        }
        return book;
      }).toList();

      if (mounted) {
        setState(() {
          _ownedBookIds = library.map((e) => e.livreId).toSet();
        });
      }

      final filtered = enrichedBooks.where((book) {
        final titleMatch = book.titre.toLowerCase().contains(
          value.toLowerCase(),
        );
        final authorMatch =
            book.authorName.toLowerCase().contains(value.toLowerCase()) ||
            book.auteurId.toLowerCase().contains(value.toLowerCase());
        return titleMatch || authorMatch;
      }).toList();

      setState(() {
        _searchResults = filtered;
      });
    } catch (e) {
      debugPrint("Error searching books: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.scaffoldBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Iconsax.arrow_left_2, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Container(
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(10),
          ),
          child: TextField(
            controller: _searchController,
            autofocus: true,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            onChanged: _onSearch,
            decoration: InputDecoration(
              hintText: "Rechercher...",
              hintStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
              prefixIcon: const Icon(
                Iconsax.search_normal,
                color: Colors.grey,
                size: 18,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? Center(
              child: Text(
                "Recherche en cours...",
                style: GoogleFonts.poppins(color: Colors.white70),
              ),
            )
          : _query.isEmpty
          ? _buildEmptyState(
              "Saisissez quelque chose pour commencer la recherche",
            )
          : _searchResults.isEmpty
          ? _buildEmptyState("Aucun résultat trouvé pour \"$_query\"")
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final book = _searchResults[index];
                return _buildSearchResultTile(book);
              },
            ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Iconsax.search_status,
            size: 64,
            color: Colors.white.withOpacity(0.1),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.greyMedium14,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResultTile(BookModel book) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BookDetailPage(
              book: book,
              isOwned: _ownedBookIds.contains(book.id),
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 90,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                image:
                    (book.imageCouverture != null &&
                        book.imageCouverture!.isNotEmpty)
                    ? DecorationImage(
                        image: NetworkImage(book.imageCouverture!),
                        fit: BoxFit.cover,
                      )
                    : null,
                color: Colors.white10,
              ),
              child:
                  (book.imageCouverture == null ||
                      book.imageCouverture!.isEmpty)
                  ? const Icon(Icons.book, color: Colors.white24)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.titre,
                    style: AppTextStyles.button15,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Par ${book.authorName}",
                    style: GoogleFonts.poppins(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    book.description,
                    style: AppTextStyles.grey11,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "${book.prix} FCFA",
                    style: AppTextStyles.withColor(AppTextStyles.cardTitle, AppColors.primary),
                  ),
                ],
              ),
            ),
            const Icon(Iconsax.arrow_right_3, color: Colors.white24, size: 18),
          ],
        ),
      ),
    );
  }
}
