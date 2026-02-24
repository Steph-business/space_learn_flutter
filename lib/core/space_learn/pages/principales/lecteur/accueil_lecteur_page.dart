import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../data/dataServices/notification_provider.dart';

import '../../widgets/details/book_detail_page.dart';
import '../../principales/notificationPage.dart';
import '../../principales/lecteur/recherche_page.dart';

import '../../../../themes/layout/nav_bar_all.dart';
import '../../../../themes/layout/nav_bar_lecteur.dart';

import '../../../data/dataServices/libraryService.dart';
import '../../../data/dataServices/bookService.dart';
import '../../../data/dataServices/readerStatsService.dart';
import '../../../data/dataServices/lectureService.dart';
import '../../../data/model/book_model.dart';
import '../../../data/model/library_model.dart';
import '../../../data/model/readerStatsModel.dart';
import '../../../data/model/activite_model.dart';
import '../../../data/model/user_model.dart';
import '../../../../utils/token_storage.dart';
import '../../../data/dataServices/readingProgressService.dart';
import '../../../data/model/readingActivityModel.dart';
import '../../../data/dataServices/categorie_service.dart';
import '../../../data/model/categorie.dart';
import '../../../data/dataServices/discussionService.dart';
import '../../../data/model/discussionModel.dart';

class HomePageLecteur extends StatefulWidget {
  final String profileId;
  final String userName;

  const HomePageLecteur({
    super.key,
    required this.profileId,
    this.userName = 'Utilisateur',
  });

  @override
  State<HomePageLecteur> createState() => _HomePageLecteurState();
}

class _HomePageLecteurState extends State<HomePageLecteur> {
  final LibraryService _libraryService = LibraryService();
  final BookService _bookService = BookService();
  final ReaderStatsService _statsService = ReaderStatsService();
  final Lectureservice _lectureService = Lectureservice();
  final ReadingProgressService _readingProgressService =
      ReadingProgressService();
  final CategorieService _categorieService = CategorieService();
  final DiscussionService _discussionService = DiscussionService();

  bool _isLoading = true;
  String? _error;

  ReaderStatsModel? _stats;
  BookModel? _continueReadingBook;
  ReadingActivityModel? _readingProgress;
  List<BookModel> _recommendations = [];

  List<UserModel> _featuredAuthors = [];
  List<ReviewModel> _recentActivities = [];
  List<LibraryModel> _library = [];
  List<Categorie> _categories = [];
  List<Discussion> _discussions = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final token = await TokenStorage.getToken();
      if (token == null) throw Exception("Session expirée");

      final results = await Future.wait([
        _statsService.getReaderStats(widget.profileId),
        _libraryService.getUserLibrary(token),
        _bookService.getAllBooks(),
        _lectureService.getReviewsByUser(token),
        _categorieService.getCategories().catchError((e) {
          debugPrint('⚠️ Error loading categories: $e');
          return <Categorie>[];
        }),
        _discussionService.getDiscussionsByUser(token).catchError((e) {
          debugPrint('⚠️ Error loading discussions: $e');
          return <Discussion>[];
        }),
      ]);

      if (mounted) {
        context
            .read<NotificationProvider>()
            .loadNotifications(token)
            .catchError((e) {
              debugPrint('⚠️ Error loading notifications: $e');
            });
        setState(() {
          if (results[0] is ReaderStatsModel) {
            _stats = results[0] as ReaderStatsModel;
          }

          if (results[1] is List) {
            final library = (results[1] as List).cast<LibraryModel>();
            _library = library;
            if (library.isNotEmpty) {
              _continueReadingBook = library.first.livre;
            }
          }

          if (results[2] is List) {
            final allBooks = (results[2] as List).cast<BookModel>();
            _recommendations = allBooks.take(5).toList();

            final authorsMap = <String, UserModel>{};
            for (var book in allBooks) {
              if (book.auteur != null && book.auteur!.id.isNotEmpty) {
                // Auteur complet disponible
                authorsMap[book.auteur!.id] = book.auteur!;
              } else if (book.auteurId.isNotEmpty &&
                  !authorsMap.containsKey(book.auteurId)) {
                // Fallback : créer un UserModel avec l’auteurId
                authorsMap[book.auteurId] = UserModel(
                  id: book.auteurId,
                  profilId: book.auteurId,
                  email: '',
                  nomComplet: 'Auteur ${authorsMap.length + 1}',
                  isProfileComplete: false,
                );
              }
            }
            _featuredAuthors = authorsMap.values.take(10).toList();
          }

          if (results[3] is List) {
            _recentActivities = (results[3] as List).cast<ReviewModel>();
          }

          if (results.length > 4 && results[4] is List) {
            _categories = (results[4] as List).cast<Categorie>();
          }

          if (results.length > 5 && results[5] is List) {
            _discussions = (results[5] as List).cast<Discussion>();
          }
        });

        if (_continueReadingBook != null) {
          try {
            final progress = await _readingProgressService.getReadingProgress(
              _continueReadingBook!.id,
              token,
            );

            bool needsAuthorFix =
                _continueReadingBook!.auteur == null ||
                _continueReadingBook!.authorName == 'Auteur inconnu' ||
                _continueReadingBook!.auteur!.nomComplet.isEmpty;

            if (needsAuthorFix) {
              try {
                final t = await TokenStorage.getToken();
                final fullBook = await _bookService.getBookById(
                  _continueReadingBook!.id,
                  authToken: t,
                );
                _continueReadingBook = fullBook;
              } catch (bookErr) {
                print("⚠️ Failed to fix book author details: $bookErr");
              }
            }

            if (mounted) {
              setState(() {
                _readingProgress = progress;
              });
            }
          } catch (e) {
            print("⚠️ Error enriching reading data: $e");
          }
        }

        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Erreur lors du chargement des données: $e";
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MainNavBar(
      key: MainNavBar.mainNavBarKey,
      child: Scaffold(
        key: const PageStorageKey('homePageLecteur'),
        backgroundColor: const Color(0xFF0F172A),
        body: Stack(
          children: [
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
                NavBarAll(userName: widget.userName),

                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF6366F1),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadData,
                          color: const Color(0xFF6366F1),
                          child: _error != null
                              ? _buildErrorState()
                              : _buildContent(),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        children: [
          // Section Sombre (Haut)
          Container(
            color: Colors
                .transparent, // Translucide pour voir le dégradé en dessous
            width: double.infinity,
            padding: const EdgeInsets.only(top: 16, bottom: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Barre de recherche
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const RecherchePage(),
                              ),
                            );
                          },
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(bottom: 2),
                                  child: Icon(
                                    Icons.search,
                                    color: Colors.grey,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "Rechercher un livre, un auteur...",
                                    style: GoogleFonts.poppins(
                                      color: Colors.grey,
                                      fontSize: 13,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Stack(
                        alignment: Alignment.topRight,
                        children: [
                          IconButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const NotificationPage(),
                                ),
                              );
                            },
                            icon: const Icon(
                              Icons.notifications_none,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                          Consumer<NotificationProvider>(
                            builder: (context, notificationProvider, child) {
                              final count = notificationProvider.unreadCount;
                              if (count == 0) return const SizedBox.shrink();
                              return Positioned(
                                right: 6,
                                top: 6,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFF0F172A),
                                      width: 1.5,
                                    ),
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 14,
                                    minHeight: 14,
                                  ),
                                  child: Text(
                                    '$count',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // À la une
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "À la une",
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "Tout voir",
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF38BDF8),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildFeaturedHorizontalList(),

                const SizedBox(height: 24),
                // Catégories
                _buildCategoryPills(),

                const SizedBox(height: 32),
                // Recommandations pour vous
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    "Recommandations pour vous",
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildRecommendationsGrid(),
              ],
            ),
          ),

          // Section Claire (Bas) -> maintenant Sombre
          Container(
            color: Colors.transparent, // Changé pour rester cohérent
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Auteurs à suivre
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    "Les auteurs à suivre",
                    style: GoogleFonts.poppins(
                      color: Colors.white, // Changé de black
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildAuthorsList(),

                const SizedBox(height: 32),
                // Clubs de lecture actifs
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    "Clubs de lecture actifs",
                    style: GoogleFonts.poppins(
                      color: Colors.white, // Changé de black
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildClubsList(),

                const SizedBox(height: 32),
                // Dernières citations partagées
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    "Dernières citations partagées",
                    style: GoogleFonts.poppins(
                      color: Colors.white, // Changé de black
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildQuotesList(),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helpers UI du nouveau design

  Widget _buildFeaturedHorizontalList() {
    return SizedBox(
      height: 320,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _recommendations.isNotEmpty ? _recommendations.length : 2,
        itemBuilder: (context, index) {
          if (_recommendations.isEmpty) {
            final hardcoded = [
              {"title": "L'Éveil des Étoiles", "author": "Par Jean Dupont"},
              {"title": "Cœurs Sauvages", "author": "Par Marie Curie"},
            ];
            return Padding(
              padding: const EdgeInsets.only(right: 16),
              child: _buildSingleFeaturedCard(
                title: hardcoded[index]["title"]!,
                author: hardcoded[index]["author"]!,
                imageUrl: null,
              ),
            );
          } else {
            final book = _recommendations[index];
            return Padding(
              padding: const EdgeInsets.only(right: 16),
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => BookDetailPage(book: book),
                    ),
                  );
                },
                child: _buildSingleFeaturedCard(
                  title: book.titre,
                  author: "Par ${book.authorName}",
                  imageUrl: book.imageCouverture,
                ),
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildSingleFeaturedCard({
    required String title,
    required String author,
    String? imageUrl,
  }) {
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        image: imageUrl != null && imageUrl.isNotEmpty
            ? DecorationImage(
                image: NetworkImage(imageUrl),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withOpacity(0.2),
                  BlendMode.darken,
                ),
              )
            : null,
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.transparent,
              Colors.black.withOpacity(0.9),
            ],
            stops: const [0.0, 0.45, 1.0],
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              author,
              style: GoogleFonts.poppins(color: Colors.grey[300], fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryPills() {
    final List<String> categories = ["Tous"];
    if (_categories.isNotEmpty) {
      categories.addAll(_categories.map((c) => c.nom));
    } else {
      categories.addAll(["Science-fiction", "Romance", "Thriller"]);
    }

    return SizedBox(
      height: 36,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final isSelected = index == 0;
          return GestureDetector(
            onTap: () {
              MainNavBar.mainNavBarKey.currentState?.navigateToMarketplace();
            },
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF06B6D4)
                    : const Color(0xFF1E293B), // Cyan pour sélectionné
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.center,
              child: Text(
                categories[index],
                style: GoogleFonts.poppins(
                  color: isSelected ? Colors.white : Colors.grey[300],
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecommendationsGrid() {
    List<BookModel> displayBooks = _recommendations.isNotEmpty
        ? _recommendations
        : [];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.58,
          crossAxisSpacing: 16,
          mainAxisSpacing: 24,
        ),
        itemCount: displayBooks.length > 4
            ? 4
            : (displayBooks.isEmpty ? 4 : displayBooks.length),
        itemBuilder: (context, index) {
          if (displayBooks.isEmpty) {
            final hardcoded = [
              {
                "title": "Nébuleuse Alpha",
                "author": "Cédric Villani",
                "price": "9.99€",
                "rating": "4.8",
              },
              {
                "title": "Les Mémoires d'Hier",
                "author": "Amélie Nothomb",
                "price": "Gratuit",
                "rating": "4.5",
              },
              {
                "title": "Le Code Perdu",
                "author": "Dan Brown",
                "price": "12.50€",
                "rating": "4.9",
              },
              {
                "title": "Forêt Silencieuse",
                "author": "Michel Bussi",
                "price": "8.00€",
                "rating": "4.2",
              },
            ];
            return _buildRecommendationCard(
              title: hardcoded[index]["title"]!,
              author: hardcoded[index]["author"]!,
              price: hardcoded[index]["price"]!,
              rating: hardcoded[index]["rating"]!,
              imageUrl: null,
            );
          } else {
            final book = displayBooks[index];
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BookDetailPage(book: book),
                  ),
                );
              },
              child: _buildRecommendationCard(
                title: book.titre,
                author: book.authorName,
                price: book.prix > 0 ? "${book.prix}€" : "Gratuit",
                rating: (book.noteMoyenne).toStringAsFixed(1),
                imageUrl: book.imageCouverture,
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildRecommendationCard({
    required String title,
    required String author,
    required String price,
    required String rating,
    String? imageUrl,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              image: imageUrl != null && imageUrl.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(imageUrl),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          author,
          style: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 11),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              price,
              style: GoogleFonts.poppins(
                color: const Color(0xFF38BDF8),
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            Row(
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 12),
                const SizedBox(width: 4),
                Text(
                  rating,
                  style: GoogleFonts.poppins(
                    color: Colors.amber,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAuthorsList() {
    final hardcodedAuthors = [
      {"name": "Marie Dubois", "img": null},
      {"name": "Thomas Leroy", "img": null},
      {"name": "Amina Said", "img": null},
      {"name": "Lucas Martin", "img": null},
    ];

    return SizedBox(
      height: 135, // Adjust for fitting content comfortably
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _featuredAuthors.isNotEmpty
            ? _featuredAuthors.length
            : hardcodedAuthors.length,
        itemBuilder: (context, index) {
          final authorName = _featuredAuthors.isNotEmpty
              ? _featuredAuthors[index].nomComplet
              : hardcodedAuthors[index]["name"]!;

          return GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Profil de $authorName en cours de développement',
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.only(right: 20),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: const Color(0xFF3B82F6).withOpacity(0.15),
                    child: Text(
                      authorName.isNotEmpty
                          ? authorName.substring(0, 1).toUpperCase()
                          : "?",
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        color: const Color(0xFF1E40AF),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    authorName,
                    style: GoogleFonts.poppins(
                      color: Colors.white, // Changé de black87
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6), // Blue pill
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      "+ Suivre",
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildClubsList() {
    List<Map<String, dynamic>> clubs = [];

    if (_discussions.isNotEmpty) {
      clubs = _discussions.map((d) {
        return {
          "title": d.titre.isNotEmpty
              ? d.titre
              : "Discussion #${d.id.substring(0, 4)}",
          "members":
              "${d.messages.length} messages", // On mock les membres avec les messages
          "icon": Icons.public,
          "color": const Color(0xFF0F172A),
          "button": true,
        };
      }).toList();
    } else {
      clubs = [
        {
          "title": "Science-fiction & Futurs",
          "members": "1.2k membres",
          "icon": Icons.public,
          "color": const Color(0xFF0F172A),
          "button": true,
        },
        {
          "title": "Polar & Frissons",
          "members": "850 membres",
          "icon": Icons.search,
          "color": const Color(0xFFF87171),
          "button": false,
        },
        {
          "title": "Romance Historique",
          "members": "2.1k membres",
          "icon": Icons.favorite,
          "color": const Color(0xFFF472B6),
          "button": false,
        },
      ];
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: clubs.take(4).map((club) {
          // On se limite à 4 pour l'accueil
          return GestureDetector(
            onTap: () {
              MainNavBar.mainNavBarKey.currentState?.navigateToCommunaute();
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B), // Changé de white
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.transparent,
                ), // Changé à transparent
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2), // Changé à plus fort
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: club["color"] as Color,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      club["icon"] as IconData,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          club["title"] as String,
                          style: GoogleFonts.poppins(
                            color: Colors.white, // Changé de black
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          club["members"] as String,
                          style: GoogleFonts.poppins(
                            color: Colors.grey[400], // Changé de 600
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (club["button"] == true)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(
                          0xFFFFEDD5,
                        ), // Light peach background
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        "Rejoindre",
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF9A3412),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildQuotesList() {
    List<Map<String, dynamic>> quotes = [];

    if (_recentActivities.isNotEmpty &&
        _recentActivities.any((r) => r.commentaire.isNotEmpty)) {
      final validReviews = _recentActivities
          .where((r) => r.commentaire.isNotEmpty)
          .toList();
      final colors = [
        [const Color(0xFF94A3B8), const Color(0xFF475569)],
        [const Color(0xFFD97706), const Color(0xFF92400E)],
        [const Color(0xFF06B6D4), const Color(0xFF0891B2)],
      ];

      quotes = validReviews.map((r) {
        final idx = validReviews.indexOf(r) % colors.length;
        String author = "Membre SpaceLearn";
        if (r.livre != null) {
          author = "Avis sur ${r.livre!.titre}";
        }

        return {
          "quote": "“${r.commentaire}”",
          "author": author,
          "gradient": colors[idx],
          "book": r.livre, // Garde le livre pour la navigation
        };
      }).toList();
    } else {
      quotes = [
        {
          "quote":
              "“Longtemps, je me suis couché de bonne heure.”\n— Marcel Proust, À la recherche du temps perdu",
          "author": "Chloé B.",
          "gradient": [const Color(0xFF94A3B8), const Color(0xFF475569)],
          "book": null,
        },
        {
          "quote":
              "“Il est grand temps de rallumer les étoiles.”\n— Guillaume Apollinaire",
          "author": "Marc D.",
          "gradient": [const Color(0xFFD97706), const Color(0xFF92400E)],
          "book": null,
        },
      ];
    }

    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: quotes.length,
        itemBuilder: (context, index) {
          final q = quotes[index];
          return GestureDetector(
            onTap: () {
              if (q["book"] != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        BookDetailPage(book: q["book"] as BookModel),
                  ),
                );
              }
            },
            child: Container(
              width: 220,
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: q["gradient"] as List<Color>,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    q["quote"] as String,
                    style: GoogleFonts.lora(
                      color: Colors.white,
                      fontSize: 15,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 12,
                        backgroundColor: Colors.white24,
                        child: Icon(
                          Icons.person,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Partagé par ",
                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          q["author"] as String,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: Colors.white),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text("Réessayer"),
            ),
          ],
        ),
      ),
    );
  }
}
