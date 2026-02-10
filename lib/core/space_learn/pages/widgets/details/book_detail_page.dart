import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/bookModel.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/details/payment_page.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/bookService.dart';
import 'reading_page.dart';

class BookDetailPage extends StatefulWidget {
  final BookModel book;
  final bool isOwned;

  const BookDetailPage({super.key, required this.book, this.isOwned = false});

  @override
  State<BookDetailPage> createState() => _BookDetailPageState();
}

class _BookDetailPageState extends State<BookDetailPage> {
  final BookService _bookService = BookService();
  List<BookModel> _authorBooks = [];
  List<BookModel> _categoryBooks = [];
  bool _isLoadingRelated = true;

  @override
  void initState() {
    super.initState();
    _loadRelatedBooks();
  }

  Future<void> _loadRelatedBooks() async {
    try {
      final futures = [
        _bookService.getBooksByAuthorId(widget.book.auteurId),
        if (widget.book.categorieId != null &&
            widget.book.categorieId!.isNotEmpty)
          _bookService.getBooksByCategory(widget.book.categorieId!),
      ];

      final results = await Future.wait(futures);

      if (mounted) {
        setState(() {
          // Filter out the current book
          _authorBooks = results[0]
              .where((b) => b.id != widget.book.id)
              .toList();

          if (results.length > 1) {
            _categoryBooks = results[1]
                .where((b) => b.id != widget.book.id)
                .toList();
          }
          _isLoadingRelated = false;
        });
      }
    } catch (e) {
      print("Error loading related books: $e");
      if (mounted) {
        setState(() => _isLoadingRelated = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String formattedDate = widget.book.creeLe != null
        ? "${widget.book.creeLe!.day}/${widget.book.creeLe!.month}/${widget.book.creeLe!.year}"
        : "N/A";

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          widget.isOwned ? 'Lecture' : 'Détails de l\'achat',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header with Gradient and Book Cover
            Stack(
              children: [
                Container(
                  height: 350,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 140, left: 20, right: 20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Book Cover with premium shadow
                      Hero(
                        tag: 'book-${widget.book.id}',
                        child: Container(
                          height: 180,
                          width: 120,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child:
                                widget.book.imageCouverture != null &&
                                    widget.book.imageCouverture!.isNotEmpty &&
                                    !widget.book.imageCouverture!.contains(
                                      'example.com',
                                    )
                                ? Image.network(
                                    widget.book.imageCouverture!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: Colors.white,
                                        child: const Icon(
                                          Icons.book,
                                          size: 50,
                                          color: Color(0xFFD97706),
                                        ),
                                      );
                                    },
                                  )
                                : Container(
                                    color: Colors.white,
                                    child: const Icon(
                                      Icons.book,
                                      size: 50,
                                      color: Color(0xFFD97706),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      // Quick Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.book.titre,
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                height: 1.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Par ${widget.book.authorName}',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.9),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Compact Stats Row in Header
                            Row(
                              children: [
                                _buildHeaderStat(
                                  Icons.star_rounded,
                                  widget.book.noteMoyenne.toStringAsFixed(1),
                                ),
                                const SizedBox(width: 12),
                                _buildHeaderStat(
                                  Icons.download_rounded,
                                  widget.book.telechargements.toString(),
                                ),
                                const SizedBox(width: 12),
                                _buildHeaderStat(
                                  Icons.calendar_today_rounded,
                                  formattedDate,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                widget.book.format.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),

            // Main Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),

                  // Price and Buy Button (Only if not owned)
                  if (!widget.isOwned)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Prix total",
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  color: const Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: "${widget.book.prix} ",
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    TextSpan(
                                      text: "FCFA",
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.normal,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                  style: const TextStyle(
                                    fontSize: 32,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 60,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        PaymentPage(book: widget.book.toJson()),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF59E0B),
                                foregroundColor: Colors.white,
                                elevation: 8,
                                shadowColor: const Color(
                                  0xFFF59E0B,
                                ).withOpacity(0.4),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Text(
                                'Acheter maintenant',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    // Reading Button (If owned)
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  ReadingPage(book: widget.book.toJson()),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF59E0B),
                          foregroundColor: Colors.white,
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          'Commencer la lecture',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 32),

                  // Description
                  Text(
                    'À propos de ce livre',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.book.description,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      color: const Color(0xFF475569),
                      height: 1.7,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Related Sections
                  if (_isLoadingRelated)
                    const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFF59E0B),
                      ),
                    )
                  else ...[
                    if (_authorBooks.isNotEmpty)
                      _buildRelatedSection(
                        "Livres du même auteur",
                        _authorBooks,
                      ),

                    if (_categoryBooks.isNotEmpty)
                      _buildRelatedSection(
                        "Recommandations (Même catégorie)",
                        _categoryBooks,
                      ),
                  ],

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRelatedSection(String title, List<BookModel> books) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: books.length,
            itemBuilder: (context, index) {
              final book = books[index];
              return _buildBookCard(book);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBookCard(BookModel book) {
    return GestureDetector(
      onTap: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => BookDetailPage(
              book: book,
              isOwned: false,
            ), // On assume non possédé pour le moment
          ),
        );
      },
      child: Container(
        width: 110,
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child:
                    book.imageCouverture != null &&
                        book.imageCouverture!.isNotEmpty
                    ? Image.network(
                        book.imageCouverture!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.grey[200],
                          child: const Icon(
                            Icons.book,
                            color: Color(0xFFF59E0B),
                          ),
                        ),
                      )
                    : Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.book, color: Color(0xFFF59E0B)),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              book.titre,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1E293B),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              "${book.prix} FCFA",
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: const Color(0xFFF59E0B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderStat(IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white70, size: 14),
        const SizedBox(width: 4),
        Text(
          value,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
