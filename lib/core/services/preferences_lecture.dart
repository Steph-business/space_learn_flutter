import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:space_learn_flutter/core/themes/app_colors.dart';

/// Réglages de confort de lecture, en un seul endroit.
///
/// Ils étaient dédoublés. La page « Préférences de lecture » écrivait
/// `pref_reading_font`, `pref_reading_font_size`, `pref_reading_night_mode` et
/// `pref_reading_theme` — quatre clés que **rien** dans l'application ne lisait.
/// On choisissait une police, une taille, un thème, on appuyait sur
/// « Sauvegarder », et aucun de ces choix n'atteignait le lecteur, qui lisait
/// de son côté `reading_bg_color`, `reading_brightness`, `reading_zoom_level`
/// et `reading_is_horizontal`.
///
/// Une seule série de clés désormais, décrite ici. La page de préférences et la
/// feuille de réglages du lecteur écrivent les mêmes.
class PreferencesLecture {
  PreferencesLecture._();

  static const cleLuminosite = 'reading_brightness';
  static const cleFondDePage = 'reading_bg_color';
  static const cleAgrandissement = 'reading_zoom_level';
  static const cleSensHorizontal = 'reading_is_horizontal';

  /// Fonds de page proposés, dans l'ordre d'affichage.
  ///
  /// La liste vit ici plutôt que dans chaque écran : elle était recopiée, et
  /// « Original » valait blanc pur d'un côté, parchemin clair de l'autre — deux
  /// vignettes qui prétendaient montrer le même fond.
  static const List<({String nom, Color fond, Color texte})> fondsDePage = [
    (
      nom: 'Original',
      fond: AppColors.parchmentLight,
      texte: AppColors.textOnLight,
    ),
    (nom: 'Nuit', fond: AppColors.readingDark, texte: AppColors.textOnDark),
    (
      nom: 'Sépia',
      fond: AppColors.parchment,
      texte: AppColors.readingBrownDark,
    ),
  ];

  static Future<Reglages> charger() async {
    final prefs = await SharedPreferences.getInstance();
    final fond = prefs.getInt(cleFondDePage);
    final zoom = prefs.getDouble(cleAgrandissement) ?? 1.0;

    return Reglages(
      luminosite: prefs.getDouble(cleLuminosite) ?? 1.0,
      fondDePage: fond != null ? Color(fond) : AppColors.parchmentLight,
      // Un zoom nul ou négatif rendrait la page invisible.
      agrandissement: zoom > 0 ? zoom : 1.0,
      sensHorizontal: prefs.getBool(cleSensHorizontal) ?? false,
    );
  }

  static Future<void> enregistrer(Reglages r) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(cleLuminosite, r.luminosite);
    await prefs.setInt(cleFondDePage, r.fondDePage.toARGB32());
    await prefs.setDouble(cleAgrandissement, r.agrandissement);
    await prefs.setBool(cleSensHorizontal, r.sensHorizontal);
  }
}

/// Les quatre réglages, tels que le lecteur les applique.
class Reglages {
  final double luminosite;
  final Color fondDePage;
  final double agrandissement;
  final bool sensHorizontal;

  const Reglages({
    required this.luminosite,
    required this.fondDePage,
    required this.agrandissement,
    required this.sensHorizontal,
  });

  Reglages copier({
    double? luminosite,
    Color? fondDePage,
    double? agrandissement,
    bool? sensHorizontal,
  }) {
    return Reglages(
      luminosite: luminosite ?? this.luminosite,
      fondDePage: fondDePage ?? this.fondDePage,
      agrandissement: agrandissement ?? this.agrandissement,
      sensHorizontal: sensHorizontal ?? this.sensHorizontal,
    );
  }

  /// Valeurs par défaut, pour le bouton « Réinitialiser ».
  static const Reglages defaut = Reglages(
    luminosite: 1.0,
    fondDePage: AppColors.parchmentLight,
    agrandissement: 1.0,
    sensHorizontal: false,
  );
}
