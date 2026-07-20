import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/themes/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../data/dataServices/badgeService.dart';
import '../../../data/model/badgeModel.dart';

class BadgesPage extends StatefulWidget {
  final String userId;

  const BadgesPage({super.key, required this.userId});

  @override
  State<BadgesPage> createState() => _BadgesPageState();
}

class _BadgesPageState extends State<BadgesPage> {
  final BadgeService _badgeService = BadgeService();
  List<BadgeModel> _badges = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBadges();
  }

  Future<void> _loadBadges() async {
    final badges = await _badgeService.getUserBadges();
    if (mounted) {
      setState(() {
        _badges = badges;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          _isLoading
              ? SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.indigo),
                  ),
                )
              : (_badges.isEmpty ? _buildEmptyState() : _buildBadgesGrid()),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.emoji_events_outlined, size: 80, color: AppColors.textHint),
            SizedBox(height: 16),
            Text(
              "Aucun badge débloqué",
              style: AppTextStyles.bodyFaded16,
            ),
            Text(
              "Continuez à lire pour en obtenir !",
              style: GoogleFonts.poppins(color: AppColors.textHint, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 200.0,
      floating: false,
      pinned: true,
      backgroundColor: AppColors.cardBackground,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          "Mes Récompenses",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.indigo, AppColors.indigoDark],
                ),
              ),
            ),
            Positioned(
              right: -50,
              top: -20,
              child: Icon(
                Icons.emoji_events,
                size: 200,
                color: AppColors.textPrimary.withOpacity(0.1),
              ),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: 40),
                  Text(
                    "${_badges.length}",
                    style: GoogleFonts.poppins(
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    "Badges débloqués",
                    style: AppTextStyles.bodySecondary14,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgesGrid() {
    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 0.85,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildBadgeCard(_badges[index]),
          childCount: _badges.length,
        ),
      ),
    );
  }

  Widget _buildBadgeCard(BadgeModel badge) {
    bool isUnlocked = badge.debloqueLe != null;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isUnlocked
              ? AppColors.indigo.withOpacity(0.5)
              : AppColors.textHint,
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
                        ? AppColors.indigo.withOpacity(0.1)
                        : AppColors.textHint,
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
                                ? AppColors.indigoLight
                                : AppColors.textHint,
                          ),
                        )
                      : Icon(
                          _getIconData(badge.iconUrl),
                          size: 40,
                          color: isUnlocked
                              ? AppColors.indigoLight
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
                child: Icon(Icons.check, size: 10, color: AppColors.textPrimary),
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