import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/themes/theme_provider.dart';
import 'package:space_learn_flutter/core/utils/app_notifications.dart';
import 'package:space_learn_flutter/core/utils/token_storage.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/authServices.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/profilePage.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/readingPreferencesPage.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/base_settings_layout.dart';

// Nouvelles pages de paramètres
import 'package:space_learn_flutter/core/space_learn/pages/principales/settings/password_change_page.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/settings/help_faq_page.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/settings/privacy_policy_page.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/settings/language_selection_page.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/settings/notification_settings_page.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/settings/publication_settings_page.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/settings/sales_report_page.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/settings/terms_of_use_page.dart';

class SettingsPageAuteur extends StatelessWidget {
  const SettingsPageAuteur({super.key});

  @override
  Widget build(BuildContext context) {
    return BaseSettingsLayout(
      title: "Paramètres Auteur",
      primaryAccentColor: AppColors.secondaryVariant,
      children: [
        // Section Profil
        SettingSectionHeader(title: "Profil", accentColor: AppColors.secondaryVariant),
        SettingItemTile(
          icon: Icons.person_outline_rounded,
          title: "Informations personnelles",
          subtitle: "Modifier vos informations d'auteur",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ProfilePage(),
              ),
            );
          },
        ),
        SettingItemTile(
          icon: Icons.photo_camera_outlined,
          title: "Photo de profil",
          subtitle: "Changer votre photo d'auteur",
          onTap: () {
            _pickProfilePhoto(context);
          },
        ),



        // Section Publication
        SettingSectionHeader(title: "Publication", accentColor: AppColors.secondaryVariant),
        SettingItemTile(
          icon: Icons.publish_outlined,
          title: "Paramètres de publication",
          subtitle: "Visibilité, prix, droits d'auteur",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const PublicationSettingsPage(),
              ),
            );
          },
        ),
        SettingItemTile(
          icon: Icons.analytics_outlined,
          title: "Rapports de ventes",
          subtitle: "Statistiques détaillées",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SalesReportPage(),
              ),
            );
          },
        ),

        // Section Application
        SettingSectionHeader(title: "Application", accentColor: AppColors.secondaryVariant),
        SettingItemTile(
          icon: Icons.language_outlined,
          title: "Langue",
          subtitle: "Français",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const LanguageSelectionPage(),
              ),
            );
          },
        ),
        SettingItemTile(
          icon: Icons.dark_mode_outlined,
          title: "Thème",
          subtitle: "Changer le thème de l'application",
          onTap: () {
            _showThemeSelectorDialog(context);
          },
        ),

        // Section Sécurité
        SettingSectionHeader(title: "Sécurité", accentColor: AppColors.secondaryVariant),
        SettingItemTile(
          icon: Icons.lock_outline,
          title: "Mot de passe",
          subtitle: "Changer votre mot de passe",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const PasswordChangePage(),
              ),
            );
          },
        ),
        SettingItemTile(
          icon: Icons.security_outlined,
          title: "Confidentialité",
          subtitle: "Gérer vos données personnelles d'auteur",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const PrivacyPolicyPage(),
              ),
            );
          },
        ),

        // Section Support
        SettingSectionHeader(title: "Support", accentColor: AppColors.secondaryVariant),
        SettingItemTile(
          icon: Icons.help_outline,
          title: "Aide & FAQ",
          subtitle: "Trouver des réponses",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const HelpFaqPage(),
              ),
            );
          },
        ),
        SettingItemTile(
          icon: Icons.contact_support_outlined,
          title: "Contacter le support",
          subtitle: "Nous contacter",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const HelpFaqPage(),
              ),
            );
          },
        ),

        // Section À propos
        SettingSectionHeader(title: "À propos", accentColor: AppColors.secondaryVariant),
        SettingItemTile(
          icon: Icons.info_outline,
          title: "Version de l'application",
          subtitle: "1.0.0",
          onTap: () {
            AppNotifications.showPremiumDialog(
              context,
              title: "Version de l'application",
              message: "SpaceLearn Mobile (Auteur)\nVersion: 1.0.0\nConstruit avec amour par Steph-business.",
              confirmText: "Fermer",
              isSuccess: true,
            );
          },
        ),
        SettingItemTile(
          icon: Icons.description_outlined,
          title: "Conditions d'utilisation",
          subtitle: "Lire les conditions",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const TermsOfUsePage(),
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _pickProfilePhoto(BuildContext context) async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (image == null) return;

      AppNotifications.showSnackBar(context, message: "Téléversement de l'image en cours...");

      String? photoUrl;
      try {
        final bytes = await image.readAsBytes();
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
        
        await Supabase.instance.client.storage
            .from('avatars')
            .uploadBinary(
              fileName,
              bytes,
              fileOptions: const FileOptions(
                contentType: 'image/jpeg',
                upsert: true,
              ),
            );
            
        photoUrl = Supabase.instance.client.storage
            .from('avatars')
            .getPublicUrl(fileName);
      } catch (_) {
        try {
          final bytes = await image.readAsBytes();
          final base64String = base64Encode(bytes);
          final extension = image.path.split('.').last;
          photoUrl = 'data:image/$extension;base64,$base64String';
        } catch (_) {
          AppNotifications.showSnackBar(context, message: "Erreur lors du traitement de l'image.", isError: true);
          return;
        }
      }

      if (photoUrl != null) {
        final token = await TokenStorage.getToken();
        if (token != null) {
          final authService = AuthService();
          final user = await authService.getUser(token);
          if (user != null) {
            final updatedUser = await authService.updateProfileDetails(
              userId: user.id,
              profilePhoto: photoUrl,
            );
            if (updatedUser != null) {
              AppNotifications.showSnackBar(context, message: "Photo de profil mise à jour !", isSuccess: true);
            } else {
              AppNotifications.showSnackBar(context, message: "Erreur lors de la mise à jour.", isError: true);
            }
          }
        }
      }
    } catch (e) {
      AppNotifications.showSnackBar(context, message: "Erreur lors du choix de l'image.", isError: true);
    }
  }

  void _showThemeSelectorDialog(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: isDark ? AppColors.textHint : Colors.black.withOpacity(0.05)),
              
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Sélectionner le thème",
                  style: GoogleFonts.poppins(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 16),
                _buildThemeOption(context, "Thème Clair", ThemeMode.light, Icons.light_mode_outlined, themeProvider),
                _buildThemeOption(context, "Thème Sombre", ThemeMode.dark, Icons.dark_mode_outlined, themeProvider),
                _buildThemeOption(context, "Thème Système", ThemeMode.system, Icons.phone_android_outlined, themeProvider),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildThemeOption(
    BuildContext context,
    String title,
    ThemeMode mode,
    IconData icon,
    ThemeProvider themeProvider,
  ) {
    final isSelected = themeProvider.themeMode == mode;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      leading: Icon(icon, color: isSelected ? AppColors.primary : (AppColors.textSecondary)),
      title: Text(
        title,
        style: GoogleFonts.poppins(
          color: isSelected ? AppColors.primary : (AppColors.textPrimary),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: isSelected ? Icon(Icons.check_circle, color: AppColors.primary) : null,
      onTap: () {
        themeProvider.setThemeMode(mode);
        Navigator.of(context).pop();
      },
    );
  }
}