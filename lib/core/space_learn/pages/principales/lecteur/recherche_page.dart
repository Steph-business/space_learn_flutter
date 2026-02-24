import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/bookService.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/book_model.dart';
import '../../widgets/details/book_detail_page.dart';

class RecherchePage extends StatefulWidget {
  const RecherchePage({super.key});

  @override
  State<RecherchePage> createState() => _RecherchePageState();
}

class _RecherchePageState extends State<RecherchePage> {
  final _searchController = TextEditingController();
  final _bookService = BookService();
  List<BookModel> _searchResults = [];
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
      final allBooks = await _bookService.getAllBooks();
      // Simple client-side search for now
      final filtered = allBooks.where((book) {
        final titleMatch = book.titre.toLowerCase().contains(
          value.toLowerCase(),
        );
        final authorMatch = book.auteurId.toLowerCase().contains(
          value.toLowerCase(),
        ); // This isn't great but works as a fallback
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
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Iconsax.arrow_left_2, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Container(
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
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
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF06B6D4)),
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
            style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 14),
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
          MaterialPageRoute(builder: (context) => BookDetailPage(book: book)),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
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
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    book.description,
                    style: GoogleFonts.poppins(
                      color: Colors.grey[400],
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "${book.prix} FCFA",
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF06B6D4),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
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
