import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/utils/app_notifications.dart';

class LanguageSelectionPage extends StatefulWidget {
  const LanguageSelectionPage({super.key});

  @override
  State<LanguageSelectionPage> createState() => _LanguageSelectionPageState();
}

class _LanguageSelectionPageState extends State<LanguageSelectionPage> {
  String _selectedLang = 'fr';

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
          "Langue",
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
            "Langue de l'application",
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 8),
          Text(
            "Sélectionnez votre langue d'affichage préférée.",
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
                _buildLangTile("Français (French)", "fr", "🇫🇷"),
                Divider(height: 1, indent: 16, endIndent: 16),
                _buildLangTile("English (English)", "en", "🇬🇧"),
                Divider(height: 1, indent: 16, endIndent: 16),
                _buildLangTile("Español (Spanish)", "es", "🇪🇸"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLangTile(String name, String code, String flag) {
    final isSelected = _selectedLang == code;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      leading: Text(flag, style: TextStyle(fontSize: 24)),
      title: Text(
        name,
        style: GoogleFonts.poppins(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? AppColors.primary : (AppColors.textPrimary),
        ),
      ),
      trailing: isSelected ? Icon(Icons.check_circle, color: AppColors.primary) : null,
      onTap: () {
        setState(() => _selectedLang = code);
        AppNotifications.showSnackBar(context, message: "Langue modifiée avec succès !", isSuccess: true);
      },
    );
  }
}