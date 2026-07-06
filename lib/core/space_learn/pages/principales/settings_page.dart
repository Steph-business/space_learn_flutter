import 'package:flutter/material.dart';
import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/utils/app_notifications.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/profilePage.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/readingPreferencesPage.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/base_settings_layout.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BaseSettingsLayout(
      title: "Paramètres",
      primaryAccentColor: AppColors.primary,
      children: [
        // Section Profil
        const SettingSectionHeader(title: "Profil", accentColor: AppColors.primary),
        SettingItemTile(
          icon: Icons.person_outline_rounded,
          title: "Informations personnelles",
          subtitle: "Modifier vos informations",
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
          subtitle: "Changer votre photo",
          onTap: () {
            AppNotifications.showSnackBar(
              context,
              message: "Fonctionnalité de mise à jour de photo de profil en cours d'intégration.",
            );
          },
        ),

        // Section Lecture
        const SettingSectionHeader(title: "Lecture", accentColor: AppColors.primary),
        SettingItemTile(
          icon: Icons.book_outlined,
          title: "Préférences de lecture",
          subtitle: "Police, taille du texte, thème",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ReadingPreferencesPage(),
              ),
            );
          },
        ),
        SettingItemTile(
          icon: Icons.notifications_outlined,
          title: "Notifications de lecture",
          subtitle: "Rappels de lecture, nouveaux chapitres",
          onTap: () {
            AppNotifications.showSnackBar(
              context,
              message: "Paramètres de notification bientôt disponibles.",
            );
          },
        ),

        // Section Application
        const SettingSectionHeader(title: "Application", accentColor: AppColors.primary),
        SettingItemTile(
          icon: Icons.language_outlined,
          title: "Langue",
          subtitle: "Français",
          onTap: () {
            AppNotifications.showSnackBar(
              context,
              message: "Sélection de la langue bientôt disponible.",
            );
          },
        ),
        SettingItemTile(
          icon: Icons.dark_mode_outlined,
          title: "Thème",
          subtitle: "Mode automatique",
          onTap: () {
            AppNotifications.showSnackBar(
              context,
              message: "Changement de thème bientôt disponible.",
            );
          },
        ),
        SettingItemTile(
          icon: Icons.download_outlined,
          title: "Téléchargements",
          subtitle: "Gérer les livres téléchargés",
          onTap: () {
            AppNotifications.showSnackBar(
              context,
              message: "Gestionnaire de téléchargements bientôt disponible.",
            );
          },
        ),

        // Section Sécurité
        const SettingSectionHeader(title: "Sécurité", accentColor: AppColors.primary),
        SettingItemTile(
          icon: Icons.lock_outline,
          title: "Mot de passe",
          subtitle: "Changer votre mot de passe",
          onTap: () {
            AppNotifications.showSnackBar(
              context,
              message: "Changement de mot de passe disponible prochainement.",
            );
          },
        ),
        SettingItemTile(
          icon: Icons.security_outlined,
          title: "Confidentialité",
          subtitle: "Gérer vos données personnelles",
          onTap: () {
            AppNotifications.showSnackBar(
              context,
              message: "Paramètres de confidentialité en cours d'intégration.",
            );
          },
        ),

        // Section Support
        const SettingSectionHeader(title: "Support", accentColor: AppColors.primary),
        SettingItemTile(
          icon: Icons.help_outline,
          title: "Aide & FAQ",
          subtitle: "Trouver des réponses",
          onTap: () {
            AppNotifications.showSnackBar(
              context,
              message: "Centre d'aide et FAQ en cours de développement.",
            );
          },
        ),
        SettingItemTile(
          icon: Icons.contact_support_outlined,
          title: "Contacter le support",
          subtitle: "Nous contacter",
          onTap: () {
            AppNotifications.showSnackBar(
              context,
              message: "Formulaire de contact avec le support en développement.",
            );
          },
        ),

        // Section À propos
        const SettingSectionHeader(title: "À propos", accentColor: AppColors.primary),
        SettingItemTile(
          icon: Icons.info_outline,
          title: "Version de l'application",
          subtitle: "1.0.0",
          onTap: () {
            AppNotifications.showPremiumDialog(
              context,
              title: "Version de l'application",
              message: "SpaceLearn Mobile\nVersion: 1.0.0\nConstruit avec amour par Steph-business.",
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
            AppNotifications.showSnackBar(
              context,
              message: "Chargement des CGU...",
            );
          },
        ),
      ],
    );
  }
}
