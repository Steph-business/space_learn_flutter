import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/utils/app_notifications.dart';
import 'package:space_learn_flutter/core/themes/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:space_learn_flutter/core/themes/layout/recherche_bar.dart';
import 'package:space_learn_flutter/core/themes/app_dimensions.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import '../../../data/dataServices/notification_provider.dart';

import '../../widgets/details/book_detail_page.dart';
import '../../widgets/lecteur/boutique/livre_card.dart';
import '../../widgets/details/author_profile_page.dart';
import 'badges_page.dart';
import '../../widgets/lecteur/accueil/daily_goal_section.dart';
import '../../../data/dataServices/badgeService.dart';
import '../../../data/model/goalModel.dart';
import '../../principales/lecteur/all_authors_page.dart';

import '../../../../themes/layout/nav_bar_all.dart';
import '../../../../themes/layout/nav_bar_lecteur.dart';
import '../../widgets/lecteur/communaute/forum_messages_page.dart';

import '../../../data/dataServices/readingProgressService.dart';
import '../../../data/dataServices/reading_time_storage.dart';
import '../../../data/model/readingActivityModel.dart';
import '../../../data/model/badgeModel.dart';
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
import '../../../data/dataServices/citation_service.dart';
import '../../../data/model/citation_model.dart';
import 'temps_lecture_page.dart';
import 'package:space_learn_flutter/core/services/onboarding_guide_service.dart';
import 'package:space_learn_flutter/core/widgets/guides/space_learn_tour.dart';

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
  final CitationService _citationService = CitationService();
  final ReadingProgressService _progressService = ReadingProgressService();

  final GlobalKey _searchBarKey = GlobalKey();
  final GlobalKey _dailyGoalKey = GlobalKey();
  final GlobalKey _featuredBooksKey = GlobalKey();

  GoalModel? _dailyGoal;
  CitationModel? _dailyCitation;

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

  Future<void> _checkAndShowTour() async {
    final shouldShow = await OnboardingGuideService.shouldShowHomeTour();
    if (shouldShow && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 650), () {
          if (mounted) {
            SpaceLearnTour.startHomeTour(
              context: context,
              searchBarKey: _searchBarKey,
              dailyGoalKey: _dailyGoal != null ? _dailyGoalKey : null,
              featuredBooksKey:
                  _featuredBooks.isNotEmpty ? _featuredBooksKey : null,
            );
          }
        });
      });
    }
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
          // Rattrape les sessions ouvertes avant que l'identifiant soit
          // enregistré à la connexion.
          TokenStorage.saveUserId(user.id);
          if (user.nomComplet.isNotEmpty) {
            _displayName = user.nomComplet;
            TokenStorage.saveUserName(user.nomComplet); // Sync storage
          }
          _profilePhoto = user.profilePhoto;
        });
      }

      final readingMinutes = await ReadingTimeStorage.getTotalReadingMinutes(
        user?.id ?? widget.profileId,
      );
      final todayReadingMinutes =
          await ReadingTimeStorage.getTodayReadingMinutes(
        user?.id ?? widget.profileId,
      );

      final results = await Future.wait([
        _statsService.getReaderStats(widget.profileId).catchError((e) {
          return ReaderStatsModel(
            booksRead: 0,
            totalTime: '0m',
            goalsAchieved: 0,
          );
        }),
        _bookService.getAllBooks(authToken: token).catchError((e) {
          return <BookModel>[];
        }),
        _lectureService.getAllReviews(token).catchError((e) {
          return <ReviewModel>[];
        }),
        _categorieService.getCategories().catchError((e) {
          return <Categorie>[];
        }),
        _discussionService.getGlobalDiscussions().catchError((e) {
          return <Discussion>[];
        }),
        _recommendationService.getRecommendations(token).catchError((e) {
          return <RecommendationModel>[];
        }),
        _libraryService.getUserLibrary(token).catchError((e) {
          return <LibraryModel>[];
        }),
        (user != null)
            ? _relationService.getFollowing(user.id).catchError((e) {
                return <RelationModel>[];
              })
            : Future.value(<RelationModel>[]),
        _badgeService.getGoals().catchError((e) {
          return <GoalModel>[];
        }),
        _citationService.getDailyCitation(token).catchError((e) {
          return null;
        }),
        _progressService.getAllProgressions(token).catchError((e) {
          return <ReadingActivityModel>[];
        }),
        _badgeService.getUserBadges().catchError((e) {
          return <BadgeModel>[];
        }),
      ]);

      if (mounted) {
        context
            .read<NotificationProvider>()
            .loadNotifications(token)
            .catchError((e) {});
        setState(() {
          // 1. Get stats from API
          ReaderStatsModel apiStats = results[0] as ReaderStatsModel;

          final allBooks = (results[1] as List).cast<BookModel>();
          final reviews = (results[2] as List).cast<ReviewModel>();
          final categories = (results[3] as List).cast<Categorie>();
          final discussions = (results[4] as List).cast<Discussion>();
          final recs = (results[5] as List).cast<RecommendationModel>();
          final library = (results.length > 6 && results[6] is List)
              ? (results[6] as List).cast<LibraryModel>()
              : <LibraryModel>[];
          final followings = (results.length > 7 && results[7] is List)
              ? (results[7] as List).cast<RelationModel>()
              : <RelationModel>[];
          final backendGoals = (results.length > 8 && results[8] is List)
              ? (results[8] as List).cast<GoalModel>()
              : <GoalModel>[];
          final citation = results.length > 9 ? results[9] as CitationModel? : null;
          final allProgress = (results.length > 10 && results[10] is List)
              ? (results[10] as List).cast<ReadingActivityModel>()
              : <ReadingActivityModel>[];
          final backendBadges = (results.length > 11 && results[11] is List)
              ? (results[11] as List).cast<BadgeModel>()
              : <BadgeModel>[];

          _recentActivities = reviews;
          _dailyCitation = citation;
          _categories = categories;
          _discussions = discussions;
          if (_discussions.isNotEmpty) {
            _discussions.sort((a, b) {
              if (a.creeLe != null && b.creeLe != null) {
                return b.creeLe!.compareTo(a.creeLe!);
              }
              return b.id.compareTo(a.id);
            });
          }

          // Map allProgress onto library
          final Map<String, ReadingActivityModel> progressMap = {};
          for (var p in allProgress) {
            if (p.livreId.isNotEmpty) {
              progressMap[p.livreId] = p;
            }
          }
          final updatedLibrary = library.map((item) {
            if (item.livre != null) {
              final prog = progressMap[item.livre!.id];
              if (prog != null) {
                return item.copyWith(
                  livre: item.livre!.copyWith(progressions: [prog]),
                );
              }
            }
            return item;
          }).toList();

          // Compute accurate books read
          int finishedReading = allProgress.where((p) {
            return p.pourcentage >= 100 ||
                (p.lastPage >= p.totalPages && p.totalPages > 0);
          }).length;

          if (finishedReading == 0) {
            finishedReading = updatedLibrary.where((item) {
              final p = item.livre?.progressions;
              return p != null &&
                  p.isNotEmpty &&
                  (p.first.pourcentage >= 100 ||
                      (p.first.lastPage >= p.first.totalPages &&
                          p.first.totalPages > 0));
            }).length;
          }

          int displayedBooksRead =
              (apiStats.booksRead > 0 && apiStats.booksRead != 12)
                  ? apiStats.booksRead
                  : finishedReading;

          // Format reading time
          String formattedTime =
              ReadingTimeStorage.formatMinutes(readingMinutes);
          if (readingMinutes == 0 &&
              apiStats.totalTime.isNotEmpty &&
              apiStats.totalTime != '0h' &&
              apiStats.totalTime != '0m' &&
              apiStats.totalTime != '34h') {
            formattedTime = apiStats.totalTime;
          }

          // Compute smart & backend goals
          final smartGoals = ReadingTimeStorage.computeSmartGoals(
            booksRead: displayedBooksRead,
            totalMinutes: readingMinutes,
            todayMinutes: todayReadingMinutes,
            libraryCount: library.length,
          );

          final List<GoalModel> finalGoals =
              backendGoals.isNotEmpty ? backendGoals : smartGoals;
          int goalsAchievedCount =
              finalGoals.where((g) => g.estTermine).length;

          if (backendBadges.isNotEmpty) {
            final unlockedBadges =
                backendBadges.where((b) => b.debloqueLe != null).length;
            if (unlockedBadges > goalsAchievedCount) {
              goalsAchievedCount = unlockedBadges;
            }
          }

          if (finalGoals.isNotEmpty) {
            _dailyGoal = finalGoals.firstWhere(
              (g) => g.type == 'DAILY',
              orElse: () => finalGoals.first,
            );
          }

          _stats = ReaderStatsModel(
            booksRead: displayedBooksRead,
            totalTime: formattedTime,
            goalsAchieved: goalsAchievedCount,
          );

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

          final authorOwnBookIds = _allBooks
              .where((b) =>
                  (b.auteurId.isNotEmpty && b.auteurId == _currentUserId) ||
                  (b.auteur != null && b.auteur!.id == _currentUserId) ||
                  (b.authorName.isNotEmpty &&
                      (b.authorName.trim().toLowerCase() ==
                              _displayName.trim().toLowerCase() ||
                          b.authorName.trim().toLowerCase() ==
                              widget.userName.trim().toLowerCase())))
              .map((b) => b.id);

          _ownedBookIds = {
            ...library.map((item) => item.livreId),
            ...authorOwnBookIds,
          };
          _followingIds = followings.map((f) => f.suitId).toSet();

          // 3. Finalize Lists
          // Nouveautés
          _featuredBooks = List.from(_allBooks);
          _featuredBooks.sort((a, b) {
            if (a.creeLe != null && b.creeLe != null) {
              return b.creeLe!.compareTo(a.creeLe!);
            }
            return b.id.compareTo(a.id);
          });
          _featuredBooks = _featuredBooks.take(5).toList();

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
          _checkAndShowTour();
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
    AppColors.suivreLeTheme(context);
    return MainNavBar(
      key: MainNavBar.mainNavBarKey,
      child: Scaffold(
        key: PageStorageKey('homePageLecteur'),
        backgroundColor: AppColors.scaffoldBackground,
        body: Column(
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
                        style: GoogleFonts.poppins(
                          color: AppColors.textSecondary,
                        ),
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
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      key: _searchBarKey,
      padding: const EdgeInsets.fromLTRB(24, 4, 16, 2),
      child: Row(
        children: [
          Expanded(
            child: CustomSearchBar(
              controller: _searchController,
              onChanged: _onSearch,
              hintText: "Rechercher un livre, un auteur...",
            ),
          ),
          SizedBox(width: 10),
          PopupMenuButton<String>(
            icon: Container(
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(AppDimensions.radiusInner),
                border: Border.all(
                  color: _selectedSection != "Tout"
                      ? AppColors.accentInk
                      : AppColors.textHint,
                ),
              ),
              child: Icon(
                Icons.tune,
                color: _selectedSection != "Tout"
                    ? AppColors.accentInk
                    : AppColors.textSecondary,
                size: 20,
              ),
            ),
            offset: Offset(0, 52),
            color: AppColors.cardBackground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusInner),
            ),
            onSelected: (value) {
              setState(() {
                _selectedSection = value;
              });
            },
            itemBuilder: (context) {
              final List<Map<String, dynamic>> menuItems = [
                {'label': 'Tout', 'icon': Icons.dashboard_outlined},
                {'label': 'Nouveautés', 'icon': Icons.new_releases_outlined},
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
                            ? AppColors.accentInk
                            : AppColors.textHint,
                      ),
                      SizedBox(width: 12),
                      Text(
                        item['label'],
                        style: GoogleFonts.poppins(
                          color: isSelected
                              ? AppColors.secondaryVariant
                              : AppColors.textPrimary,
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
                  SizedBox(height: 16),
                  if (_stats != null) _buildQuickStats(),
                  if (_dailyGoal != null) ...[
                    SizedBox(height: 16),
                    GestureDetector(
                      key: _dailyGoalKey,
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                BadgesPage(userId: widget.profileId),
                          ),
                        );
                        _loadData();
                      },
                      child: DailyGoalSection(goal: _dailyGoal),
                    ),
                  ],
                  SizedBox(height: 20),
                ],

                // Nouveautés
                if (_selectedSection == "Tout" ||
                    _selectedSection == "Nouveautés") ...[
                  Container(
                    key: _featuredBooksKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Nouveautés", style: AppTextStyles.sectionTitle),
                              GestureDetector(
                                onTap: () {
                                  MainNavBar.mainNavBarKey.currentState
                                      ?.navigateToMarketplace();
                                },
                                child: Text("Voir plus", style: AppTextStyles.link),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 16),
                        _buildFeaturedHorizontalList(),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),
                ],

                // Catégories (Persistent or only in section?)
                // Usually better to keep categories only when book sections are shown
                if (_selectedSection == "Tout" ||
                    _selectedSection == "Nouveautés" ||
                    _selectedSection == "Recommandations") ...[
                  _buildCategoryPills(),
                  SizedBox(height: 18),
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
                  SizedBox(height: 12),
                  _buildRecommendationsGrid(),
                  if (_selectedSection == "Tout") SizedBox(height: 20),
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
                          Text("Auteurs", style: AppTextStyles.sectionTitle),
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
                    SizedBox(height: 12),
                    _buildAuthorsList(),
                    SizedBox(height: 20),
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
                    SizedBox(height: 12),
                    _buildClubsList(),
                    SizedBox(height: 20),
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
                    SizedBox(height: 12),
                    _buildQuotesList(),
                    SizedBox(height: 20),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  // Helpers UI du nouveau design

  /// Largeur d'une carte de livre sur l'accueil.
  ///
  /// Reprise de la boutique : deux colonnes sur un ecran ordinaire y donnent
  /// environ cette largeur, si bien qu'un meme ouvrage a la meme taille d'un
  /// ecran a l'autre.
  static const double _largeurCarte = 160;

  Widget _buildFeaturedHorizontalList() {
    List<BookModel> displayBooks = [];
    if (_featuredBooks.isNotEmpty) {
      displayBooks = _featuredBooks;
    } else if (_allBooks.isNotEmpty) {
      displayBooks = _allBooks;
    }

    if (displayBooks.isEmpty) {
      return SizedBox(height: LivreCard.hauteurPour(_largeurCarte));
    }

    // Meme carte qu'en boutique, donc meme hauteur.
    //
    // Elle etait posee dans une bande de 250 px : la couverture y tenait ce
    // qu'elle pouvait et le texte debordait par le bas, sans que rien ne le
    // signale a la compilation. La hauteur se demande maintenant a la carte
    // elle-meme, qui seule connait ses proportions.
    return SizedBox(
      height: LivreCard.hauteurPour(_largeurCarte),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: displayBooks.length,
        itemBuilder: (context, index) {
          final book = displayBooks[index];
          return Padding(
            padding: const EdgeInsets.only(right: 14),
            child: SizedBox(
              width: _largeurCarte,
              child: LivreCard(
                book: book,
                isOwned: _ownedBookIds.contains(book.id),
              ),
            ),
          );
        },
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
              padding: EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.secondary
                    : AppColors.cardBackground,
                borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
                border: Border.all(
                  color: isSelected ? AppColors.accentInk : AppColors.textHint,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                catName,
                style: GoogleFonts.poppins(
                  color: isSelected
                      ? AppColors.onAccent
                      : AppColors.textPrimary,
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

    // Meme carte qu'en boutique, donc meme hauteur.
    //
    // Elle etait posee dans une bande de 250 px : la couverture y tenait ce
    // qu'elle pouvait et le texte debordait par le bas, sans que rien ne le
    // signale a la compilation. La hauteur se demande maintenant a la carte
    // elle-meme, qui seule connait ses proportions.
    return SizedBox(
      height: LivreCard.hauteurPour(_largeurCarte),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: displayBooks.length,
        itemBuilder: (context, index) {
          final book = displayBooks[index];
          return Padding(
            padding: const EdgeInsets.only(right: 14),
            child: SizedBox(
              width: _largeurCarte,
              child: LivreCard(
                book: book,
                isOwned: _ownedBookIds.contains(book.id),
              ),
            ),
          );
        },
      ),
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
                AppNotifications.showSnackBar(
                  context,
                  message: 'Profil de $authorName en cours de développement',
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
                        color: AppColors.accentInk,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    authorName,
                    style: GoogleFonts.poppins(
                      color: AppColors.textPrimary, // Changé de black87
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 8),
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
                        AppNotifications.showSnackBar(
                          context,
                          message:
                              'Fonctionnalité indisponible pour les auteurs de démonstration',
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
                            ? AppColors.textHint
                            : AppColors.secondary, // Blue pill
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusCard,
                        ),
                        border:
                            _followingIds.contains(
                              _featuredAuthors.isNotEmpty
                                  ? _featuredAuthors[index].id
                                  : "",
                            )
                            ? Border.all(color: AppColors.textHint)
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
                              ? AppColors.textSecondary
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
          AppNotifications.showSnackBar(
            context,
            message: "Vous ne pouvez pas vous suivre vous-même",
            isError: true,
          );
        }
        return;
      }

      await _relationService.followUser(authorId, token);
      if (mounted) {
        setState(() {
          _followingIds.add(authorId);
        });
        AppNotifications.showSnackBar(context, message: '$authorName suivi !');
      }
    } catch (e) {
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
          AppNotifications.showSnackBar(
            context,
            message: errorStr.replaceFirst('Exception: ', ''),
            isError: true,
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
        title: Text(
          "Déjà suivi",
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          "Vous suivez déjà $authorName. Vous recevrez des notifications pour ses prochaines publications.",
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("OK", style: TextStyle(color: AppColors.accentInk)),
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
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: club["color"] as Color,
                borderRadius: BorderRadius.circular(AppDimensions.radiusInner),
              ),
              child: Icon(
                club["icon"] as IconData,
                color: AppColors.textPrimary,
                size: 24,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(club["title"] as String, style: AppTextStyles.cardTitle),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        (club["members"] as String).toLowerCase().contains(
                              "message",
                            )
                            ? Iconsax.message
                            : Icons.person_outline,
                        color: AppColors.textSecondary,
                        size: 11,
                      ),
                      SizedBox(width: 4),
                      Text(
                        club["members"] as String,
                        style: AppTextStyles.grey12,
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
                  borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
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

    // Ajouter la citation API dynamique s'il y en a une
    if (_dailyCitation != null && _dailyCitation!.texte.isNotEmpty) {
      quotes.add({
        "quote": _dailyCitation!.texte,
        "author": _dailyCitation!.auteur,
        "bookTitle": _dailyCitation!.livreTitre ?? "",
        "gradient": [AppColors.primary, AppColors.primaryDark],
        "book": null,
        "note": 5,
      });
    }

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

      final reviewQuotes = validReviews.map((r) {
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

      quotes.addAll(reviewQuotes);
    }

    if (quotes.isEmpty) {
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
                borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
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
                            color: AppColors.textPrimary,
                            size: 14,
                          );
                        }),
                      ),
                      Icon(
                        Icons.format_quote,
                        color: AppColors.textHint,
                        size: 24,
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Expanded(
                    child: Center(
                      child: Text(
                        q["quote"] as String,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.lora(
                          color: AppColors.textPrimary,
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
                  SizedBox(height: 12),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: AppColors.textHint,
                        child: Icon(
                          Icons.person,
                          size: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              q["author"] as String,
                              style: GoogleFonts.poppins(
                                color: AppColors.textPrimary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (q["book"] != null)
                              Text(
                                "Livre: ${(q["book"] as BookModel).titre}",
                                style: GoogleFonts.poppins(
                                  color: AppColors.textSecondary,
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
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          border: Border.all(color: AppColors.textPrimary.withOpacity(0.05)),
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
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        TempsLecturePage(userId: widget.profileId),
                  ),
                );
                _loadData();
              },
            ),
            _buildStatSeparator(),
            _buildStatItem(
              "${_stats!.goalsAchieved}",
              "Objectifs",
              Icons.emoji_events,
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BadgesPage(userId: widget.profileId),
                  ),
                );
                _loadData();
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
          Icon(icon, color: AppColors.accentInk, size: 20),
          SizedBox(height: 8),
          Text(value, style: AppTextStyles.subtitle),
          Text(label, style: AppTextStyles.grey11),
        ],
      ),
    );
  }

  Widget _buildStatSeparator() {
    return Container(
      height: 40,
      width: 1,
      color: AppColors.textPrimary.withOpacity(0.1),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
            SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: AppColors.textPrimary),
            ),
            SizedBox(height: 20),
            ElevatedButton(onPressed: _loadData, child: Text("Réessayer")),
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
              color: AppColors.textPrimary.withOpacity(0.1),
            ),
            SizedBox(height: 16),
            Text(
              "Aucun résultat trouvé pour \"$_searchQuery\"",
              style: AppTextStyles.greyMedium14,
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
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          border: Border.all(color: AppColors.textPrimary.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 70,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
                color: AppColors.textHint,
              ),
              child:
                  book.imageCouverture != null &&
                      book.imageCouverture!.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusSmall,
                      ),
                      child: Image.network(
                        book.imageCouverture!,
                        fit: BoxFit.cover,
                      ),
                    )
                  : Icon(Icons.book, color: AppColors.textHint, size: 20),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.titre,
                    style: AppTextStyles.button14,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text("Par ${book.authorName}", style: AppTextStyles.link12),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }
}
