import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../widgets/details/reading_page.dart';
import '../../../../themes/layout/navBarAll.dart';
import '../../../../themes/layout/navBarLecteur.dart';
import '../../widgets/lecteur/home/continue_reading_section.dart';
import '../../widgets/lecteur/home/recent_activity_section.dart';
import '../../widgets/lecteur/home/recommendations_section.dart';
import '../../widgets/lecteur/home/stats_section.dart';
import '../../widgets/lecteur/home/featured_authors_section.dart';

import 'teamsPage.dart';

import '../../../data/dataServices/libraryService.dart';
import '../../../data/dataServices/bookService.dart';
import '../../../data/dataServices/readerStatsService.dart';
import '../../../data/dataServices/lectureService.dart';
import '../../../data/model/bookModel.dart';
import '../../../data/model/libraryModel.dart';
import '../../../data/model/readerStatsModel.dart';
import '../../../data/model/activiteModel.dart';
import '../../../data/model/userModel.dart';
import '../../../../utils/tokenStorage.dart';
import '../../../data/dataServices/readingProgressService.dart';
import '../../../data/model/readingActivityModel.dart';

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

  bool _isLoading = true;
  String? _error;

  ReaderStatsModel? _stats;
  BookModel? _continueReadingBook;
  ReadingActivityModel? _readingProgress;
  List<BookModel> _recommendations = [];

  List<UserModel> _featuredAuthors = [];
  List<ReviewModel> _recentActivities = [];

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

      // Fetch all data in parallel
      final results = await Future.wait([
        _statsService.getReaderStats(widget.profileId),
        _libraryService.getUserLibrary(token),
        _bookService.getAllBooks(),
        _lectureService.getReviewsByUser(token),
      ]);

      if (mounted) {
        setState(() {
          if (results[0] is ReaderStatsModel) {
            _stats = results[0] as ReaderStatsModel;
          }

          if (results[1] is List) {
            final library = (results[1] as List).cast<LibraryModel>();
            if (library.isNotEmpty) {
              _continueReadingBook = library.first.livre;
            }
          }

          if (results[2] is List) {
            final allBooks = (results[2] as List).cast<BookModel>();
            _recommendations = allBooks.take(5).toList();

            // Extract unique authors from books
            final authorsMap = <String, UserModel>{};
            for (var book in allBooks) {
              if (book.auteur != null) {
                authorsMap[book.auteur!.id] = book.auteur!;
              }
            }
            _featuredAuthors = authorsMap.values.take(10).toList();
          }

          if (results[3] is List) {
            _recentActivities = (results[3] as List).cast<ReviewModel>();
          }
        });

        // 2. Fetch Progress and Fix Author if needed
        if (_continueReadingBook != null) {
          try {
            // Fetch Reading Progress
            final progress = await _readingProgressService.getReadingProgress(
              _continueReadingBook!.id,
              token,
            );
            print("Fetched progress: ${progress?.pourcentage ?? 'None'}");

            // Fix missing Author details if "Unknown" or ID only (using ID to fetch full details)
            // This is the workaround for the user's issue where "Livre" has empty author details
            // but the main object (or book ID) is valid.
            bool needsAuthorFix =
                _continueReadingBook!.auteur == null ||
                _continueReadingBook!.authorName == 'Auteur inconnu' ||
                _continueReadingBook!.auteur!.nomComplet.isEmpty;

            if (needsAuthorFix) {
              print(
                "🔄 Fixing author details for book ${_continueReadingBook!.id}...",
              );
              try {
                final fullBook = await _bookService.getBookById(
                  _continueReadingBook!.id,
                );
                _continueReadingBook = fullBook;
              } catch (bookErr) {
                print("⚠️ Failed to fix book author details: $bookErr");
              }
            }

            if (mounted) {
              setState(() {
                _readingProgress = progress;
                // _continueReadingBook is updated in place if fullBook was fetched
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
        backgroundColor: const Color(0xFFF8FAFC),
        body: Column(
          children: [
            NavBarAll(userName: widget.userName),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFF59E0B),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadData,
                      color: const Color(0xFFF59E0B),
                      child: _error != null
                          ? _buildErrorState()
                          : _buildContent(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StatsSection(stats: _stats),
          const SizedBox(height: 32),

          if (_continueReadingBook != null) ...[
            _buildSectionHeader(context, 'Continuer la lecture', null),
            const SizedBox(height: 16),
            ContinueReadingSection(
              book: _continueReadingBook!,
              currentChapter: _readingProgress?.chapitreCourant,
              progress: (_readingProgress?.pourcentage ?? 0) / 100.0,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        ReadingPage(book: _continueReadingBook!.toJson()),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
          ],

          _buildSectionHeader(
            context,
            'Recommandations',
            () =>
                MainNavBar.mainNavBarKey.currentState?.navigateToMarketplace(),
          ),
          const SizedBox(height: 16),
          RecommendationsSection(books: _recommendations),
          const SizedBox(height: 32),

          if (_featuredAuthors.isNotEmpty) ...[
            _buildSectionHeader(context, 'Auteurs à la Une', null),
            const SizedBox(height: 16),
            FeaturedAuthorsSection(authors: _featuredAuthors),
            const SizedBox(height: 32),
          ],

          _buildSectionHeader(context, 'Activité Récente', null),
          const SizedBox(height: 12),
          if (_recentActivities.isEmpty)
            _buildEmptyActivity()
          else
            ..._recentActivities
                .take(3)
                .map(
                  (activity) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: RecentActivitySection(activity: activity),
                  ),
                ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    VoidCallback? onSeeMore,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1E293B),
            letterSpacing: -0.5,
          ),
        ),
        if (onSeeMore != null)
          TextButton(
            onPressed: onSeeMore,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFF59E0B),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Voir plus',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildErrorState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Center(
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
                  style: GoogleFonts.poppins(color: const Color(0xFF1E293B)),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                  ),
                  child: const Text("Réessayer"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyActivity() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Center(
        child: Text(
          "Aucune activité récente",
          style: GoogleFonts.poppins(
            color: const Color(0xFF64748B),
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
