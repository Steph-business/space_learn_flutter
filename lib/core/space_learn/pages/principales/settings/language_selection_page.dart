import 'package:flutter/material.dart';
import 'package:space_learn_flutter/core/themes/app_dimensions.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  void initState() {
    super.initState();
    _loadLang();
  }

  Future<void> _loadLang() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _selectedLang = prefs.getString('pref_app_language') ?? 'fr';
      });
    }
  }

  Future<void> _setLang(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pref_app_language', code);
  }

  @override
  Widget build(BuildContext context) {
    AppColors.suivreLeTheme(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark
          ? AppColors.scaffoldBackground
          : const Color.fromARGB(255, 250, 249, 246),
      appBar: AppBar(
        backgroundColor: AppColors.scaffoldBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.accentInk),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          "Langue",
          style: GoogleFonts.poppins(
            color: isDark ? Colors.white : AppColors.accentInk,
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
          const SizedBox(height: 8),
          Text(
            "Sélectionnez votre langue d'affichage préférée.",
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 28),
          Card(
            color: AppColors.cardBackground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
            ),
            elevation: 0,
            child: Column(
              children: [
                _buildLangTile(
                  name: "Français",
                  subtitle: "French",
                  code: "fr",
                  flag: "🇫🇷",
                  isAvailable: true,
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                _buildLangTile(
                  name: "English",
                  subtitle: "Anglais",
                  code: "en",
                  flag: "🇬🇧",
                  isAvailable: false,
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                _buildLangTile(
                  name: "Español",
                  subtitle: "Espagnol",
                  code: "es",
                  flag: "🇪🇸",
                  isAvailable: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLangTile({
    required String name,
    required String subtitle,
    required String code,
    required String flag,
    required bool isAvailable,
  }) {
    final isSelected = _selectedLang == code && isAvailable;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.12)
              : (isAvailable
                  ? Colors.grey.withValues(alpha: 0.1)
                  : Colors.grey.withValues(alpha: 0.05)),
          borderRadius: BorderRadius.circular(AppDimensions.radiusInner),
        ),
        child: Text(flag, style: const TextStyle(fontSize: 22)),
      ),
      title: Row(
        children: [
          Text(
            name,
            style: GoogleFonts.poppins(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isAvailable
                  ? AppColors.textPrimary
                  : AppColors.textSecondary.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(width: 8),
          if (!isAvailable)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
              ),
              child: Text(
                "Bientôt",
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.amber.shade800,
                ),
              ),
            ),
        ],
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.poppins(
          fontSize: 12,
          color: AppColors.textSecondary,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 24)
          : (!isAvailable
              ? Icon(
                  Icons.lock_clock_outlined,
                  color: AppColors.textHint,
                  size: 20,
                )
              : null),
      onTap: () {
        if (!isAvailable) {
          AppNotifications.showPremiumDialog(
            context,
            title: "Langue non disponible",
            message:
                "La langue $name ($subtitle) n'est pas encore disponible pour le moment. L'application est actuellement optimisée en Français.",
            confirmText: "Compris",
            isSuccess: false,
          );
          return;
        }

        setState(() => _selectedLang = code);
        _setLang(code);
        AppNotifications.showSnackBar(
          context,
          message: "Langue définie sur $name.",
          isSuccess: true,
        );
      },
    );
  }
}
