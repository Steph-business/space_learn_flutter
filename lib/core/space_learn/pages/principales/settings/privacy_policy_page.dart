import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/utils/app_notifications.dart';

class PrivacyPolicyPage extends StatefulWidget {
  const PrivacyPolicyPage({super.key});

  @override
  State<PrivacyPolicyPage> createState() => _PrivacyPolicyPageState();
}

class _PrivacyPolicyPageState extends State<PrivacyPolicyPage> {
  bool _shareAnalytics = true;
  bool _personalizedAds = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.scaffoldBackground : Color.fromARGB(255, 250, 249, 246),
      appBar: AppBar(
        backgroundColor: AppColors.scaffoldBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          "Confidentialité",
          style: GoogleFonts.poppins(
            color: isDark ? Colors.white : AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            "Vos données, votre choix",
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 8),
          Text(
            "Nous accordons une grande importance à la protection de votre vie privée. Gérez ici vos préférences.",
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: 28),
          Card(
            color: AppColors.cardBackground,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                SwitchListTile(
                  title: Text("Partager les statistiques d'utilisation", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 14)),
                  subtitle: Text("Nous aide à améliorer l'application en collectant des données de crash anonymes.", style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 12)),
                  value: _shareAnalytics,
                  activeColor: AppColors.primary,
                  onChanged: (val) {
                    setState(() => _shareAnalytics = val);
                    AppNotifications.showSnackBar(context, message: "Préférences d'analyse mises à jour.", isSuccess: true);
                  },
                ),
                Divider(height: 1, indent: 16, endIndent: 16),
                SwitchListTile(
                  title: Text("Recommandations personnalisées", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 14)),
                  subtitle: Text("Permet de vous proposer des livres adaptés à vos habitudes de lecture.", style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 12)),
                  value: _personalizedAds,
                  activeColor: AppColors.primary,
                  onChanged: (val) {
                    setState(() => _personalizedAds = val);
                    AppNotifications.showSnackBar(context, message: "Préférences de recommandation mises à jour.", isSuccess: true);
                  },
                ),
              ],
            ),
          ),
          SizedBox(height: 32),
          Text(
            "Politique de confidentialité",
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 12),
          Text(
            "1. Collecte de données\nNous collectons les données nécessaires à l'authentification et à la synchronisation de vos livres lus, de votre progression et de votre portefeuille de parrainage.\n\n2. Partage des données\nVos données ne sont jamais partagées ou vendues à des tiers à des fins publicitaires.\n\n3. Sécurité\nToutes vos transactions et données personnelles sont cryptées de bout en bout.",
            style: GoogleFonts.poppins(
              fontSize: 13.5,
              height: 1.6,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}