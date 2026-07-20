import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/themes/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:space_learn_flutter/core/utils/token_storage.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/authServices.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/ecrivain/abonnes_page.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/book_model.dart';

import 'package:space_learn_flutter/core/space_learn/data/dataServices/relationService.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/ecrivain/accueil_auteur_page.dart';

class Statistique extends StatefulWidget {
  final Map<String, dynamic> stats;
  const Statistique({super.key, required this.stats});

  @override
  State<Statistique> createState() => _StatistiqueState();
}

class _StatistiqueState extends State<Statistique> {
  final AuthService _authService = AuthService();
  final RelationService _relationService = RelationService();
  String? _authorId;
  int _followersCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    try {
      final token = await TokenStorage.getToken();
      if (token != null) {
        final user = await _authService.getUser(token);
        if (user != null && mounted) {
          setState(() {
            _authorId = user.id;
          });
          _loadFollowers(user.id);
        }
      }
    } catch (e) {
    }
  }

  Future<void> _loadFollowers(String userId) async {
    try {
      final followers = await _relationService.getFollowers(userId);
      if (mounted) {
        setState(() => _followersCount = followers.length);
      }
    } catch (e) {
    }
  }

  @override
  Widget build(BuildContext context) {
    // Extract values from stats map
    final double totalRevenue =
        (widget.stats['total_revenue'] ?? 0).toDouble();
    
    final int readersCount =
        widget.stats['total_followers'] ?? _followersCount;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                "VENTES",
                "${totalRevenue.toStringAsFixed(0)} FCFA",
                "", // Removed fake growth
                Icons.account_balance_wallet_rounded,
                AppColors.cardBackground,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  if (_authorId != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AbonnesPage(authorId: _authorId!),
                      ),
                    );
                  }
                },
                child: _buildStatCard(
                  "LECTEURS",
                  "$readersCount",
                  "", // Removed fake growth
                  Icons.people_alt_rounded,
                  AppColors.cardBackground,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        GestureDetector(
          onTap: () {
            HomePageAuteur.navKey.currentState?.setIndex(3);
          },
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryVariant.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.campaign_rounded,
                    color: AppColors.secondaryVariant,
                    size: 20,
                  ),
                ),
                SizedBox(width: 15),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "COMMUNAUTÉ",
                      style: GoogleFonts.poppins(
                        color: AppColors.textPrimary.withOpacity(0.5),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.1,
                      ),
                    ),
                    Text(
                      "Gérer mes annonces & évènements",
                      style: GoogleFonts.poppins(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Spacer(),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: AppColors.textHint,
                  size: 14,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    String growth,
    IconData icon,
    Color bgColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  color: AppColors.textPrimary.withOpacity(0.5),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.1,
                ),
              ),
              Icon(icon, color: AppColors.primary, size: 18),
            ],
          ),
          SizedBox(height: 12),
          Text(value, style: AppTextStyles.pageTitle),
          if (growth.isNotEmpty) ...[
            SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.show_chart, color: Colors.greenAccent, size: 14),
                SizedBox(width: 4),
                Text(
                  growth,
                  style: GoogleFonts.poppins(
                    color: Colors.greenAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ] else SizedBox(height: 18),
        ],
      ),
    );
  }
}