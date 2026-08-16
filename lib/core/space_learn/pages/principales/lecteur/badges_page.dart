import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/themes/app_dimensions.dart';
import 'package:space_learn_flutter/core/themes/app_text_styles.dart';
import '../../../../utils/token_storage.dart';
import '../../../data/dataServices/badgeService.dart';
import '../../../data/dataServices/libraryService.dart';
import '../../../data/dataServices/readingProgressService.dart';
import '../../../data/dataServices/reading_time_storage.dart';
import '../../../data/model/badgeModel.dart';
import '../../../data/model/goalModel.dart';
import '../../../data/model/readingActivityModel.dart';

class BadgesPage extends StatefulWidget {
  final String userId;

  const BadgesPage({super.key, required this.userId});

  @override
  State<BadgesPage> createState() => _BadgesPageState();
}

class _BadgesPageState extends State<BadgesPage>
    with SingleTickerProviderStateMixin {
  final BadgeService _badgeService = BadgeService();
  final ReadingProgressService _progressService = ReadingProgressService();
  final LibraryService _libraryService = LibraryService();

  List<BadgeModel> _badges = [];
  List<GoalModel> _goals = [];
  int _totalReadingMinutes = 0;
  int _todayReadingMinutes = 0;
  bool _isLoading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    try {
      final token = await TokenStorage.getToken();
      final totalMin =
          await ReadingTimeStorage.getTotalReadingMinutes(widget.userId);
      final todayMin =
          await ReadingTimeStorage.getTodayReadingMinutes(widget.userId);

      List<ReadingActivityModel> allProgress = [];
      int libraryCount = 0;
      if (token != null) {
        try {
          allProgress = await _progressService.getAllProgressions(token);
          final lib = await _libraryService.getUserLibrary(token);
          libraryCount = lib.length;
        } catch (_) {}
      }

      int finishedBooks = allProgress
          .where(
            (p) =>
                p.pourcentage >= 100 ||
                (p.lastPage >= p.totalPages && p.totalPages > 0),
          )
          .length;

      final backendBadges = await _badgeService.getUserBadges();
      final backendGoals = await _badgeService.getGoals();

      final smartGoals = ReadingTimeStorage.computeSmartGoals(
        booksRead: finishedBooks,
        totalMinutes: totalMin,
        todayMinutes: todayMin,
        libraryCount: libraryCount,
      );

      final List<GoalModel> finalGoals =
          backendGoals.isNotEmpty ? backendGoals : smartGoals;

      // Update badge unlock states dynamically based on real activity
      final updatedBadges = backendBadges.map((b) {
        bool isUnlocked = b.debloqueLe != null;
        if (!isUnlocked) {
          if (b.code == 'FIRST_STEP' &&
              (totalMin > 0 || allProgress.isNotEmpty)) {
            isUnlocked = true;
          } else if (b.code == 'FIRST_BOOK' && finishedBooks >= 1) {
            isUnlocked = true;
          } else if (b.code == 'DAILY_15MIN' && todayMin >= 15) {
            isUnlocked = true;
          } else if (b.code == 'COLLECTION_2' && libraryCount >= 2) {
            isUnlocked = true;
          } else if (b.code == 'READ_60MIN' && totalMin >= 60) {
            isUnlocked = true;
          }
        }
        return BadgeModel(
          id: b.id,
          utilisateurId: b.utilisateurId,
          debloqueLe: isUnlocked ? (b.debloqueLe ?? DateTime.now()) : null,
          name: b.name,
          description: b.description,
          iconUrl: b.iconUrl,
          code: b.code,
        );
      }).toList();

      if (mounted) {
        setState(() {
          _totalReadingMinutes = totalMin;
          _todayReadingMinutes = todayMin;
          _badges = updatedBadges;
          _goals = finalGoals;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    AppColors.suivreLeTheme(context);
    final unlockedCount = _badges.where((b) => b.debloqueLe != null).length;
    final formattedTime =
        ReadingTimeStorage.formatMinutes(_totalReadingMinutes);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.cardBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Statistiques & Récompenses",
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.accentInk,
          unselectedLabelColor: AppColors.textHint,
          labelStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          tabs: const [
            Tab(text: "Objectifs & Défis"),
            Tab(text: "Badges Débloqués"),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              children: [
                _buildSummaryHeader(unlockedCount, formattedTime),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [_buildGoalsTab(), _buildBadgesTab()],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSummaryHeader(int unlockedCount, String formattedTime) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryDark, AppColors.primary],
        ),
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.18),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(
            children: [
              Icon(Icons.timer_outlined, color: AppColors.onAccent, size: 24),
              const SizedBox(height: 6),
              Text(
                formattedTime,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.onAccent,
                ),
              ),
              Text(
                "Temps de lecture",
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: AppColors.onAccent.withOpacity(0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          Container(
            height: 40,
            width: 1,
            color: AppColors.onAccent.withOpacity(0.25),
          ),
          Column(
            children: [
              Icon(Icons.emoji_events_outlined,
                  color: AppColors.onAccent, size: 24),
              const SizedBox(height: 6),
              Text(
                "$unlockedCount / ${_badges.length}",
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.onAccent,
                ),
              ),
              Text(
                "Badges obtenus",
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: AppColors.onAccent.withOpacity(0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGoalsTab() {
    if (_goals.isEmpty) {
      return Center(
        child: Text(
          "Aucun défi en cours",
          style: GoogleFonts.poppins(color: AppColors.textHint),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _goals.length,
      itemBuilder: (context, index) {
        final goal = _goals[index];
        final progress = goal.progress;
        final isCompleted = goal.estTermine;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
            border: Border.all(
              color: isCompleted
                  ? AppColors.success.withOpacity(0.4)
                  : AppColors.textPrimary.withOpacity(0.05),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      goal.titre,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? AppColors.success.withOpacity(0.15)
                          : AppColors.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusPill,
                      ),
                    ),
                    child: Text(
                      isCompleted
                          ? "Terminé 🎉"
                          : "${(progress * 100).round()}%",
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isCompleted
                            ? AppColors.success
                            : AppColors.accentInk,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                goal.description,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius:
                    BorderRadius.circular(AppDimensions.radiusXs),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: AppColors.textHint.withOpacity(0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isCompleted ? AppColors.success : AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBadgesTab() {
    if (_badges.isEmpty) return _buildEmptyState();
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      itemCount: _badges.length,
      itemBuilder: (context, index) => _buildBadgeCard(_badges[index]),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.emoji_events_outlined,
            size: 80,
            color: AppColors.textHint,
          ),
          SizedBox(height: 16),
          Text("Aucun badge débloqué", style: AppTextStyles.bodyFaded16),
          Text(
            "Continuez à lire pour en obtenir !",
            style: GoogleFonts.poppins(
              color: AppColors.textHint,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeCard(BadgeModel badge) {
    bool isUnlocked = badge.debloqueLe != null;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(
          color: isUnlocked
              ? AppColors.primary.withOpacity(0.5)
              : AppColors.textHint.withOpacity(0.3),
        ),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isUnlocked
                        ? AppColors.primary.withOpacity(0.12)
                        : AppColors.textHint.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: badge.iconUrl.startsWith('http')
                      ? Image.network(
                          badge.iconUrl,
                          width: 40,
                          height: 40,
                          color: isUnlocked ? null : AppColors.textHint,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.emoji_events,
                            size: 40,
                            color: isUnlocked
                                ? AppColors.accentInk
                                : AppColors.textHint,
                          ),
                        )
                      : Icon(
                          _getIconData(badge.iconUrl),
                          size: 40,
                          color: isUnlocked
                              ? AppColors.accentInk
                              : AppColors.textHint,
                        ),
                ),
                SizedBox(height: 12),
                Text(
                  badge.name,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isUnlocked ? Colors.white : AppColors.textHint,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  badge.description,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: AppColors.textHint,
                  ),
                ),
              ],
            ),
          ),
          if (isUnlocked)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check,
                  size: 10,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  IconData _getIconData(String? name) {
    switch (name) {
      case 'stars':
        return Icons.stars;
      case 'auto_stories':
        return Icons.auto_stories;
      case 'timer':
        return Icons.timer;
      case 'rate_review':
        return Icons.rate_review;
      case 'inventory_2':
        return Icons.inventory_2;
      default:
        return Icons.emoji_events;
    }
  }
}
