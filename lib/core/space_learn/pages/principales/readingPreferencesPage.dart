import 'package:flutter/material.dart';
import 'package:space_learn_flutter/core/themes/app_dimensions.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:space_learn_flutter/core/themes/app_colors.dart';
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
  bool _isLoading = true;

  final List<String> _fonts = [
    'Roboto',
    'Open Sans',
    'Lato',
    'Poppins',
    'Inter',
  ];
  final List<String> _themes = ['Clair', 'Sombre', 'Automatique'];

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _selectedFont = prefs.getString('pref_reading_font') ?? 'Roboto';
        _fontSize = prefs.getDouble('pref_reading_font_size') ?? 16.0;
        _nightMode = prefs.getBool('pref_reading_night_mode') ?? false;
        _theme = prefs.getString('pref_reading_theme') ?? 'Automatique';
        _isLoading = false;
      });
    }
  }

  bool get _isEffectiveDark {
    if (_nightMode || _theme == 'Sombre') return true;
    if (_theme == 'Clair') return false;
    return Theme.of(context).brightness == Brightness.dark;
  }

  @override
  Widget build(BuildContext context) {
    // Cette page décide seule de sa luminosité : elle prévisualise le confort
    // de lecture, qui a son propre mode nuit, indépendant du thème de
    // l'application. Ce choix est légitime — la palette qui l'accompagnait ne
    // l'était pas : elle redéfinissait localement fond, carte, texte, texte
    // secondaire et bordure, soit un troisième thème invisible depuis
    // AppColors. Seule la *sélection* reste locale ; les valeurs viennent des
    // constantes absolues de la palette.
    final isDark = _isEffectiveDark;
    final bgColor = isDark ? AppColors.scaffoldDark : AppColors.scaffoldLight;
    final cardBgColor = isDark ? AppColors.cardDark : AppColors.cardLight;
    final textColor = isDark ? AppColors.textOnDark : AppColors.textOnLight;
    final secondaryTextColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    final borderColor = isDark
        ? AppColors.borderDark
        : AppColors.borderLightMode;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.accentInk),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          "Préférences de lecture",
          style: GoogleFonts.poppins(
            color: isDark ? Colors.white : AppColors.accentInk,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
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
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Aperçu du texte
                  _buildTextPreview(
                    isDark,
                    cardBgColor,
                    textColor,
                    secondaryTextColor,
                    borderColor,
                  ),
                  const SizedBox(height: 30),

                  // Section Police
                  _buildSectionTitle("Police"),
                  _buildFontSelector(
                    isDark,
                    cardBgColor,
                    textColor,
                    borderColor,
                  ),
                  const SizedBox(height: 20),

                  // Section Taille du texte
                  _buildSectionTitle("Taille du texte"),
                  _buildFontSizeSlider(isDark, textColor, secondaryTextColor),
                  const SizedBox(height: 20),

                  // Section Thème
                  _buildSectionTitle("Thème de lecture"),
                  _buildThemeSelector(isDark),
                  const SizedBox(height: 20),

                  // Section Mode nuit
                  _buildSectionTitle("Mode nuit"),
                  _buildNightModeToggle(
                    isDark,
                    cardBgColor,
                    textColor,
                    secondaryTextColor,
                    borderColor,
                  ),
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
                              borderRadius: BorderRadius.circular(
                                AppDimensions.radiusInner,
                              ),
                            ),
                          ),
                          child: Text(
                            "Sauvegarder",
                            style: GoogleFonts.poppins(
                              color: AppColors.onAccent,
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
                            side: BorderSide(
                              color: isDark
                                  ? Colors.white24
                                  : AppColors.accentInk,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppDimensions.radiusInner,
                              ),
                            ),
                          ),
                          child: Text(
                            "Par défaut",
                            style: GoogleFonts.poppins(
                              color: isDark
                                  ? AppColors.textOnDark
                                  : AppColors.amberDark,
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

  Widget _buildTextPreview(
    bool isDark,
    Color cardBg,
    Color textColor,
    Color subTextColor,
    Color borderColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(color: borderColor),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
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
              color: isDark ? Colors.white : AppColors.accentInk,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "Ceci est un exemple de texte pour prévisualiser vos préférences de lecture. La police, la taille et le thème choisis s'appliqueront à tous vos livres.",
            style: TextStyle(
              fontFamily: _selectedFont,
              fontSize: _fontSize,
              color: subTextColor,
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
          color: AppColors.accentInk,
        ),
      ),
    );
  }

  Widget _buildFontSelector(
    bool isDark,
    Color cardBg,
    Color textColor,
    Color borderColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(AppDimensions.radiusInner),
        border: Border.all(color: borderColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedFont,
          isExpanded: true,
          dropdownColor: cardBg,
          style: GoogleFonts.poppins(color: textColor, fontSize: 16),
          icon: Icon(Icons.arrow_drop_down, color: AppColors.accentInk),
          items: _fonts.map((font) {
            return DropdownMenuItem(
              value: font,
              child: Text(
                font,
                style: TextStyle(fontFamily: font, color: textColor),
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _selectedFont = value;
              });
            }
          },
        ),
      ),
    );
  }

  Widget _buildFontSizeSlider(
    bool isDark,
    Color textColor,
    Color subTextColor,
  ) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Taille: ${_fontSize.toInt()}",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
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
                  color: AppColors.accentInk,
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      if (_fontSize < 24) _fontSize += 2;
                    });
                  },
                  icon: const Icon(Icons.add),
                  color: AppColors.accentInk,
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
          inactiveColor: isDark ? Colors.white24 : Colors.black12,
          onChanged: (value) {
            setState(() {
              _fontSize = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildThemeSelector(bool isDark) {
    return Wrap(
      spacing: 8,
      children: _themes.map((theme) {
        final isSelected = _theme == theme;
        return ChoiceChip(
          label: Text(theme),
          selected: isSelected,
          selectedColor: AppColors.primary.withValues(alpha: 0.2),
          checkmarkColor: AppColors.primary,
          backgroundColor: isDark
              ? AppColors.cardDark
              : AppColors.surfaceVariantLight,
          labelStyle: GoogleFonts.poppins(
            color: isSelected
                ? (isDark ? AppColors.accentInk : AppColors.amberDark)
                : (isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight),
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

  Widget _buildNightModeToggle(
    bool isDark,
    Color cardBg,
    Color textColor,
    Color subTextColor,
    Color borderColor,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(AppDimensions.radiusInner),
        border: Border.all(color: borderColor),
      ),
      child: SwitchListTile(
        title: Text(
          "Activer le mode nuit",
          style: GoogleFonts.poppins(
            color: textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          "Texte blanc sur fond sombre",
          style: GoogleFonts.poppins(color: subTextColor),
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

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pref_reading_font', _selectedFont);
    await prefs.setDouble('pref_reading_font_size', _fontSize);
    await prefs.setBool('pref_reading_night_mode', _nightMode);
    await prefs.setString('pref_reading_theme', _theme);

    if (mounted) {
      AppNotifications.showSnackBar(
        context,
        message: 'Préférences de lecture sauvegardées !',
        isSuccess: true,
      );
    }
  }

  void _resetToDefaults() {
    setState(() {
      _selectedFont = 'Roboto';
      _fontSize = 16.0;
      _nightMode = false;
      _theme = 'Automatique';
    });
    _savePreferences();
  }
}
