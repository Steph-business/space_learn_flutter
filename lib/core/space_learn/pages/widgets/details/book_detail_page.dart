import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/themes/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/book_model.dart';
import 'package:provider/provider.dart';
import 'package:iconsax/iconsax.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/cart_provider.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/bookService.dart';
import 'reading_page.dart';
import 'payment_page.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/review_model.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/review_service.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/favoriteService.dart';
import 'package:space_learn_flutter/core/utils/token_storage.dart';
import 'package:intl/intl.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/readingProgressService.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/readingActivityModel.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/libraryService.dart';
import 'all_reviews_page.dart';

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

  bool _isFavorite = false;
  bool _isLoadingFavorite = true;
  final FavoriteService _favoriteService = FavoriteService();
  final ReviewService _reviewService = ReviewService();
  BookModel? _fullBook;
  List<ReviewModel> _reviews = [];
  bool _isLoadingReviews = true;
  final LibraryService _libraryService = LibraryService();
  bool _isOwned = false;
  bool _isLoadingOwnership = true;

  final ReadingProgressService _readingProgressService =
      ReadingProgressService();
  ReadingActivityModel? _readingProgress;
  Set<String> _ownedBookIds = {};

  @override
  void initState() {
    super.initState();
    _isOwned = widget.isOwned;
    _loadFullBookDetails();
    _loadRelatedBooks();
    _checkFavoriteStatus();
    _loadReviews();
    _checkOwnershipStatus();
  }

  Future<void> _loadFullBookDetails() async {
    try {
      final token = await TokenStorage.getToken();
      final fullBook = await _bookService.getBookById(
        widget.book.id,
        authToken: token,
      );
      if (mounted) {
        setState(() {
          _fullBook = fullBook;
        });
      }
    } catch (e) {
      print("Erreur chargement détails complets : $e");
    }
  }

  Future<void> _checkOwnershipStatus() async {
    if (_isOwned) {
      _loadReadingProgress();
      setState(() => _isLoadingOwnership = false);
      return;
    }

    try {
      final token = await TokenStorage.getToken();
      if (token != null) {
        final library = await _libraryService.getUserLibrary(token);
        final found = library.any((item) => item.livreId == widget.book.id);
        if (mounted) {
          setState(() {
            _isOwned = found;
            _ownedBookIds = library.map((e) => e.livreId).toSet();
            _isLoadingOwnership = false;
          });
          if (_isOwned) {
            _loadReadingProgress();
          }
        }
      } else {
        if (mounted) setState(() => _isLoadingOwnership = false);
      }
    } catch (e) {
      print("Erreur check ownership : $e");
      if (mounted) setState(() => _isLoadingOwnership = false);
    }
  }

  Future<void> _loadReadingProgress() async {
    try {
      final token = await TokenStorage.getToken();
      if (token != null) {
        final progress = await _readingProgressService.getProgressByLivre(
          widget.book.id,
          token,
        );
        if (mounted) {
          setState(() {
            _readingProgress = progress;
          });
        }
      }
    } catch (e) {
      print("Erreur chargement progression : $e");
    }
  }

  Future<void> _checkFavoriteStatus() async {
    try {
      final token = await TokenStorage.getToken();
      if (token != null) {
        final favorites = await _favoriteService.getFavorites(token);
        if (mounted) {
          setState(() {
            _isFavorite = favorites.any((f) => f.livreId == widget.book.id);
            _isLoadingFavorite = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingFavorite = false);
      }
    } catch (e) {
      print("Erreur check favorie : $e");
      if (mounted) setState(() => _isLoadingFavorite = false);
    }
  }

  Future<void> _toggleFavorite() async {
    try {
      final token = await TokenStorage.getToken();
      if (token == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Veuillez vous connecter pour ajouter à ma favorie",
              ),
            ),
          );
        }
        return;
      }

      setState(() => _isLoadingFavorite = true);

      if (_isFavorite) {
        await _favoriteService.removeFavorite(widget.book.id, token);
      } else {
        await _favoriteService.addFavorite(widget.book.id, token);
      }

      if (mounted) {
        setState(() {
          _isFavorite = !_isFavorite;
          _isLoadingFavorite = false;
        });
      }
    } catch (e) {
      print("Erreur toggle favorie : $e");
      if (mounted) setState(() => _isLoadingFavorite = false);
    }
  }

  Future<void> _loadReviews() async {
    try {
      final reviews = await _reviewService.getBookReviews(widget.book.id);
      if (mounted) {
        setState(() {
          _reviews = reviews;
          _isLoadingReviews = false;
        });
      }
    } catch (e) {
      print("Erreur appel avis : $e");
      if (mounted) setState(() => _isLoadingReviews = false);
    }
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
    final book = _fullBook ?? widget.book;
    final isOwned = _isOwned;

    return Scaffold(
      backgroundColor: AppColors.darkSurface, // Dark slate UI background
      appBar: AppBar(
        backgroundColor: AppColors.darkSurface,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'DÉTAILS DU LIVRE',
          style: AppTextStyles.cardTitle12SemiBold,
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
            icon: _isLoadingFavorite
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: Padding(
                      padding: EdgeInsets.all(4),
                      child: Text(
                        "...",
                        style: TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ),
                  )
                : Icon(
                    _isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: _isFavorite ? Colors.red : Colors.white,
                    size: 20,
                  ),
            onPressed: _isLoadingFavorite ? null : _toggleFavorite,
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 120),
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
                      colors: [AppColors.surfaceVariant, AppColors.darkSurface],
                    ),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 30),
                      Container(
                        height: 240,
                        width: 168,
                        decoration: BoxDecoration(
                          color: AppColors.lightSurface,
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
                                  !book.imageCouverture!.contains('example.com')
                              ? Image.network(
                                  book.imageCouverture!,
                                  fit: BoxFit.cover,
                                  height: 240,
                                  width: 168,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(
                                        Icons.book,
                                        size: 60,
                                        color: AppColors.orange,
                                      ),
                                )
                              : const Icon(
                                  Icons.book,
                                  size: 60,
                                  color: AppColors.orange,
                                ),
                        ),
                      ),
                      const SizedBox(height: 40),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          book.titre,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.pageTitle,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        book.authorName,
                        style: AppTextStyles.withColor(AppTextStyles.subtitle, AppColors.primary),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (book.telechargements > 0 || _reviews.isNotEmpty)
                            Row(
                              children: [
                                (() {
                                  double avg = book.noteMoyenne;
                                  if (avg == 0 && _reviews.isNotEmpty) {
                                    avg =
                                        _reviews
                                            .map((e) => e.note)
                                            .reduce((a, b) => a + b) /
                                        _reviews.length;
                                  }
                                  return _buildStars(avg);
                                })(),
                                const SizedBox(width: 8),
                                Text(
                                  "${(() {
                                    double avg = book.noteMoyenne;
                                    if (avg == 0 && _reviews.isNotEmpty) {
                                      avg = _reviews.map((e) => e.note).reduce((a, b) => a + b) / _reviews.length;
                                    }
                                    return avg.toStringAsFixed(1);
                                  })()} (${book.telechargements > 0 ? book.telechargements : _reviews.length} avis)",
                                  style: GoogleFonts.poppins(
                                    color: Colors.grey[400],
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          if (book.nombreMessages > 0) ...[
                            const SizedBox(width: 12),
                            Icon(
                              Iconsax.message,
                              color: Colors.grey[400],
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "${book.nombreMessages} message${book.nombreMessages > 1 ? 's' : ''}",
                              style: GoogleFonts.poppins(
                                color: Colors.grey[400],
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
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
                        'Description',
                        style: AppTextStyles.sectionTitle,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        book.description.isEmpty
                            ? "Aucune description disponible pour ce livre."
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
                          color: AppColors.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      const SizedBox(height: 40),

                      // À propos de l'auteur
                      Text(
                        "À propos de ${book.authorName}",
                        style: AppTextStyles.sectionTitle,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
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
                                  backgroundImage:
                                      (book.auteur?.profilePhoto != null &&
                                          book.auteur!.profilePhoto!.isNotEmpty)
                                      ? NetworkImage(book.auteur!.profilePhoto!)
                                      : null,
                                  child:
                                      (book.auteur?.profilePhoto == null ||
                                          book.auteur!.profilePhoto!.isEmpty)
                                      ? const Icon(
                                          Icons.person,
                                          color: AppColors.primaryLight,
                                          size: 30,
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        book.authorName,
                                        style: AppTextStyles.subtitle,
                                      ),
                                      Text(
                                        book.auteur?.biography ??
                                            "Auteur passionné sur SpaceLearn",
                                        style: AppTextStyles.grey12,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
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
                            style: AppTextStyles.subtitle,
                          ),
                          InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AllReviewsPage(
                                    book: book,
                                    reviews: _reviews,
                                  ),
                                ),
                              );
                            },
                            child: Text(
                              'Voir tout',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Review list
                      if (_isLoadingReviews)
                        const Center(
                          child: Text(
                            "Chargement des avis...",
                            style: TextStyle(color: Colors.white70),
                          ),
                        )
                      else if (_reviews.isEmpty)
                        Text(
                          "Soyez le premier à donner votre avis !",
                          style: AppTextStyles.grey13,
                        )
                      else
                        ..._reviews.map(
                          (r) => Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _buildReviewCard(
                              r.nomUtilisateur ?? "Avis vérifié",
                              r.creeLe != null
                                  ? DateFormat('dd MMM yyyy').format(r.creeLe!)
                                  : "Récemment",
                              r.note,
                              r.commentaire ?? "",
                              r.photoProfil,
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),

                      if (isOwned)
                        Container(
                          width: double.infinity,
                          height: 54,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.primary.withOpacity(0.3),
                              width: 1.5,
                            ),
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primary.withOpacity(0.05),
                                AppColors.primary.withOpacity(0.01),
                              ],
                            ),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => _showReviewDialog(context),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.star_rounded,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Laisser un avis",
                                    style: AppTextStyles.withColor(AppTextStyles.button14, AppColors.primary),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                      const SizedBox(height: 40),

                      // Related Sections (Only shown if not owned)
                      if (!isOwned) ...[
                        if (!_isLoadingRelated) ...[
                          if (_authorBooks.isNotEmpty)
                            _buildRelatedSection(
                              "Autres livres de ${book.authorName}",
                              _authorBooks,
                            ),
                          if (_categoryBooks.isNotEmpty)
                            _buildRelatedSection(
                              "Livres similaires",
                              _categoryBooks,
                            ),
                        ] else ...[
                          const Center(
                            child: Text(
                              "Chargement...",
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),

          // Fixed Bottom Bar
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.darkSurface,
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withOpacity(0.05),
                    width: 1,
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                child: _isLoadingOwnership
                    ? const Center(
                        child: Text(
                          "...",
                          style: TextStyle(color: Colors.white),
                        ),
                      )
                    : !isOwned
                    ? widget.showCart
                          ? Row(
                              children: [
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
                                      "${book.prix} FCFA",
                                      style: AppTextStyles.heroTitle22,
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 32),
                                Container(
                                  height: 50,
                                  width: 50,
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceVariant,
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
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_readingProgress != null) ...[
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "Progression de lecture",
                                        style: GoogleFonts.poppins(
                                          color: Colors.grey[400],
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        "${_readingProgress!.pourcentage}%",
                                        style: GoogleFonts.poppins(
                                          color: AppColors.primary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value:
                                          _readingProgress!.pourcentage / 100,
                                      backgroundColor: Colors.white.withOpacity(
                                        0.05,
                                      ),
                                      valueColor:
                                          const AlwaysStoppedAnimation<Color>(
                                            AppColors.primary,
                                          ),
                                      minHeight: 6,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ReadingPage(
                                      book: book.toJson(),
                                      initialPage:
                                          _readingProgress?.chapitreCourant,
                                    ),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
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
                                    _readingProgress != null &&
                                            _readingProgress!.pourcentage > 0
                                        ? 'Continuer la lecture'
                                        : 'Commencer la lecture',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
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

  Widget _buildRelatedSection(String title, List<BookModel> books) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
        Text(
          title,
          style: AppTextStyles.sectionTitle,
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 280,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: books.length,
            padding: EdgeInsets.zero,
            clipBehavior: Clip.none,
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
              isOwned: _ownedBookIds.contains(book.id),
            ),
          ),
        );
      },
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover Image with Shadow and Rounded Corners
            Container(
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child:
                    book.imageCouverture != null &&
                        book.imageCouverture!.isNotEmpty &&
                        !book.imageCouverture!.contains('example.com')
                    ? Image.network(
                        book.imageCouverture!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _buildPlaceholderCover(),
                      )
                    : _buildPlaceholderCover(),
              ),
            ),
            const SizedBox(height: 12),
            // Title
            Text(
              book.titre,
              style: AppTextStyles.cardTitleSmallSemiBold,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 1),
            // Author
            Text(
              book.authorName,
              style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            // Price and Stats Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  book.prix > 0 ? "${book.prix} F" : "Gratuit",
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                Row(
                  children: [
                    if (book.noteMoyenne > 0) ...[
                      const Icon(
                        Icons.star_rounded,
                        color: AppColors.warning,
                        size: 10,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        book.noteMoyenne.toStringAsFixed(1),
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (book.nombreMessages > 0) ...[
                      const SizedBox(width: 6),
                      const Icon(
                        Iconsax.message,
                        color: Colors.white38,
                        size: 10,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        "${book.nombreMessages}",
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: Colors.white38,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderCover() {
    return Container(
      color: AppColors.surfaceVariant,
      child: const Center(
        child: Icon(Icons.book, color: AppColors.primary, size: 30),
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
          return const Icon(Icons.star, color: AppColors.warning, size: 18);
        } else if (index == fullStars && hasHalfStar) {
          return const Icon(
            Icons.star_half,
            color: AppColors.warning,
            size: 18,
          );
        } else {
          return const Icon(
            Icons.star_border,
            color: AppColors.warning,
            size: 18,
          );
        }
      }),
    );
  }

  Widget _buildReviewCard(
    String name,
    String time,
    int stars,
    String comment, [
    String? photoUrl,
  ]) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primary.withOpacity(0.2),
                backgroundImage:
                    (photoUrl != null &&
                        photoUrl.isNotEmpty &&
                        !photoUrl.contains('example.com'))
                    ? NetworkImage(photoUrl)
                    : null,
                child:
                    (photoUrl == null ||
                        photoUrl.isEmpty ||
                        photoUrl.contains('example.com'))
                    ? const Icon(
                        Icons.person,
                        color: AppColors.primary,
                        size: 18,
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: AppTextStyles.cardTitleSmall,
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
                    index < stars
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: AppColors.warning,
                    size: 16,
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

  void _showReviewDialog(BuildContext context) {
    int selectedStars = 5;
    TextEditingController commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surfaceVariant,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                "Laisser un avis",
                style: AppTextStyles.sectionTitle,
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return IconButton(
                        icon: Icon(
                          index < selectedStars
                              ? Icons.star
                              : Icons.star_border,
                          color: AppColors.warning,
                          size: 32,
                        ),
                        onPressed: () {
                          setDialogState(() {
                            selectedStars = index + 1;
                          });
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: commentController,
                    maxLines: 4,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Écrivez votre commentaire ici...",
                      hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                      ),
                      filled: true,
                      fillColor: AppColors.surfaceVariant,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    "Annuler",
                    style: GoogleFonts.poppins(color: Colors.grey[400]),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () async {
                    Navigator.pop(context);
                    final token = await TokenStorage.getToken();
                    if (token == null) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              "Veuillez vous connecter pour laisser un avis.",
                            ),
                          ),
                        );
                      }
                      return;
                    }

                    try {
                      await _reviewService.addReview(
                        livreId: widget.book.id,
                        note: selectedStars,
                        commentaire: commentController.text,
                        authToken: token,
                      );
                      _loadReviews(); // Reload the reviews
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Avis ajouté avec succès !"),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      print("Error adding review: $e");
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Erreur lors de l'ajout de l'avis."),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  child: Text(
                    "Envoyer",
                    style: GoogleFonts.poppins(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
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
