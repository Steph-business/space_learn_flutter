import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/utils/app_notifications.dart';
import 'package:space_learn_flutter/core/themes/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:space_learn_flutter/core/themes/app_dimensions.dart';
import 'package:space_learn_flutter/core/utils/profile_image_helper.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/book_model.dart';
import 'package:provider/provider.dart';
import 'package:iconsax/iconsax.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/bookService.dart';
import 'reading_page.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/paymentService.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/cinetpay_webview_page.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/review_model.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/review_service.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/favoriteService.dart';
import 'package:space_learn_flutter/core/utils/token_storage.dart';
import 'package:intl/intl.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/readingProgressService.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/readingActivityModel.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/libraryService.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/chapitre_service.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/chapitre_model.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/partageService.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/authServices.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/user_model.dart';
import 'all_reviews_page.dart';

class BookDetailPage extends StatefulWidget {
  final BookModel book;
  final bool isOwned;

  /// Celui qui regarde peut-il acheter cet ouvrage ?
  ///
  /// Faux quand un auteur consulte son propre livre depuis ses publications.
  /// Le drapeau s'appelait `showCart` : il commandait l'affichage du panier,
  /// lequel n'existe plus. Son nom decrivait un bouton, pas une regle.
  final bool peutAcheter;

  const BookDetailPage({
    super.key,
    required this.book,
    this.isOwned = false,
    this.peutAcheter = true,
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
  bool _isAuthorOfThisBook = false;
  UserModel? _currentUser;
  bool _acquisitionEnCours = false;
  bool _paiementEnCours = false;

  /// Un livre a prix nul.
  bool get _estGratuit => (_fullBook ?? widget.book).prix <= 0;
  bool _isLoadingOwnership = true;

  String _getAuthorDisplayName(BookModel book) {
    if (book.authorName.isNotEmpty && book.authorName != 'Auteur inconnu') {
      return book.authorName;
    }
    if (_isAuthorOfThisBook &&
        _currentUser != null &&
        _currentUser!.nomComplet.isNotEmpty) {
      return _currentUser!.nomComplet;
    }
    return book.authorName;
  }

  final ReadingProgressService _readingProgressService =
      ReadingProgressService();
  ReadingActivityModel? _readingProgress;
  Set<String> _ownedBookIds = {};

  // Chapitres
  final ChapitreService _chapitreService = ChapitreService();
  List<ChapitreModel> _chapitres = [];
  bool _isLoadingChapitres = true;

  @override
  void initState() {
    super.initState();
    _isOwned = widget.isOwned;
    _loadFullBookDetails();
    _loadRelatedBooks();
    _checkFavoriteStatus();
    _loadReviews();
    _checkOwnershipStatus();
    _loadChapitres();
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
        await _checkOwnershipStatus();
      }
    } catch (e) {}
  }

  Future<void> _checkOwnershipStatus() async {
    try {
      final token = await TokenStorage.getToken();
      if (token != null) {
        final authService = AuthService();
        final user = await authService.getUser(token);
        final currentBook = _fullBook ?? widget.book;

        final isAuthor = user != null &&
            ((currentBook.auteurId.isNotEmpty &&
                    (user.id == currentBook.auteurId ||
                        user.profilId == currentBook.auteurId)) ||
                (currentBook.auteur != null &&
                    (currentBook.auteur!.id == user.id ||
                        currentBook.auteur!.profilId == user.id ||
                        currentBook.auteur!.id == user.profilId)) ||
                (currentBook.authorName.isNotEmpty &&
                    currentBook.authorName != 'Auteur inconnu' &&
                    user.nomComplet.trim().toLowerCase() ==
                        currentBook.authorName.trim().toLowerCase()));

        final library = await _libraryService.getUserLibrary(token);
        final found = library.any((item) => item.livreId == widget.book.id);
        if (mounted) {
          setState(() {
            _currentUser = user;
            _isAuthorOfThisBook = isAuthor;
            _isOwned = _isOwned || isAuthor || found;
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
    } catch (e) {}
  }

  Future<void> _loadChapitres() async {
    try {
      final chapitres = await _chapitreService.getChapitres(widget.book.id);
      if (mounted) {
        setState(() {
          _chapitres = chapitres;
          _isLoadingChapitres = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingChapitres = false;
        });
      }
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
      if (mounted) setState(() => _isLoadingFavorite = false);
    }
  }

  Future<void> _toggleFavorite() async {
    try {
      final token = await TokenStorage.getToken();
      if (token == null) {
        if (mounted) {
          AppNotifications.showSnackBar(
            context,
            message: "Veuillez vous connecter pour ajouter à ma favorie",
            isError: true,
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
      if (mounted) setState(() => _isLoadingFavorite = false);
    }
  }

  /// Détermine dynamiquement si un chapitre fait partie de l'extrait gratuit.
  /// Se base sur la gratuité explicite (ch.estGratuit) ou la page de départ (<= 10 pages).
  bool _isChapterInExtrait(ChapitreModel ch, int index) {
    if (ch.estGratuit) return true;
    if (ch.pageDepart > 0) {
      return ch.pageDepart <= 10;
    }
    return index < 2;
  }

  /// Formate le prix proprement avec espace des milliers pour prévenir tout décalage
  String _formatPrix(int prix) {
    if (prix <= 0) return "Gratuit";
    final str = prix.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write(' ');
      }
      buffer.write(str[i]);
    }
    return "${buffer.toString()} FCFA";
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
      if (mounted) setState(() => _isLoadingReviews = false);
    }
  }

  void _showAllChaptersModal(BuildContext context) {
    final isOwned = _isOwned;
    final book = _fullBook ?? widget.book;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        // Une feuille est une route a part : elle lit la palette sans
        // s'y abonner, donc elle garde celle du dernier ecran construit.
        AppColors.suivreLeTheme(context);
        final chaptersList = _chapitres;
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Tous les chapitres",
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    chaptersList.isNotEmpty
                        ? "${chaptersList.length} chapitres"
                        : "3 chapitres",
                    style: GoogleFonts.poppins(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: chaptersList.isNotEmpty
                    ? ListView.separated(
                        itemCount: chaptersList.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final ch = chaptersList[index];
                          final isExtraitGratuit = (!isOwned) && _isChapterInExtrait(ch, index);
                          final isLocked = !isOwned && !isExtraitGratuit;
                          final numStr = ch.numero < 10
                              ? "0${ch.numero}"
                              : "${ch.numero}";
                          return _buildChapterTile(
                            number: numStr,
                            title: ch.titre,
                            description: ch.description.isNotEmpty
                                ? ch.description
                                : (isLocked
                                      ? "Contenu verrouillé - Achetez le livre pour lire la suite."
                                      : "Extrait gratuit - Disponible à la lecture."),
                            isLocked: isLocked,
                            onTap: () {
                              Navigator.pop(context);
                              if (isLocked) {
                                _lancerPaiementDirect(book);
                              } else {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ReadingPage(
                                      book: book.toJson(),
                                      isExtrait: !isOwned,
                                      initialPage: ch.pageDepart > 0
                                          ? ch.pageDepart
                                          : null,
                                    ),
                                  ),
                                );
                              }
                            },
                          );
                        },
                      )
                    : ListView(
                        children: [
                          _buildChapterTile(
                            number: "01",
                            title: "Introduction",
                            description:
                                "Découvrez cet extrait gratuit.",
                            isLocked: false,
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ReadingPage(
                                    book: book.toJson(),
                                    isExtrait: !isOwned,
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 8),
                          _buildChapterTile(
                            number: "02",
                            title: "Développement",
                            description:
                                "Découvrez cet extrait gratuit.",
                            isLocked: false,
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ReadingPage(
                                    book: book.toJson(),
                                    isExtrait: !isOwned,
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 8),
                          _buildChapterTile(
                            number: "03",
                            title: "Conclusion",
                            description: isOwned
                                ? "Disponible dans l'ouvrage."
                                : "Contenu verrouillé - Achetez le livre pour lire la suite.",
                            isLocked: !isOwned,
                            onTap: () {
                              Navigator.pop(context);
                              if (!isOwned) {
                                _lancerPaiementDirect(book);
                              } else {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        ReadingPage(book: book.toJson()),
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
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
      if (mounted) {
        setState(() => _isLoadingRelated = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    AppColors.suivreLeTheme(context);
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
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: AppColors.textPrimary,
            size: 18,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.share, color: AppColors.textPrimary, size: 20),
            onPressed: () => PartageService().partagerLivre(
              livreId: book.id,
              titreDeSecours: book.titre,
            ),
          ),
          IconButton(
            icon: _isLoadingFavorite
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: Padding(
                      padding: EdgeInsets.all(4),
                      child: Text(
                        "...",
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 10,
                        ),
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
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [AppColors.surfaceVariant, AppColors.darkSurface],
                    ),
                  ),
                  child: Column(
                    children: [
                      SizedBox(height: 30),
                      Container(
                        height: 240,
                        width: 168,
                        decoration: BoxDecoration(
                          color: AppColors.lightSurface,
                          borderRadius: BorderRadius.circular(
                            AppDimensions.radiusCard,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(
                            AppDimensions.radiusCard,
                          ),
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
                                      Icon(
                                        Icons.book,
                                        size: 60,
                                        color: AppColors.orange,
                                      ),
                                )
                              : Icon(
                                  Icons.book,
                                  size: 60,
                                  color: AppColors.orange,
                                ),
                        ),
                      ),
                      SizedBox(height: 40),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          book.titre,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.pageTitle,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        _getAuthorDisplayName(book),
                        style: AppTextStyles.withColor(
                          AppTextStyles.subtitle,
                          AppColors.primary,
                        ),
                      ),
                      SizedBox(height: 12),
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
                                SizedBox(width: 8),
                                Text(
                                  "${(() {
                                    double avg = book.noteMoyenne;
                                    if (avg == 0 && _reviews.isNotEmpty) {
                                      avg = _reviews.map((e) => e.note).reduce((a, b) => a + b) / _reviews.length;
                                    }
                                    return avg.toStringAsFixed(1);
                                  })()} (${book.telechargements > 0 ? book.telechargements : _reviews.length} avis)",
                                  style: GoogleFonts.poppins(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          if (book.nombreMessages > 0) ...[
                            SizedBox(width: 12),
                            Icon(
                              Iconsax.message,
                              color: AppColors.textSecondary,
                              size: 12,
                            ),
                            SizedBox(width: 4),
                            Text(
                              "${book.nombreMessages} message${book.nombreMessages > 1 ? 's' : ''}",
                              style: GoogleFonts.poppins(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: 30),
                    ],
                  ),
                ),

                // Synopsis
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Description', style: AppTextStyles.sectionTitle),
                      SizedBox(height: 12),
                      Text(
                        book.description.isEmpty
                            ? "Aucune description disponible pour ce livre."
                            : book.description,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.6,
                        ),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Lire la suite ⌄',
                        style: GoogleFonts.poppins(
                          color: AppColors.accentInk,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      SizedBox(height: 40),

                      // Sommaire
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Sommaire', style: AppTextStyles.sectionTitle),
                          Text(
                            _chapitres.isNotEmpty
                                ? "${_chapitres.length} CHAPITRES"
                                : "3 CHAPITRES",
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),

                      if (_chapitres.isNotEmpty)
                        ..._chapitres.take(3).toList().asMap().entries.map((entry) {
                          final index = entry.key;
                          final ch = entry.value;
                          final isExtraitGratuit = (!isOwned) && _isChapterInExtrait(ch, index);
                          final isLocked = !isOwned && !isExtraitGratuit;
                          final numStr = ch.numero < 10
                              ? "0${ch.numero}"
                              : "${ch.numero}";
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: _buildChapterTile(
                              number: numStr,
                              title: ch.titre,
                              description: ch.description.isNotEmpty
                                  ? ch.description
                                  : (isLocked
                                        ? "Contenu verrouillé - Achetez le livre pour lire la suite."
                                        : "Extrait gratuit - Disponible à la lecture."),
                              isLocked: isLocked,
                              onTap: () {
                                if (isLocked) {
                                  _lancerPaiementDirect(book);
                                } else {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ReadingPage(
                                        book: book.toJson(),
                                        isExtrait: !isOwned,
                                        initialPage: ch.pageDepart > 0
                                            ? ch.pageDepart
                                            : null,
                                      ),
                                    ),
                                  );
                                }
                              },
                            ),
                          );
                        }).toList()
                      else ...[
                        _buildChapterTile(
                          number: "01",
                          title: "Introduction",
                          description:
                              "Extrait gratuit - Disponible à la lecture.",
                          isLocked: false,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ReadingPage(
                                  book: book.toJson(),
                                  isExtrait: !isOwned,
                                ),
                              ),
                            );
                          },
                        ),
                        SizedBox(height: 8),
                        _buildChapterTile(
                          number: "02",
                          title: "Développement",
                          description:
                              "Extrait gratuit - Disponible à la lecture.",
                          isLocked: false,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ReadingPage(
                                  book: book.toJson(),
                                  isExtrait: !isOwned,
                                ),
                              ),
                            );
                          },
                        ),
                        SizedBox(height: 8),
                        _buildChapterTile(
                          number: "03",
                          title: "Conclusion",
                          description: isOwned
                              ? "Disponible dans l'ouvrage."
                              : "Contenu verrouillé - Achetez le livre pour lire la suite.",
                          isLocked: !isOwned,
                          onTap: () {
                            if (!isOwned) {
                              _lancerPaiementDirect(book);
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      ReadingPage(book: book.toJson()),
                                ),
                              );
                            }
                          },
                        ),
                      ],

                      const SizedBox(height: 12),
                      Center(
                        child: InkWell(
                          onTap: () => _showAllChaptersModal(context),
                          borderRadius: BorderRadius.circular(
                            AppDimensions.radiusSmall,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "Voir tous les chapitres",
                                  style: GoogleFonts.poppins(
                                    color: AppColors.accentInk,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  color: AppColors.accentInk,
                                  size: 12,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: 40),

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
                                color: AppColors.accentInk,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      // Review list
                      if (_isLoadingReviews)
                        Center(
                          child: Text(
                            "Chargement des avis...",
                            style: TextStyle(color: AppColors.textSecondary),
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
                      SizedBox(height: 24),

                      if (isOwned)
                        Container(
                          width: double.infinity,
                          height: 54,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                              AppDimensions.radiusCard,
                            ),
                            border: Border.all(
                              color: AppColors.accentInk.withOpacity(0.3),
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
                              borderRadius: BorderRadius.circular(
                                AppDimensions.radiusCard,
                              ),
                              onTap: () => _showReviewDialog(context),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.star_rounded,
                                    color: AppColors.accentInk,
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    "Laisser un avis",
                                    style: AppTextStyles.withColor(
                                      AppTextStyles.button14,
                                      AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                      SizedBox(height: 40),

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
                          Center(
                            child: Text(
                              "Chargement...",
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
                SizedBox(height: 20),
              ],
            ),
          ),

          // Fixed Bottom Bar
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.darkSurface,
                border: Border(
                  top: BorderSide(
                    color: AppColors.textPrimary.withOpacity(0.05),
                    width: 1,
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                child: _isLoadingOwnership
                    ? Center(
                        child: Text(
                          "...",
                          style: TextStyle(color: AppColors.textPrimary),
                        ),
                      )
                    // Un livre gratuit ne se vend pas.
                    //
                    // Proposer un panier et un bouton « Acheter » sur un
                    // ouvrage a prix nul, c'est demander de payer ce que
                    // l'auteur a decide de donner. On l'ouvre, c'est tout.
                    : !isOwned && _estGratuit
                    ? _boutonLireGratuitement()
                    : !isOwned
                    ? widget.peutAcheter
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "PRIX EBOOK",
                                            style: GoogleFonts.poppins(
                                              color: AppColors.textSecondary,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                          FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              _formatPrix(book.prix),
                                              style: AppTextStyles.heroTitle22,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: SizedBox(
                                        height: 50,
                                        child: ElevatedButton(
                                          onPressed: _paiementEnCours
                                              ? null
                                              : () => _lancerPaiementDirect(book),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                AppColors.secondary,
                                            foregroundColor: AppColors.onAccent,
                                            disabledBackgroundColor:
                                                AppColors.secondary
                                                    .withValues(alpha: 0.6),
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    AppDimensions.radiusInner,
                                                  ),
                                            ),
                                          ),
                                          child: _paiementEnCours
                                              ? SizedBox(
                                                  height: 20,
                                                  width: 20,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: AppColors.onAccent,
                                                  ),
                                                )
                                              : Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons.shopping_bag,
                                                      size: 18,
                                                    ),
                                                    SizedBox(width: 6),
                                                    Flexible(
                                                      child: Text(
                                                        'Acheter',
                                                        overflow:
                                                            TextOverflow.ellipsis,
                                                        style:
                                                            GoogleFonts.poppins(
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.w600,
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
                                SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: OutlinedButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ReadingPage(
                                            book: book.toJson(),
                                            isExtrait: true,
                                          ),
                                        ),
                                      );
                                    },
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.textPrimary,
                                      side: BorderSide(
                                        color: AppColors.textPrimary
                                            .withOpacity(0.2),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          AppDimensions.radiusInner,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.menu_book, size: 18),
                                        SizedBox(width: 8),
                                        Text(
                                          "Lire un extrait",
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
                            )
                          : Center(
                              child: Text(
                                "Consultation Auteur",
                                style: GoogleFonts.poppins(
                                  color: AppColors.textSecondary,
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
                                          color: AppColors.textSecondary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        "${_readingProgress!.pourcentage}%",
                                        style: GoogleFonts.poppins(
                                          color: AppColors.accentInk,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 6),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(
                                      AppDimensions.radiusXs,
                                    ),
                                    child: LinearProgressIndicator(
                                      value:
                                          _readingProgress!.pourcentage / 100,
                                      backgroundColor: Colors.white.withOpacity(
                                        0.05,
                                      ),
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        AppColors.primary,
                                      ),
                                      minHeight: 6,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (_isAuthorOfThisBook)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.auto_awesome,
                                    size: 15,
                                    color: AppColors.accentInk,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    "Vous êtes l'auteur de cet ouvrage",
                                    style: GoogleFonts.poppins(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.accentInk,
                                    ),
                                  ),
                                ],
                              ),
                            ),
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
                                foregroundColor: AppColors.onAccent,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppDimensions.radiusInner,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.menu_book, size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    _isAuthorOfThisBook
                                        ? 'Lire mon ouvrage (Auteur)'
                                        : (_readingProgress != null &&
                                                _readingProgress!.pourcentage >
                                                    0
                                            ? 'Continuer la lecture'
                                            : 'Commencer la lecture'),
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
        SizedBox(height: 32),
        Text(title, style: AppTextStyles.sectionTitle),
        SizedBox(height: 20),
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
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
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
            SizedBox(height: 12),
            // Title
            Text(
              book.titre,
              style: AppTextStyles.cardTitleSmallSemiBold,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 1),
            // Author
            Text(
              book.authorName,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 4),
            // Price and Stats Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  book.prix > 0 ? "${book.prix} F" : "Gratuit",
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.accentInk,
                  ),
                ),
                Row(
                  children: [
                    if (book.noteMoyenne > 0) ...[
                      Icon(
                        Icons.star_rounded,
                        color: AppColors.warning,
                        size: 10,
                      ),
                      SizedBox(width: 2),
                      Text(
                        book.noteMoyenne.toStringAsFixed(1),
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (book.nombreMessages > 0) ...[
                      SizedBox(width: 6),
                      Icon(
                        Iconsax.message,
                        color: AppColors.textHint,
                        size: 10,
                      ),
                      SizedBox(width: 2),
                      Text(
                        "${book.nombreMessages}",
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: AppColors.textHint,
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

  /// Le seul bouton d'un livre gratuit.
  ///
  /// Il fait les deux gestes d'un coup : le livre entre dans la bibliotheque —
  /// sans quoi le lecteur ne pourrait ni le retrouver ni reprendre ou il en
  /// etait — puis la lecture s'ouvre. Le serveur verifie le prix ; l'appel
  /// echoue si l'ouvrage n'est pas reellement gratuit.
  Widget _boutonLireGratuitement() {
    return SizedBox(
      height: 50,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _acquisitionEnCours ? null : _lireGratuitement,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onAccent,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.6),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusInner),
          ),
        ),
        child: _acquisitionEnCours
            ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.onAccent,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.menu_book, size: 18),
                  SizedBox(width: 8),
                  Text(
                    "Lire gratuitement",
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _lancerPaiementDirect(BookModel book) async {
    if (_paiementEnCours) return;

    final double amount = book.prix.toDouble();
    if (amount <= 0) {
      await _lireGratuitement();
      return;
    }

    setState(() => _paiementEnCours = true);

    try {
      final token = await TokenStorage.getToken();
      if (token == null) {
        if (mounted) {
          AppNotifications.showSnackBar(
            context,
            message: "Veuillez vous connecter pour effectuer un achat",
            isError: true,
          );
        }
        return;
      }

      final user = _currentUser ?? await AuthService().getUser(token);
      if (user == null) {
        if (mounted) {
          AppNotifications.showSnackBar(
            context,
            message: "Impossible de récupérer les informations de votre compte",
            isError: true,
          );
        }
        return;
      }

      final paymentService = PaymentService();
      final result = await paymentService.initiateCinetpayPayment(
        livreId: book.id,
        montant: amount,
        authToken: token,
        customerName: user.nomComplet.isNotEmpty ? user.nomComplet : "Lecteur SpaceLearn",
        customerEmail: user.email.isNotEmpty ? user.email : "client@spacelearn.com",
      );

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CinetpayWebViewPage(
            paymentUrl: result.paymentUrl,
            transactionId: result.paiement.transactionId,
            book: book.toJson(),
            montant: amount,
          ),
        ),
      );

      if (mounted) {
        await _checkOwnershipStatus();
      }
    } catch (e) {
      if (mounted) {
        AppNotifications.showSnackBar(
          context,
          message: "Erreur lors de l'initialisation du paiement : $e",
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _paiementEnCours = false);
      }
    }
  }

  Future<void> _lireGratuitement() async {
    setState(() => _acquisitionEnCours = true);
    try {
      final token = await TokenStorage.getToken();
      if (token == null) {
        if (!mounted) return;
        AppNotifications.showSnackBar(
          context,
          message: "Votre session a expiré. Reconnectez-vous.",
          isError: true,
        );
        return;
      }

      await LibraryService().acquerirGratuitement(widget.book.id, token);
      if (!mounted) return;

      // Le livre est relu apres l'acquisition, et ce n'est pas un luxe.
      //
      // Le serveur masque l'adresse du manuscrit tant que le lecteur ne
      // possede pas l'ouvrage. L'objet affiche sur cette fiche a donc ete
      // recu SANS elle : le passer tel quel au lecteur donnait « Aucun fichier
      // disponible pour ce livre » sur un livre qu'on venait d'obtenir.
      final aJour = await BookService().getBookById(
        widget.book.id,
        authToken: token,
      );
      if (!mounted) return;

      setState(() => _isOwned = true);
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ReadingPage(book: aJour.toJson()),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      AppNotifications.showSnackBar(
        context,
        message: "Le livre n'a pas pu être ouvert. Vérifiez votre connexion.",
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _acquisitionEnCours = false);
    }
  }

  Widget _buildPlaceholderCover() {
    return Container(
      color: AppColors.surfaceVariant,
      child: Center(
        child: Icon(Icons.book, color: AppColors.accentInk, size: 30),
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
          return Icon(Icons.star, color: AppColors.warning, size: 18);
        } else if (index == fullStars && hasHalfStar) {
          return Icon(Icons.star_half, color: AppColors.warning, size: 18);
        } else {
          return Icon(Icons.star_border, color: AppColors.warning, size: 18);
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
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(color: AppColors.textPrimary.withOpacity(0.05)),
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
                    ? Icon(Icons.person, color: AppColors.accentInk, size: 18)
                    : null,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: AppTextStyles.cardTitleSmall),
                    Text(
                      time,
                      style: GoogleFonts.poppins(
                        color: AppColors.textSecondary,
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
          SizedBox(height: 12),
          Text(
            comment,
            style: GoogleFonts.poppins(
              color: AppColors.textSecondary,
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
                borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
              ),
              title: Text("Laisser un avis", style: AppTextStyles.sectionTitle),
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
                  SizedBox(height: 16),
                  TextField(
                    controller: commentController,
                    maxLines: 4,
                    style: TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: "Écrivez votre commentaire ici...",
                      hintStyle: TextStyle(
                        color: AppColors.textPrimary.withOpacity(0.5),
                      ),
                      filled: true,
                      fillColor: AppColors.surfaceVariant,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusInner,
                        ),
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
                    style: GoogleFonts.poppins(color: AppColors.textSecondary),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusSmall,
                      ),
                    ),
                  ),
                  onPressed: () async {
                    final scaffoldMessenger = ScaffoldMessenger.of(context);
                    Navigator.pop(context);
                    final token = await TokenStorage.getToken();
                    if (token == null) {
                      AppNotifications.showSnackBar(
                        context,
                        message:
                            "Veuillez vous connecter pour laisser un avis.",
                        isError: true,
                      );
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
                      AppNotifications.showSnackBar(
                        context,
                        message: "Avis ajouté avec succès !",
                        isSuccess: true,
                      );
                    } catch (e) {
                      AppNotifications.showSnackBar(
                        context,
                        message: "Erreur lors de l'ajout de l'avis.",
                        isError: true,
                      );
                    }
                  },
                  child: Text(
                    "Envoyer",
                    style: GoogleFonts.poppins(color: AppColors.onAccent),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildChapterTile({
    required String number,
    required String title,
    required String description,
    required bool isLocked,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: isLocked ? null : onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppDimensions.radiusInner),
          border: Border.all(
            color: isLocked
                ? AppColors.textPrimary.withOpacity(0.04)
                : AppColors.primary.withOpacity(0.15),
          ),
        ),
        child: Row(
          children: [
            Text(
              "$number.",
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isLocked ? AppColors.textSecondary : AppColors.accentInk,
              ),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isLocked
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    description,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            SizedBox(width: 8),
            Icon(
              isLocked ? Icons.lock_outline : Icons.play_circle_outline,
              color: isLocked ? AppColors.textSecondary : AppColors.accentInk,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
