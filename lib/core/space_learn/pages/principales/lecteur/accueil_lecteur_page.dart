import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/themes/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import '../../../data/dataServices/notification_provider.dart';

import '../../widgets/details/book_detail_page.dart';
import '../../widgets/details/author_profile_page.dart';
import 'badges_page.dart';
import '../../widgets/lecteur/accueil/daily_goal_section.dart';
import '../../../data/dataServices/badgeService.dart';
import '../../../data/model/goalModel.dart';
import '../../principales/lecteur/all_authors_page.dart';

import '../../../../themes/layout/nav_bar_all.dart';
import '../../../../themes/layout/nav_bar_lecteur.dart';
import '../../widgets/lecteur/communaute/forum_messages_page.dart';

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
import '../../../data/dataServices/categorie_service.dart';
import '../../../data/model/categorie.dart';
import '../../../data/dataServices/discussionService.dart';
import '../../../data/model/discussionModel.dart';
import '../../../data/dataServices/recommendationService.dart';
import '../../../data/model/recommendationModel.dart';
import '../../../data/dataServices/relationService.dart';
import '../../../data/dataServices/authServices.dart';
import '../../../data/model/relationModel.dart';

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
  final BookService _bookService = BookService();
  final ReaderStatsService _statsService = ReaderStatsService();
  final Lectureservice _lectureService = Lectureservice();
  final CategorieService _categorieService = CategorieService();
  final DiscussionService _discussionService = DiscussionService();
  final RecommendationService _recommendationService = RecommendationService();
  final RelationService _relationService = RelationService();
  final LibraryService _libraryService = LibraryService();
  final AuthService _authService = AuthService();
  final BadgeService _badgeService = BadgeService();

  GoalModel? _dailyGoal;

  bool _isLoading = true;
  String? _error;
  ReaderStatsModel? _stats;

  List<BookModel> _featuredBooks = [];
  List<BookModel> _recommendations = [];
  List<BookModel> _allBooks = [];

  List<UserModel> _featuredAuthors = [];
  List<ReviewModel> _recentActivities = [];
  List<Categorie> _categories = [];
  Set<String> _ownedBookIds = {};
  List<Discussion> _discussions = [];
  String? _currentUserId;
  Set<String> _followingIds = {};
  String _displayName = "Utilisateur";
  String? _profilePhoto;
  String _selectedCategory = "Tous";
  String _selectedSection = "Tout";
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  List<BookModel> _searchResults = [];
  bool _isSearching = false;

  void _onSearch(String value) {
    setState(() {
      _searchQuery = value;
      _isSearching = value.isNotEmpty;
    });

    if (value.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    // Direct local search for speed
    final filtered = _allBooks.where((book) {
      final titleMatch = book.titre.toLowerCase().contains(value.toLowerCase());
      final authorMatch = book.authorName.toLowerCase().contains(
        value.toLowerCase(),
      );
      return titleMatch || authorMatch;
    }).toList();

    setState(() {
      _searchResults = filtered;
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = "";
      _isSearching = false;
      _searchResults = [];
    });
  }

  @override
  void initState() {
    super.initState();
    _displayName = widget.userName;
    _initDisplayName();
    _loadData();
  }

  Future<void> _initDisplayName() async {
    final savedName = await TokenStorage.getUserName();
    if (savedName != null && mounted && _displayName == widget.userName) {
      setState(() {
        _displayName = savedName;
      });
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final token = await TokenStorage.getToken();
      if (token == null) throw Exception("Session expirée");

      // Get current user Id to prevent self-following
      final user = await _authService.getUser(token);
      if (user != null && mounted) {
        setState(() {
          _currentUserId = user.id;
          if (user.nomComplet.isNotEmpty) {
            _displayName = user.nomComplet;
            TokenStorage.saveUserName(user.nomComplet); // Sync storage
          }
          _profilePhoto = user.profilePhoto;
        });
      }

      final results = await Future.wait([
        _statsService.getReaderStats(widget.profileId).catchError((e) {
          debugPrint('⚠️ Error loading stats: $e');
          return ReaderStatsModel(
            booksRead: 0,
            totalTime: '0h',
            goalsAchieved: 0,
          );
        }),
        _bookService.getAllBooks(authToken: token).catchError((e) {
          debugPrint('⚠️ Error loading books: $e');
          return <BookModel>[];
        }),
        _lectureService.getAllReviews(token).catchError((e) {
          debugPrint('⚠️ Error loading all reviews: $e');
          return <ReviewModel>[];
        }),
        _categorieService.getCategories().catchError((e) {
          debugPrint('⚠️ Error loading categories: $e');
          return <Categorie>[];
        }),
        _discussionService.getGlobalDiscussions().catchError((e) {
          debugPrint('⚠️ Error loading global discussions: $e');
          return <Discussion>[];
        }),
        _recommendationService.getRecommendations(token).catchError((e) {
          debugPrint('⚠️ Error loading recommendations: $e');
          return <RecommendationModel>[];
        }),
        _libraryService.getUserLibrary(token).catchError((e) {
          debugPrint('⚠️ Error loading library: $e');
          return <LibraryModel>[];
        }),
        (user != null)
            ? _relationService.getFollowing(user.id).catchError((e) {
                debugPrint('⚠️ Error loading following: $e');
                return <RelationModel>[];
              })
            : Future.value(<RelationModel>[]),
        _badgeService.getGoals().catchError((e) {
          debugPrint('⚠️ Error loading goals: $e');
          return <GoalModel>[];
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
          // 1. Get stats from API
          ReaderStatsModel apiStats = results[0] as ReaderStatsModel;
          _stats = apiStats;

          if (results[2] is List) {
            _recentActivities = (results[2] as List).cast<ReviewModel>();
          }

          if (results.length > 8 && results[8] is List) {
            final goals = (results[8] as List).cast<GoalModel>();
            if (goals.isNotEmpty) {
              _dailyGoal = goals.first;
            }
          }

          if (results.length > 3 && results[3] is List) {
            _categories = (results[3] as List).cast<Categorie>();
          }

          if (results.length > 4 && results[4] is List) {
            _discussions = (results[4] as List).cast<Discussion>();
            if (_discussions.isNotEmpty) {
              print(
                '💬 HOME DISCUSSIONS LOADED: ${_discussions.length} items. First item title: ${_discussions.first.titre}, count: ${_discussions.first.messagesCount}',
              );
            }
            _discussions.sort((a, b) {
              if (a.creeLe != null && b.creeLe != null) {
                return b.creeLe!.compareTo(a.creeLe!);
              }
              return b.id.compareTo(a.id);
            });
          }

          // Data sources for enrichment
          final allBooks = (results[1] as List).cast<BookModel>();
          final library = (results.length > 6 && results[6] is List)
              ? (results[6] as List).cast<LibraryModel>()
              : <LibraryModel>[];
          final followings = (results.length > 7 && results[7] is List)
              ? (results[7] as List).cast<RelationModel>()
              : <RelationModel>[];
          final recs = (results.length > 5 && results[5] is List)
              ? (results[5] as List).cast<RecommendationModel>()
              : <RecommendationModel>[];

          // 1.5 Local stats fallback if API is unavailable or returns mock data
          if (_stats!.booksRead == 0 || _stats!.booksRead == 12) {
            int totalInLibrary = library.length;
            int finishedReading = library.where((item) {
              final p = item.livre?.progressions;
              return p != null && p.isNotEmpty && p.first.pourcentage >= 100;
            }).length;

            int displayedBooksRead = finishedReading > 0
                ? finishedReading
                : totalInLibrary;

            _stats = ReaderStatsModel(
              booksRead: displayedBooksRead,
              totalTime: _stats!.totalTime == '34h' ? '0h' : _stats!.totalTime,
              goalsAchieved: _stats!.goalsAchieved == 5
                  ? 0
                  : _stats!.goalsAchieved,
            );
          }

          // 1. Build a comprehensive Author Map from all available sources
          final Map<String, UserModel> knownAuthors = {};

          // Source A: Following (very reliable for names)
          for (var f in followings) {
            if (f.nomComplet != null && f.nomComplet!.isNotEmpty) {
              knownAuthors[f.suitId] = UserModel(
                id: f.suitId,
                profilId: f.suitId,
                email: '',
                nomComplet: f.nomComplet!,
                profilePhoto: f.profilePhoto,
                isProfileComplete: false,
              );
            }
          }

          // Source B: Library (often contains enriched names from joins)
          for (var item in library) {
            final authorId = item.livre?.auteurId;
            if (authorId != null && authorId.isNotEmpty) {
              if (item.livre!.auteur != null &&
                  item.livre!.auteur!.nomComplet != 'Auteur inconnu') {
                knownAuthors[authorId] = item.livre!.auteur!;
              } else if (item.auteurNom != null &&
                  item.auteurNom!.isNotEmpty &&
                  item.auteurNom != 'Auteur inconnu') {
                knownAuthors[authorId] = UserModel(
                  id: authorId,
                  profilId: authorId,
                  email: '',
                  nomComplet: item.auteurNom!,
                  isProfileComplete: false,
                );
              }
            }
          }

          // Source C: Books list
          for (var book in allBooks) {
            if (book.auteur != null &&
                book.auteur!.nomComplet != 'Auteur inconnu') {
              knownAuthors[book.auteurId] = book.auteur!;
            }
          }

          // 2. Enrich ALL books with the best author data found
          BookModel enrichBook(BookModel b) {
            if (knownAuthors.containsKey(b.auteurId)) {
              final bestAuthor = knownAuthors[b.auteurId]!;
              // Only update if current is missing or "Auteur inconnu"
              if (b.auteur == null ||
                  b.auteur!.nomComplet == 'Auteur inconnu') {
                return b.copyWith(auteur: bestAuthor);
              }
            }
            return b;
          }

          _allBooks = allBooks.map(enrichBook).toList();

          // 3. Enrich reviews (Recent Activities) with book data
          final Map<String, BookModel> booksById = {
            for (var b in _allBooks) b.id: b,
          };

          _recentActivities = _recentActivities.map((review) {
            BookModel? book = booksById[review.livreId];
            if (book != null) {
              return ReviewModel(
                id: review.id,
                utilisateurId: review.utilisateurId,
                livreId: review.livreId,
                note: review.note,
                commentaire: review.commentaire,
                creeLe: review.creeLe,
                livre: book,
                utilisateur: review.utilisateur,
                nomUtilisateur: review.nomUtilisateur,
              );
            }
            return review;
          }).toList();

          // Sort reviews by date descending (Handle nulls by putting them at the end)
          _recentActivities.sort((a, b) {
            if (a.creeLe != null && b.creeLe != null) {
              return b.creeLe!.compareTo(a.creeLe!);
            } else if (a.creeLe == null && b.creeLe != null) {
              return 1; // a is null, put it after b
            } else if (a.creeLe != null && b.creeLe == null) {
              return -1; // b is null, put a before b
            }
            return 0;
          });

          // Limit to most recent activities to avoid long lists
          if (_recentActivities.length > 15) {
            _recentActivities = _recentActivities.take(15).toList();
          }

          _recommendations = recs
              .where((r) => r.livre != null)
              .map((r) => enrichBook(r.livre!))
              .toList();

          _ownedBookIds = library.map((item) => item.livreId).toSet();
          _followingIds = followings.map((f) => f.suitId).toSet();

          // 3. Finalize Lists
          // À la une
          _featuredBooks = List.from(_allBooks);
          _featuredBooks.sort((a, b) {
            if (a.creeLe != null && b.creeLe != null) {
              return b.creeLe!.compareTo(a.creeLe!);
            }
            return b.id.compareTo(a.id);
          });
          _featuredBooks = _featuredBooks.take(10).toList();

          // Auteurs à suivre
          final Map<String, UserModel> authorsToFollowMap = {};
          for (var book in _allBooks) {
            final authorId = book.auteurId;
            if (authorId.isEmpty || authorId == _currentUserId) continue;

            if (knownAuthors.containsKey(authorId)) {
              authorsToFollowMap[authorId] = knownAuthors[authorId]!;
            } else {
              authorsToFollowMap[authorId] = UserModel(
                id: authorId,
                profilId: authorId,
                email: '',
                nomComplet: (book.authorName != 'Auteur inconnu')
                    ? book.authorName
                    : "Auteur #${authorId.length > 5 ? authorId.substring(0, 5) : authorId}",
                isProfileComplete: false,
              );
            }
          }
          _featuredAuthors = authorsToFollowMap.values.take(10).toList();
        });

        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
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
        backgroundColor: AppColors.scaffoldBackground,
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
                      AppColors.slate, // Lighter slate gray
                      AppColors.scaffoldBackground, // Dark background matching Scaffold
                    ],
                  ),
                ),
              ),
            ),
            Column(
              children: [
                NavBarAll(
                  userName: _displayName,
                  userUrl: _profilePhoto,
                  role: 'lecteur',
                ),
                Expanded(
                  child: _isLoading
                      ? Center(
                          child: Text(
                            "Chargement...",
                            style: GoogleFonts.poppins(color: Colors.white70),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadData,
                          color: AppColors.indigo,
                          child: _error != null
                              ? _buildErrorState()
                              : _isSearching
                              ? _buildSearchResults()
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

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 16, 2),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.search, color: Colors.grey, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearch,
                      style: AppTextStyles.body,
                      decoration: InputDecoration(
                        hintText: "Rechercher un livre, un auteur...",
                        hintStyle: GoogleFonts.poppins(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    GestureDetector(
                      onTap: _clearSearch,
                      child: const Icon(
                        Icons.close,
                        color: Colors.grey,
                        size: 18,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          PopupMenuButton<String>(
            icon: Container(
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _selectedSection != "Tout"
                      ? AppColors.secondary
                      : Colors.white.withOpacity(0.05),
                ),
              ),
              child: Icon(
                Icons.tune,
                color: _selectedSection != "Tout"
                    ? AppColors.secondary
                    : Colors.white70,
                size: 20,
              ),
            ),
            offset: const Offset(0, 52),
            color: AppColors.cardBackground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (value) {
              setState(() {
                _selectedSection = value;
              });
            },
            itemBuilder: (context) {
              final List<Map<String, dynamic>> menuItems = [
                {'label': 'Tout', 'icon': Icons.dashboard_outlined},
                {'label': 'À la une', 'icon': Icons.star_outline},
                {'label': 'Recommandations', 'icon': Icons.recommend},
                {'label': 'Auteurs', 'icon': Icons.people_outline},
                {'label': 'Forum', 'icon': Icons.forum_outlined},
              ];
              return menuItems.map((item) {
                final isSelected = _selectedSection == item['label'];
                return PopupMenuItem<String>(
                  value: item['label'],
                  height: 40,
                  child: Row(
                    children: [
                      Icon(
                        item['icon'],
                        size: 16,
                        color: isSelected
                            ? AppColors.secondary
                            : Colors.white38,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        item['label'],
                        style: GoogleFonts.poppins(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        children: [
          // Search bar (scrollable)
          _buildSearchBar(),
          // Section Sombre (Haut)
          Container(
            color: Colors.transparent,
            width: double.infinity,
            padding: const EdgeInsets.only(top: 8, bottom: 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_selectedSection == "Tout") ...[
                  const SizedBox(height: 16),
                  if (_stats != null) _buildQuickStats(),
                  if (_dailyGoal != null) ...[
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                BadgesPage(userId: widget.profileId),
                          ),
                        );
                      },
                      child: DailyGoalSection(goal: _dailyGoal),
                    ),
                  ],
                  const SizedBox(height: 20),
                ],

                // À la une
                if (_selectedSection == "Tout" ||
                    _selectedSection == "À la une") ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "À la une",
                          style: AppTextStyles.sectionTitle,
                        ),
                        GestureDetector(
                          onTap: () {
                            MainNavBar.mainNavBarKey.currentState
                                ?.navigateToMarketplace();
                          },
                          child: Text(
                            "Voir plus",
                            style: AppTextStyles.link,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildFeaturedHorizontalList(),
                  const SizedBox(height: 20),
                ],

                // Catégories (Persistent or only in section?)
                // Usually better to keep categories only when book sections are shown
                if (_selectedSection == "Tout" ||
                    _selectedSection == "À la une" ||
                    _selectedSection == "Recommandations") ...[
                  _buildCategoryPills(),
                  const SizedBox(height: 18),
                ],

                // Recommandations pour vous
                if (_selectedSection == "Tout" ||
                    _selectedSection == "Recommandations") ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Recommandations",
                          style: AppTextStyles.sectionTitle,
                        ),
                        TextButton(
                          onPressed: () {
                            MainNavBar.mainNavBarKey.currentState
                                ?.navigateToMarketplace();
                          },
                          child: Text(
                            "Voir plus",
                            style: AppTextStyles.linkBold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildRecommendationsGrid(),
                  if (_selectedSection == "Tout") const SizedBox(height: 20),
                ],
              ],
            ),
          ),

          // Section Basse
          if (_selectedSection == "Tout" ||
              _selectedSection == "Auteurs" ||
              _selectedSection == "Forum")
            Container(
              color: Colors.transparent,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Auteurs
                  if (_selectedSection == "Tout" ||
                      _selectedSection == "Auteurs") ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Auteurs",
                            style: AppTextStyles.sectionTitle,
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const AllAuthorsPage(),
                                ),
                              );
                            },
                            child: Text(
                              "Voir plus",
                              style: AppTextStyles.linkBold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildAuthorsList(),
                    const SizedBox(height: 20),
                  ],

                  // Clubs / Forum
                  if (_selectedSection == "Tout" ||
                      _selectedSection == "Forum") ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _discussions.isNotEmpty
                                ? "Forums (${_discussions.length})"
                                : "Forums",
                            style: AppTextStyles.sectionTitle,
                          ),
                          TextButton(
                            onPressed: () {
                              MainNavBar.mainNavBarKey.currentState
                                  ?.navigateToCommunaute();
                            },
                            child: Text(
                              "Voir plus",
                              style: AppTextStyles.linkBold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildClubsList(),
                    const SizedBox(height: 20),
                  ],

                  // Citations (toujours à la fin si mode Tout)
                  if (_selectedSection == "Tout") ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        "Citations",
                        style: AppTextStyles.sectionTitle,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildQuotesList(),
                    const SizedBox(height: 20),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  // Helpers UI du nouveau design

  Widget _buildFeaturedHorizontalList() {
    List<BookModel> displayBooks = [];
    if (_featuredBooks.isNotEmpty) {
      displayBooks = _featuredBooks;
    } else if (_allBooks.isNotEmpty) {
      displayBooks = _allBooks;
    }

    return SizedBox(
      height: 320,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: displayBooks.isNotEmpty ? displayBooks.length : 0,
        itemBuilder: (context, index) {
          final book = displayBooks[index];
          return Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
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
              child: _buildSingleFeaturedCard(
                title: book.titre,
                author: "Par ${book.authorName}",
                imageUrl: book.imageCouverture,
                messagesCount: book.nombreMessages,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSingleFeaturedCard({
    required String title,
    required String author,
    String? imageUrl,
    int messagesCount = 0,
  }) {
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
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
              style: AppTextStyles.subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              author,
              style: AppTextStyles.bodySecondary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (messagesCount > 0) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Iconsax.message, color: Colors.white70, size: 11),
                  const SizedBox(width: 4),
                  Text(
                    "$messagesCount message${messagesCount > 1 ? 's' : ''}",
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryPills() {
    final List<BookModel> pool = _recommendations.isNotEmpty
        ? _recommendations
        : _allBooks;

    // Get names of categories that actually contain books
    final Set<String> activeCategoryNames = pool
        .map((b) => b.categorie?.nom)
        .whereType<String>()
        .map((name) => name.trim())
        .toSet();

    final List<String> categories = ["Tous"];
    if (_categories.isNotEmpty) {
      categories.addAll(
        _categories
            .map((c) => c.nom)
            .where((name) => activeCategoryNames.contains(name.trim()))
            .toList(),
      );
    } else if (pool.isNotEmpty) {
      categories.addAll(activeCategoryNames.toList());
    }

    if (categories.length <= 1 && pool.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 36,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final catName = categories[index];
          final isSelected = _selectedCategory == catName;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedCategory = catName;
              });
            },
            child: Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.secondary
                    : AppColors.cardBackground,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? AppColors.secondary
                      : Colors.white.withOpacity(0.05),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                catName,
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
    List<BookModel> displayBooks = [];

    if (_recommendations.isNotEmpty) {
      displayBooks = _recommendations;
    } else if (_allBooks.isNotEmpty) {
      displayBooks = List.from(_allBooks);
    }

    // Filter by category locally
    if (_selectedCategory != "Tous") {
      displayBooks = displayBooks.where((book) {
        // Try to match by category name
        final bookCategory = book.categorie?.nom;
        return bookCategory != null &&
            bookCategory.toLowerCase() == _selectedCategory.toLowerCase();
      }).toList();
    }

    if (displayBooks.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: GridView.builder(
        padding: const EdgeInsets.only(top: 4),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.58,
          crossAxisSpacing: 16,
          mainAxisSpacing: 24,
        ),
        itemCount: displayBooks.length > 4 ? 4 : displayBooks.length,
        itemBuilder: (context, index) {
          final book = displayBooks[index];
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
            child: _buildRecommendationCard(
              title: book.titre,
              author: book.authorName,
              price: book.prix > 0 ? "${book.prix}  FCFA" : "Gratuit",
              rating: (book.noteMoyenne).toStringAsFixed(1),
              reviewsCount: book.telechargements,
              imageUrl: book.imageCouverture,
              messagesCount: book.nombreMessages,
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecommendationCard({
    required String title,
    required String author,
    required String price,
    required String rating,
    int reviewsCount = 0,
    String? imageUrl,
    int messagesCount = 0,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
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
          style: AppTextStyles.cardTitleSmall,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          author,
          style: AppTextStyles.bodySmall,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              price,
              style: AppTextStyles.price,
            ),
            Row(
              children: [
                if (reviewsCount > 0) ...[
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
                if (messagesCount > 0) ...[
                  const SizedBox(width: 8),
                  const Icon(Iconsax.message, color: Colors.white70, size: 10),
                  const SizedBox(width: 4),
                  Text(
                    "$messagesCount",
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
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
        physics: const ClampingScrollPhysics(),
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
              if (_featuredAuthors.isNotEmpty) {
                final author = _featuredAuthors[index];
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AuthorProfilePage(
                      author: author,
                      initialIsFollowing: _followingIds.contains(author.id),
                    ),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Profil de $authorName en cours de développement',
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            child: Padding(
              padding: const EdgeInsets.only(right: 20),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: AppColors.secondary.withOpacity(0.15),
                    child: Text(
                      authorName.isNotEmpty
                          ? authorName.substring(0, 1).toUpperCase()
                          : "?",
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        color: AppColors.secondary,
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
                  GestureDetector(
                    onTap: () {
                      if (_featuredAuthors.isNotEmpty) {
                        final authorId = _featuredAuthors[index].id;
                        if (_followingIds.contains(authorId)) {
                          _showAlreadyFollowingDialog(authorName);
                        } else {
                          _followAuthor(authorId, authorName);
                        }
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Fonctionnalité indisponible pour les auteurs de démonstration',
                            ),
                          ),
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color:
                            _followingIds.contains(
                              _featuredAuthors.isNotEmpty
                                  ? _featuredAuthors[index].id
                                  : "",
                            )
                            ? Colors.white.withOpacity(0.1)
                            : AppColors.secondary, // Blue pill
                        borderRadius: BorderRadius.circular(16),
                        border:
                            _followingIds.contains(
                              _featuredAuthors.isNotEmpty
                                  ? _featuredAuthors[index].id
                                  : "",
                            )
                            ? Border.all(color: Colors.white24)
                            : null,
                      ),
                      child: Text(
                        _followingIds.contains(
                              _featuredAuthors.isNotEmpty
                                  ? _featuredAuthors[index].id
                                  : "",
                            )
                            ? "Suivi"
                            : "+ Suivre",
                        style: GoogleFonts.poppins(
                          color:
                              _followingIds.contains(
                                _featuredAuthors.isNotEmpty
                                    ? _featuredAuthors[index].id
                                    : "",
                              )
                              ? Colors.white70
                              : Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
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

  Future<void> _followAuthor(String authorId, String authorName) async {
    if (_followingIds.contains(authorId)) return;
    try {
      final token = await TokenStorage.getToken();
      if (token == null) return;

      // Anti-self following
      if (authorId == _currentUserId) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Vous ne pouvez pas vous suivre vous-même"),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      await _relationService.followUser(authorId, token);
      if (mounted) {
        setState(() {
          _followingIds.add(authorId);
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$authorName suivi !')));
      }
    } catch (e) {
      debugPrint("Error following author: $e");
      final errorStr = e.toString();
      if (errorStr.contains("409") || errorStr.contains("déjà existante")) {
        // If it's a conflict (already following), update local state and show dialog
        if (mounted) {
          setState(() {
            _followingIds.add(authorId);
          });
          _showAlreadyFollowingDialog(authorName);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorStr.replaceFirst('Exception: ', '')),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showAlreadyFollowingDialog(String authorName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text("Déjà suivi", style: TextStyle(color: Colors.white)),
        content: Text(
          "Vous suivez déjà $authorName. Vous recevrez des notifications pour ses prochaines publications.",
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK", style: TextStyle(color: AppColors.secondary)),
          ),
        ],
      ),
    );
  }

  Widget _buildClubsList() {
    final List<Map<String, dynamic>> hardcodedClubs = [
      {
        "title": "Science-fiction & Futurs",
        "members": "12 messages",
        "icon": Icons.public,
        "color": AppColors.scaffoldBackground,
        "button": true,
      },
      {
        "title": "Polar & Frissons",
        "members": "8 messages",
        "icon": Icons.search,
        "color": AppColors.redLight,
        "button": false,
      },
      {
        "title": "Romance Historique",
        "members": "21 messages",
        "icon": Icons.favorite,
        "color": AppColors.pink,
        "button": false,
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: _discussions.isNotEmpty
            ? _discussions.take(3).map((d) {
                final club = {
                  "title": d.titre.isNotEmpty
                      ? d.titre
                      : "Discussion #${d.id.substring(0, 4)}",
                  "members": (d.messagesCount ?? 0) > 0
                      ? "${d.messagesCount} message${d.messagesCount! > 1 ? 's' : ''}"
                      : "${d.messages.length} message${d.messages.length > 1 ? 's' : ''}",
                  "icon": Icons.public,
                  "color": AppColors.scaffoldBackground,
                  "button": true,
                };
                return _buildClubItem(club, discussion: d);
              }).toList()
            : hardcodedClubs.take(3).map((club) {
                return _buildClubItem(club);
              }).toList(),
      ),
    );
  }

  Widget _buildClubItem(Map<String, dynamic> club, {Discussion? discussion}) {
    return GestureDetector(
      onTap: () {
        if (discussion != null) {
          MainNavBar.mainNavBarKey.currentState?.navigateToCommunaute();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ForumMessagesPage(discussion: discussion),
            ),
          );
        } else {
          MainNavBar.mainNavBarKey.currentState?.navigateToCommunaute();
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
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
                    style: AppTextStyles.cardTitle,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        (club["members"] as String).toLowerCase().contains(
                              "message",
                            )
                            ? Iconsax.message
                            : Icons.person_outline,
                        color: Colors.grey[400],
                        size: 11,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        club["members"] as String,
                        style: GoogleFonts.poppins(
                          color: Colors.grey[400],
                          fontSize: 12,
                        ),
                      ),
                    ],
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
                  color: AppColors.joinBadgeBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "Rejoindre",
                  style: GoogleFonts.poppins(
                    color: AppColors.joinBadgeText,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
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
        [AppColors.slateLight, AppColors.slate],
        [AppColors.orange, AppColors.orangeDark],
        [AppColors.primary, AppColors.primaryDark],
      ];

      quotes = validReviews.map((r) {
        final idx = validReviews.indexOf(r) % colors.length;
        String author = "Membre SpaceLearn";

        if (r.nomUtilisateur != null && r.nomUtilisateur!.isNotEmpty) {
          author = r.nomUtilisateur!;
        } else if (r.utilisateur != null && r.utilisateur!.libelle.isNotEmpty) {
          author = r.utilisateur!.libelle;
        } else if (r.livre != null) {
          author = "Avis sur ${r.livre!.titre}";
        }

        return {
          "quote": "“${r.commentaire}”",
          "author": author,
          "bookTitle": r.livre?.titre ?? "",
          "gradient": colors[idx],
          "book": r.livre,
          "note": r.note,
        };
      }).toList();
    } else {
      quotes = [
        {
          "quote":
              "“Longtemps, je me suis couché de bonne heure.”\n— Marcel Proust, À la recherche du temps perdu",
          "author": "Chloé B.",
          "gradient": [AppColors.slateLight, AppColors.slate],
          "book": null,
          "note": 5,
        },
        {
          "quote":
              "“Il est grand temps de rallumer les étoiles.”\n— Guillaume Apollinaire",
          "author": "Marc D.",
          "gradient": [AppColors.orange, AppColors.orangeDark],
          "book": null,
          "note": 4,
        },
      ];
    }

    return SizedBox(
      height: 210,
      child: ListView.builder(
        physics: const ClampingScrollPhysics(),
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
                    builder: (context) => BookDetailPage(
                      book: q["book"] as BookModel,
                      isOwned: _ownedBookIds.contains(
                        (q["book"] as BookModel).id,
                      ),
                    ),
                  ),
                );
              }
            },
            child: Container(
              width: 220,
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.all(16),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: List.generate(5, (starIndex) {
                          return Icon(
                            starIndex < (q["note"] as int? ?? 0)
                                ? Icons.star
                                : Icons.star_border,
                            color: Colors.white,
                            size: 14,
                          );
                        }),
                      ),
                      const Icon(
                        Icons.format_quote,
                        color: Colors.white24,
                        size: 24,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Center(
                      child: Text(
                        q["quote"] as String,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.lora(
                          color: Colors.white,
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ),
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              q["author"] as String,
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (q["book"] != null)
                              Text(
                                "Livre: ${(q["book"] as BookModel).titre}",
                                style: GoogleFonts.poppins(
                                  color: Colors.white70,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
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

  Widget _buildQuickStats() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(
              "${_stats!.booksRead}",
              "Livres lus",
              Icons.auto_stories,
              onTap: () {
                MainNavBar.mainNavBarKey.currentState?.navigateToBibliotheque();
              },
            ),
            _buildStatSeparator(),
            _buildStatItem(
              _stats!.totalTime,
              "Temps total",
              Icons.timer,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BadgesPage(userId: widget.profileId),
                  ),
                );
              },
            ),
            _buildStatSeparator(),
            _buildStatItem(
              "${_stats!.goalsAchieved}",
              "Objectifs",
              Icons.emoji_events,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BadgesPage(userId: widget.profileId),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    String value,
    String label,
    IconData icon, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Icon(icon, color: AppColors.secondary, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTextStyles.subtitle,
          ),
          Text(
            label,
            style: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildStatSeparator() {
    return Container(
      height: 40,
      width: 1,
      color: Colors.white.withOpacity(0.1),
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

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) {
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
              "Aucun résultat trouvé pour \"$_searchQuery\"",
              style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final book = _searchResults[index];
        return _buildSearchResultCard(book);
      },
    );
  }

  Widget _buildSearchResultCard(BookModel book) {
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
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 70,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.white10,
              ),
              child:
                  book.imageCouverture != null &&
                      book.imageCouverture!.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        book.imageCouverture!,
                        fit: BoxFit.cover,
                      ),
                    )
                  : const Icon(Icons.book, color: Colors.white24, size: 20),
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
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    "Par ${book.authorName}",
                    style: GoogleFonts.poppins(
                      color: AppColors.secondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white24),
          ],
        ),
      ),
    );
  }
}
