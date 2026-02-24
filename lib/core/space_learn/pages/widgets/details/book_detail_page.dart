import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/book_model.dart';
import 'package:provider/provider.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/cart_provider.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/bookService.dart';
import 'reading_page.dart';
import 'payment_page.dart';

class BookDetailPage extends StatefulWidget {
  final BookModel book;
  final bool isOwned;
  final bool showCart;

  const BookDetailPage({
    super.key,
    required this.book,
    this.isOwned = false,
    this.showCart = true,
  });

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
    final book = widget.book;
    final isOwned = widget.isOwned;

    return Scaffold(
      backgroundColor: const Color(0xFF111827), // Dark slate UI background
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        elevation: 0,
        centerTitle: true,
        title: Text(
          'DÉTAILS DU LIVRE',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 12,
            letterSpacing: 1.2,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 18,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white, size: 20),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.bookmark, color: Colors.white, size: 20),
            onPressed: () {},
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 120), // Space for bottom bar
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Book Cover Area
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF374151), // lighter grey
                        Color(0xFF111827), // dark grey to match scaffold
                      ],
                      stops: [0.0, 1.0],
                    ),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 30),
                      // The Image Card
                      Hero(
                        tag: 'book-${book.id}',
                        child: Container(
                          height: 240,
                          width: 240,
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFF1F5F9,
                            ), // Light bg for image as in mockup
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 40,
                                offset: const Offset(0, 20),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child:
                                book.imageCouverture != null &&
                                    book.imageCouverture!.isNotEmpty &&
                                    !book.imageCouverture!.contains(
                                      'example.com',
                                    )
                                ? Image.network(
                                    book.imageCouverture!,
                                    fit: BoxFit.cover,
                                    height: 240,
                                    width: 240,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Icon(
                                        Icons.book,
                                        size: 80,
                                        color: Color(0xFFD97706),
                                      );
                                    },
                                  )
                                : const Icon(
                                    Icons.book,
                                    size: 80,
                                    color: Color(0xFFD97706),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                      // Title & Author
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          book.titre,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        book.authorName,
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF06B6D4), // Cyan
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Rating Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildStars(
                            book.noteMoyenne > 0 ? book.noteMoyenne : 4.8,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            book.noteMoyenne > 0
                                ? "${book.noteMoyenne.toStringAsFixed(1)} (${book.telechargements} avis)"
                                : "4.8 (2,450 avis)",
                            style: GoogleFonts.poppins(
                              color: Colors.grey[400],
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),

                // Synopsis
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Synopsis',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        book.description.isEmpty
                            ? "J'ai libéré des princesses. J'ai incendié la ville de Trebon. J'ai suivi des pistes au clair de lune que personne n'ose évoquer durant le jour. J'ai conversé avec des dieux, aimé des femmes et écrit des chansons qui font pleurer les ménestrels..."
                            : book.description,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.grey[300],
                          height: 1.6,
                        ),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Lire la suite ⌄',
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF06B6D4),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      const SizedBox(height: 40),

                      // À propos de l'auteur
                      Text(
                        'À propos de l\'auteur',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1F2937),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.05),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 30,
                                  backgroundColor: const Color(
                                    0xFF22D3EE,
                                  ).withOpacity(0.1),
                                  child: const Icon(
                                    Icons.person,
                                    color: Color(0xFF22D3EE),
                                    size: 30,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        book.authorName,
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        "Auteur de best-sellers",
                                        style: GoogleFonts.poppins(
                                          color: Colors.grey[400],
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildSocialIcon(Icons.language, "Web"),
                                const SizedBox(width: 20),
                                _buildSocialIcon(Icons.facebook, "FB"),
                                const SizedBox(width: 20),
                                _buildSocialIcon(Icons.camera_alt, "IG"),
                                const SizedBox(width: 20),
                                _buildSocialIcon(
                                  Icons.alternate_email,
                                  "Email",
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Avis de la communauté
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Avis de la communauté',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Voir tout',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: const Color(0xFF06B6D4),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Dummy Reviews
                      _buildReviewCard(
                        "Julien M.",
                        "IL Y A 2 JOURS",
                        5,
                        "\"Une écriture magistrale. On ne lâche pas le livre avant la dernière page. Un classique instantané !\"",
                      ),
                      const SizedBox(height: 16),
                      _buildReviewCard(
                        "Sophie L.",
                        "IL Y A 1 SEMAINE",
                        5,
                        "\"L'univers est incroyablement riche. J'ai adoré le système de magie très scientifique.\"",
                      ),
                      const SizedBox(height: 24),

                      // Rejoindre la discussion Button
                      Container(
                        width: double.infinity,
                        height: 50,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF06B6D4).withOpacity(0.5),
                            width: 1.5,
                            style: BorderStyle.none,
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {},
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.chat_bubble_outline,
                                  color: Color(0xFF06B6D4),
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "Rejoindre la discussion",
                                  style: GoogleFonts.poppins(
                                    color: const Color(0xFF06B6D4),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Related Sections
                      if (!_isLoadingRelated) ...[
                        if (_authorBooks.isNotEmpty)
                          _buildRelatedSection("Du même auteur", _authorBooks),
                        if (_categoryBooks.isNotEmpty)
                          _buildRelatedSection(
                            "Livres similaires",
                            _categoryBooks,
                          ),
                      ] else ...[
                        const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF06B6D4),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Fixed Bottom Bar
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withOpacity(0.05),
                    width: 1,
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                child: !isOwned
                    ? widget.showCart
                          ? Row(
                              children: [
                                // Price
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "PRIX EBOOK",
                                      style: GoogleFonts.poppins(
                                        color: Colors.grey[500],
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    Text(
                                      "${book.prix}€",
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 32),
                                // Cart button
                                Container(
                                  height: 50,
                                  width: 50,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1F2937),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.1),
                                    ),
                                  ),
                                  child: IconButton(
                                    onPressed: () {
                                      context.read<CartProvider>().addItem(
                                        book,
                                      );
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            "${book.titre} ajouté au panier",
                                          ),
                                          backgroundColor: const Color(
                                            0xFF06B6D4,
                                          ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.shopping_cart_outlined,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Buy button
                                Expanded(
                                  child: SizedBox(
                                    height: 50,
                                    child: ElevatedButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => PaymentPage(
                                              book: book.toJson(),
                                            ),
                                          ),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF22D3EE,
                                        ),
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.shopping_bag,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Acheter',
                                            style: GoogleFonts.poppins(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Center(
                              child: Text(
                                "Consultation Auteur",
                                style: GoogleFonts.poppins(
                                  color: Colors.white70,
                                ),
                              ),
                            )
                    : SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    ReadingPage(book: book.toJson()),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF06B6D4),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.menu_book, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Commencer la lecture',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ],
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

  Widget _buildStars(double rating) {
    int fullStars = rating.floor();
    bool hasHalfStar = (rating - fullStars) >= 0.5;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        if (index < fullStars) {
          return const Icon(Icons.star, color: Color(0xFFF59E0B), size: 18);
        } else if (index == fullStars && hasHalfStar) {
          return const Icon(
            Icons.star_half,
            color: Color(0xFFF59E0B),
            size: 18,
          );
        } else {
          return const Icon(
            Icons.star_border,
            color: Color(0xFFF59E0B),
            size: 18,
          );
        }
      }),
    );
  }

  Widget _buildReviewCard(String name, String time, int stars, String comment) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFF06B6D4).withOpacity(0.2),
                child: const Icon(
                  Icons.person,
                  color: Color(0xFF06B6D4),
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      time,
                      style: GoogleFonts.poppins(
                        color: Colors.grey[500],
                        fontSize: 10,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: List.generate(5, (index) {
                  return Icon(
                    index < stars ? Icons.star : Icons.star_border,
                    color: const Color(0xFFF59E0B),
                    size: 14,
                  );
                }),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            comment,
            style: GoogleFonts.poppins(
              color: Colors.grey[300],
              fontStyle: FontStyle.italic,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialIcon(IconData icon, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.05),
          ),
          child: Icon(icon, color: Colors.white70, size: 20),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 10),
        ),
      ],
    );
  }
}
