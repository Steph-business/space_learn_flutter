import 'package:flutter/material.dart';

import '../../../themes/app_colors.dart';

class SettingsPageAuteur extends StatelessWidget {
  const SettingsPageAuteur({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 250, 249, 246),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          "Paramètres Auteur",
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Titre principal
            const Text(
              "Paramètres Auteur",
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // Section Profil
            _buildSectionTitle("Profil"),
            _buildSettingItem(
              icon: Icons.person_outline,
              title: "Informations personnelles",
              subtitle: "Modifier vos informations d'auteur",
              onTap: () {
                // Navigation vers la page de profil auteur
              },
            ),
            _buildSettingItem(
              icon: Icons.photo_camera_outlined,
              title: "Photo de profil",
              subtitle: "Changer votre photo d'auteur",
              onTap: () {
                // Navigation vers la page de changement de photo
              },
            ),

            const SizedBox(height: 20),

            // Section Écriture
            _buildSectionTitle("Écriture"),
            _buildSettingItem(
              icon: Icons.edit_outlined,
              title: "Préférences d'écriture",
              subtitle: "Police, taille du texte, thème",
              onTap: () {
                // Navigation vers les préférences d'écriture
              },
            ),
            _buildSettingItem(
              icon: Icons.notifications_outlined,
              title: "Notifications de ventes",
              subtitle: "Rappels de ventes, nouveaux commentaires",
              onTap: () {
                // Navigation vers les notifications de ventes
              },
            ),

            const SizedBox(height: 20),

            // Section Publication
            _buildSectionTitle("Publication"),
            _buildSettingItem(
              icon: Icons.publish_outlined,
              title: "Paramètres de publication",
              subtitle: "Visibilité, prix, droits d'auteur",
              onTap: () {
                // Navigation vers les paramètres de publication
              },
            ),
            _buildSettingItem(
              icon: Icons.analytics_outlined,
              title: "Rapports de ventes",
              subtitle: "Statistiques détaillées",
              onTap: () {
                // Navigation vers les rapports
              },
            ),

            const SizedBox(height: 20),

            // Section Application
            _buildSectionTitle("Application"),
            _buildSettingItem(
              icon: Icons.language_outlined,
              title: "Langue",
              subtitle: "Français",
              onTap: () {
                // Navigation vers la sélection de langue
              },
            ),
            _buildSettingItem(
              icon: Icons.dark_mode_outlined,
              title: "Thème",
              subtitle: "Mode automatique",
              onTap: () {
                // Navigation vers la sélection de thème
              },
            ),

            const SizedBox(height: 20),

            // Section Sécurité
            _buildSectionTitle("Sécurité"),
            _buildSettingItem(
              icon: Icons.lock_outline,
              title: "Mot de passe",
              subtitle: "Changer votre mot de passe",
              onTap: () {
                // Navigation vers le changement de mot de passe
              },
            ),
            _buildSettingItem(
              icon: Icons.security_outlined,
              title: "Confidentialité",
              subtitle: "Gérer vos données personnelles",
              onTap: () {
                // Navigation vers les paramètres de confidentialité
              },
            ),

            const SizedBox(height: 20),

            // Section Support
            _buildSectionTitle("Support"),
            _buildSettingItem(
              icon: Icons.help_outline,
              title: "Aide & FAQ",
              subtitle: "Trouver des réponses",
              onTap: () {
                // Navigation vers l'aide
              },
            ),
            _buildSettingItem(
              icon: Icons.contact_support_outlined,
              title: "Contacter le support",
              subtitle: "Nous contacter",
              onTap: () {
                // Navigation vers le contact support
              },
            ),

            const SizedBox(height: 20),

            // Section À propos
            _buildSectionTitle("À propos"),
            _buildSettingItem(
              icon: Icons.info_outline,
              title: "Version de l'application",
              subtitle: "1.0.0",
              onTap: () {
                // Afficher les informations de version
              },
            ),

            const SizedBox(height: 20),

            // Bouton de déconnexion
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(vertical: 20),
              child: ElevatedButton.icon(
                onPressed: () {
                  // Logique de déconnexion
                  _showLogoutDialog(context);
                },
                icon: const Icon(Icons.logout, color: Colors.white),
                label: const Text(
                  "Se déconnecter",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Colors.grey,
        ),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Déconnexion"),
          content: const Text("Êtes-vous sûr de vouloir vous déconnecter ?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Annuler"),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Logique de déconnexion
                // Navigator.of(context).pushReplacementNamed('/login');
              },
              child: const Text(
                "Se déconnecter",
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }
}
