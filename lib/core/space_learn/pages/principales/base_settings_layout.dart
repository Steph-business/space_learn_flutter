import 'package:flutter/material.dart';
import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/authServices.dart';
import 'package:space_learn_flutter/core/utils/profile_storage.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/auth/login.dart';

import 'package:space_learn_flutter/core/themes/layout/nav_bar_lecteur.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/ecrivain/accueil_auteur_page.dart';

/// Un composant UI réutilisable pour structurer les pages de paramètres (Lecteur et Auteur).
class BaseSettingsLayout extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final Color primaryAccentColor;

  BaseSettingsLayout({
    super.key,
    required this.title,
    required this.children,
    this.primaryAccentColor = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(color: AppColors.scaffoldBackground),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            automaticallyImplyLeading: false,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
              onPressed: () {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                } else {
                  // Fallback for when it's the root of a bottom nav bar
                  if (MainNavBar.mainNavBarKey.currentState != null) {
                    MainNavBar.mainNavBarKey.currentState!.goHome();
                  } else if (HomePageAuteur.navKey.currentState != null) {
                    HomePageAuteur.navKey.currentState!.goHome();
                  }
                }
              },
            ),
            title: Text(
              title,
              style: GoogleFonts.poppins(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            centerTitle: true,
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...children,
                  SizedBox(height: 12),
                  // Bouton de déconnexion premium réutilisable
                  _buildLogoutButton(context),
                  SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 24),
      height: 52,
      child: ElevatedButton.icon(
        onPressed: () => showLogoutDialog(context),
        icon: Icon(Icons.logout_rounded, color: AppColors.textPrimary, size: 20),
        label: Text(
          "Se déconnecter",
          style: GoogleFonts.poppins(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.error.withOpacity(0.85),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: AppColors.error.withOpacity(0.3), width: 1.5),
          ),
        ),
      ),
    );
  }

  static void showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.textPrimary.withOpacity(0.08)),
              
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.error.withOpacity(0.12),
                    border: Border.all(
                      color: AppColors.error.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    Icons.logout_rounded,
                    size: 28,
                    color: AppColors.error,
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  "Déconnexion",
                  style: GoogleFonts.poppins(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 12),
                Text(
                  "Êtes-vous sûr de vouloir vous déconnecter de votre compte ?",
                  style: GoogleFonts.poppins(
                    color: AppColors.textPrimary.withOpacity(0.7),
                    fontSize: 14,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.textHint,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            "Annuler",
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () async {
                            Navigator.of(context).pop();
                            final authService = AuthService();
                            await authService.logout();
                            await ProfileStorage.clearSelectedProfile();
                            await ProfileStorage.clearSelectedProfileRole();
                            if (context.mounted) {
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(builder: (_) => const LoginPage()),
                                (route) => false,
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error,
                            foregroundColor: AppColors.textPrimary,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            "Déconnexion",
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Un élément de paramètre stylisé et cliquable.
class SettingItemTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const SettingItemTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.cardBackground,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      borderOnForeground: false,
      elevation: 0,
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.textPrimary.withOpacity(0.04),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.textPrimary.withOpacity(0.9), size: 22),
        ),
        title: Text(
          title,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.poppins(
            color: AppColors.textPrimary.withOpacity(0.5),
            fontSize: 12.5,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios_rounded,
          size: 14,
          color: AppColors.textPrimary.withOpacity(0.3),
        ),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
    );
  }
}

/// Un titre de section pour séparer les catégories de paramètres.
class SettingSectionHeader extends StatelessWidget {
  final String title;
  final Color accentColor;

  SettingSectionHeader({
    super.key,
    required this.title,
    this.accentColor = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 16, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: accentColor,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}