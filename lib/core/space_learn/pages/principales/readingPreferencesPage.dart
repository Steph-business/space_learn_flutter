import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../themes/app_colors.dart';
import 'package:space_learn_flutter/core/utils/app_notifications.dart';

class ReadingPreferencesPage extends StatefulWidget {
  const ReadingPreferencesPage({super.key});

  @override
  State<ReadingPreferencesPage> createState() => _ReadingPreferencesPageState();
}

class _ReadingPreferencesPageState extends State<ReadingPreferencesPage> {
  String _selectedFont = 'Roboto';
  double _fontSize = 16.0;
  bool _nightMode = false;
  String _theme = 'Automatique';

  final List<String> _fonts = [
    'Roboto',
    'Open Sans',
    'Lato',
    'Poppins',
    'Inter',
  ];
  final List<String> _themes = ['Clair', 'Sombre', 'Automatique'];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.scaffoldBackground : const Color.fromARGB(255, 250, 249, 246),
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.scaffoldBackground : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          "Préférences de lecture",
          style: GoogleFonts.poppins(
            color: isDark ? Colors.white : AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Titre principal
            Text(
              "Préférences de lecture",
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 20),

            // Aperçu du texte
            _buildTextPreview(),
            const SizedBox(height: 30),

            // Section Police
            _buildSectionTitle("Police"),
            _buildFontSelector(),
            const SizedBox(height: 20),

            // Section Taille du texte
            _buildSectionTitle("Taille du texte"),
            _buildFontSizeSlider(),
            const SizedBox(height: 20),

            // Section Thème
            _buildSectionTitle("Thème de lecture"),
            _buildThemeSelector(),
            const SizedBox(height: 20),

            // Section Mode nuit
            _buildSectionTitle("Mode nuit"),
            _buildNightModeToggle(),
            const SizedBox(height: 30),

            // Boutons d'action
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _savePreferences,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      "Sauvegarder",
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _resetToDefaults,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: isDark ? Colors.white30 : AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      "Par défaut",
                      style: GoogleFonts.poppins(
                        color: isDark ? Colors.white70 : AppColors.primary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
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
  }

  Widget _buildTextPreview() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPreviewDark = _nightMode || (isDark && _theme == 'Automatique') || _theme == 'Sombre';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isPreviewDark ? AppColors.cardBackground : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isPreviewDark ? Colors.white10 : Colors.black12),
        boxShadow: [
          BoxShadow(
            color: isPreviewDark ? Colors.black.withOpacity(0.3) : Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Aperçu du texte",
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isPreviewDark ? Colors.white : AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "Ceci est un exemple de texte pour prévisualiser vos préférences de lecture. La police, la taille et le thème choisis s'appliqueront à tous vos livres.",
            style: TextStyle(
              fontFamily: _selectedFont,
              fontSize: _fontSize,
              color: isPreviewDark ? Colors.white70 : Colors.black87,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildFontSelector() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardBackground : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white24 : Colors.grey[300]!),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedFont,
          isExpanded: true,
          dropdownColor: isDark ? AppColors.cardBackground : Colors.white,
          style: GoogleFonts.poppins(color: isDark ? Colors.white : Colors.black87, fontSize: 16),
          icon: const Icon(Icons.arrow_drop_down, color: AppColors.primary),
          items: _fonts.map((font) {
            return DropdownMenuItem(
              value: font,
              child: Text(font, style: TextStyle(fontFamily: font)),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedFont = value!;
            });
          },
        ),
      ),
    );
  }

  Widget _buildFontSizeSlider() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Taille: ${_fontSize.toInt()}",
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87),
            ),
            Row(
              children: [
                IconButton(
                  onPressed: () {
                    setState(() {
                      if (_fontSize > 12) _fontSize -= 2;
                    });
                  },
                  icon: const Icon(Icons.remove),
                  color: AppColors.primary,
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      if (_fontSize < 24) _fontSize += 2;
                    });
                  },
                  icon: const Icon(Icons.add),
                  color: AppColors.primary,
                ),
              ],
            ),
          ],
        ),
        Slider(
          value: _fontSize,
          min: 12,
          max: 24,
          divisions: 6,
          activeColor: AppColors.primary,
          inactiveColor: isDark ? Colors.white24 : Colors.grey[300],
          onChanged: (value) {
            setState(() {
              _fontSize = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildThemeSelector() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Wrap(
      spacing: 8,
      children: _themes.map((theme) {
        final isSelected = _theme == theme;
        return ChoiceChip(
          label: Text(theme),
          selected: isSelected,
          selectedColor: AppColors.primary.withOpacity(0.2),
          checkmarkColor: AppColors.primary,
          backgroundColor: isDark ? AppColors.cardBackground : Colors.grey[200],
          labelStyle: GoogleFonts.poppins(
            color: isSelected
                ? AppColors.primary
                : (isDark ? Colors.white70 : Colors.black87),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
          onSelected: (selected) {
            if (selected) {
              setState(() {
                _theme = theme;
                _nightMode = theme == 'Sombre';
              });
            }
          },
        );
      }).toList(),
    );
  }

  Widget _buildNightModeToggle() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      color: isDark ? AppColors.cardBackground : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SwitchListTile(
        title: Text(
          "Activer le mode nuit",
          style: GoogleFonts.poppins(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          "Texte blanc sur fond sombre",
          style: GoogleFonts.poppins(color: isDark ? Colors.white70 : Colors.grey[600]),
        ),
        value: _nightMode,
        activeColor: AppColors.primary,
        onChanged: (value) {
          setState(() {
            _nightMode = value;
            _theme = value ? 'Sombre' : 'Clair';
          });
        },
      ),
    );
  }

  void _savePreferences() {
    AppNotifications.showSnackBar(
      context,
      message: 'Préférences de lecture sauvegardées !',
      isSuccess: true,
    );
  }

  void _resetToDefaults() {
    setState(() {
      _selectedFont = 'Roboto';
      _fontSize = 16.0;
      _nightMode = false;
      _theme = 'Automatique';
    });
  }
}
