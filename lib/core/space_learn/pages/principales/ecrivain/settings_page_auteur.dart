import 'package:flutter/material.dart';
import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/utils/app_notifications.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/profilePage.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/base_settings_layout.dart';

class SettingsPageAuteur extends StatelessWidget {
  const SettingsPageAuteur({super.key});

  @override
  Widget build(BuildContext context) {
    return BaseSettingsLayout(
      title: "Paramètres Auteur",
      primaryAccentColor: AppColors.secondaryVariant,
      children: [
        // Section Profil
        const SettingSectionHeader(title: "Profil", accentColor: AppColors.secondaryVariant),
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
            AppNotifications.showSnackBar(
              context,
              message: "Fonctionnalité de mise à jour de photo de profil d'auteur en cours d'intégration.",
            );
          },
        ),

        // Section Écriture
        const SettingSectionHeader(title: "Écriture", accentColor: AppColors.secondaryVariant),
        SettingItemTile(
          icon: Icons.edit_outlined,
          title: "Préférences d'écriture",
          subtitle: "Police, taille du texte, thème",
          onTap: () {
            AppNotifications.showSnackBar(
              context,
              message: "Préférences d'écriture bientôt disponibles.",
            );
          },
        ),
        SettingItemTile(
          icon: Icons.notifications_outlined,
          title: "Notifications de ventes",
          subtitle: "Rappels de ventes, nouveaux commentaires",
          onTap: () {
            AppNotifications.showSnackBar(
              context,
              message: "Paramètres de notification de ventes bientôt disponibles.",
            );
          },
        ),

        // Section Publication
        const SettingSectionHeader(title: "Publication", accentColor: AppColors.secondaryVariant),
        SettingItemTile(
          icon: Icons.publish_outlined,
          title: "Paramètres de publication",
          subtitle: "Visibilité, prix, droits d'auteur",
          onTap: () {
            AppNotifications.showSnackBar(
              context,
              message: "Paramètres de publication bientôt disponibles.",
            );
          },
        ),
        SettingItemTile(
          icon: Icons.analytics_outlined,
          title: "Rapports de ventes",
          subtitle: "Statistiques détaillées",
          onTap: () {
            AppNotifications.showSnackBar(
              context,
              message: "Accès aux rapports de ventes en cours de préparation.",
            );
          },
        ),

        // Section Application
        const SettingSectionHeader(title: "Application", accentColor: AppColors.secondaryVariant),
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

        // Section Sécurité
        const SettingSectionHeader(title: "Sécurité", accentColor: AppColors.secondaryVariant),
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
          subtitle: "Gérer vos données personnelles d'auteur",
          onTap: () {
            AppNotifications.showSnackBar(
              context,
              message: "Paramètres de confidentialité d'auteur en cours d'intégration.",
            );
          },
        ),

        // Section Support
        const SettingSectionHeader(title: "Support", accentColor: AppColors.secondaryVariant),
        SettingItemTile(
          icon: Icons.help_outline,
          title: "Aide & FAQ",
          subtitle: "Trouver des réponses",
          onTap: () {
            AppNotifications.showSnackBar(
              context,
              message: "FAQ d'auteur bientôt disponible.",
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
        const SettingSectionHeader(title: "À propos", accentColor: AppColors.secondaryVariant),
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
      ],
    );
  }
}
