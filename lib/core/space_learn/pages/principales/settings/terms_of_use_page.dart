import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:space_learn_flutter/core/themes/app_colors.dart';

class TermsOfUsePage extends StatelessWidget {
  const TermsOfUsePage({super.key});

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
          "Conditions d'utilisation",
          style: GoogleFonts.poppins(
            color: isDark ? Colors.white : AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Conditions d'Utilisation",
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 16),
            Text(
              "Dernière mise à jour : Juillet 2026",
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: isDark ? AppColors.textHint : Colors.black54,
              ),
            ),
            SizedBox(height: 24),
            _buildSection(
              isDark,
              "1. Acceptation des conditions",
              "En accédant et en utilisant l'application SpaceLearn, vous acceptez de vous conformer aux présentes conditions d'utilisation. Si vous n'êtes pas d'accord avec une partie de ces conditions, veuillez ne pas utiliser l'application.",
            ),
            SizedBox(height: 20),
            _buildSection(
              isDark,
              "2. Utilisation du service",
              "SpaceLearn offre une plateforme pour les lecteurs et les écrivains. Vous vous engagez à utiliser le service uniquement à des fins légales et d'une manière qui ne porte pas atteinte aux droits de tiers ou qui n'entrave pas l'utilisation du service par des tiers.",
            ),
            SizedBox(height: 20),
            _buildSection(
              isDark,
              "3. Propriété intellectuelle",
              "Tout le contenu publié sur la plateforme par les auteurs reste leur propriété intellectuelle. Les utilisateurs s'engagent à ne pas reproduire, distribuer ou modifier ce contenu sans l'autorisation expresse de l'auteur.",
            ),
            SizedBox(height: 20),
            _buildSection(
              isDark,
              "4. Comptes utilisateurs",
              "Vous êtes responsable du maintien de la confidentialité de votre compte et de votre mot de passe, ainsi que de la restriction de l'accès à votre appareil. Vous acceptez la responsabilité de toutes les activités qui se produisent sous votre compte.",
            ),
            SizedBox(height: 20),
            _buildSection(
              isDark,
              "5. Modifications des conditions",
              "SpaceLearn se réserve le droit de modifier ces conditions à tout moment. Les modifications entreront en vigueur dès leur publication sur la plateforme. Votre utilisation continue de l'application constitue votre acceptation des nouvelles conditions.",
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(bool isDark, String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 8),
        Text(
          content,
          style: GoogleFonts.poppins(
            fontSize: 14,
            height: 1.6,
            color: isDark ? AppColors.textSecondary : Colors.black87,
          ),
        ),
      ],
    );
  }
}