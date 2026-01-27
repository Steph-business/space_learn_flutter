import 'package:flutter/material.dart';

import '../../../themes/app_colors.dart';

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
          "Préférences de lecture",
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Titre principal
            const Text(
              "Préférences de lecture",
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
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
            _buildSectionTitle("Thème"),
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
                    onPressed: () {
                      // Sauvegarder les préférences
                      _savePreferences();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "Sauvegarder",
                      style: TextStyle(
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
                    onPressed: () {
                      // Restaurer les valeurs par défaut
                      _resetToDefaults();
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "Par défaut",
                      style: TextStyle(
                        color: AppColors.primary,
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _nightMode ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
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
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _nightMode ? Colors.white : AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "Ceci est un exemple de texte pour prévisualiser vos préférences de lecture. La police, la taille et le thème choisis s'appliqueront à tous vos livres.",
            style: TextStyle(
              fontFamily: _selectedFont,
              fontSize: _fontSize,
              color: _nightMode ? Colors.white70 : Colors.black87,
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
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildFontSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: DropdownButton<String>(
        value: _selectedFont,
        isExpanded: true,
        underline: const SizedBox(),
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
    );
  }

  Widget _buildFontSizeSlider() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Taille: ${_fontSize.toInt()}",
              style: const TextStyle(fontWeight: FontWeight.w600),
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
    return Wrap(
      spacing: 8,
      children: _themes.map((theme) {
        return ChoiceChip(
          label: Text(theme),
          selected: _theme == theme,
          selectedColor: AppColors.primary.withOpacity(0.2),
          checkmarkColor: AppColors.primary,
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
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SwitchListTile(
        title: const Text("Activer le mode nuit"),
        subtitle: const Text("Texte blanc sur fond sombre"),
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
    // Logique de sauvegarde des préférences
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Préférences de lecture sauvegardées !'),
        backgroundColor: Colors.green,
      ),
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
