/// Constantes de mise en page partagées par toute l'application.
///
/// Les écrans définissaient chacun leurs rayons et leurs marges (16, 20, 12,
/// 10…), ce qui donnait des cartes visiblement différentes sur un même écran.
/// Toute nouvelle surface doit piocher ici plutôt que réintroduire une valeur.
class AppDimensions {
  AppDimensions._();

  // ───────────────────────── Rayons ─────────────────────────
  //
  // Cinq valeurs, une par échelle d'élément. Le code en comptait quatorze
  // écrites en dur (2, 3, 4, 6, 8, 10, 12, 14, 15, 16, 20, 24, 28, 30), ce qui
  // donnait des arrondis différents sur deux cartes voisines du même écran.
  //
  //   0 – 4   → [radiusXs]     traits, jauges, minuscules pastilles
  //   6 – 10  → [radiusSmall]  badges, puces, sélecteurs
  //   12 – 15 → [radiusInner]  champs, boutons, éléments internes
  //   16 – 20 → [radiusCard]   cartes, dialogues, feuilles
  //   24 +    → [radiusPill]   avatars, gélules, boutons flottants

  /// Rayon des cartes et grandes surfaces.
  static const double radiusCard = 16;

  /// Rayon des éléments internes (pastilles, champs, puces).
  static const double radiusInner = 12;

  /// Rayon des petits éléments (badges, sélecteurs).
  static const double radiusSmall = 8;

  /// Rayon minimal — barres de progression, filets, indicateurs.
  static const double radiusXs = 4;

  /// Rayon des formes en gélule — avatars, boutons flottants, onglets ronds.
  static const double radiusPill = 24;

  // ───────────────────────── Espacements ────────────────────
  static const double spaceXs = 4;
  static const double spaceSm = 8;
  static const double spaceMd = 12;
  static const double spaceLg = 16;
  static const double spaceXl = 24;

  /// Marge intérieure standard d'une carte.
  static const double cardPadding = 16;

  /// Marge horizontale d'un écran.
  static const double screenPadding = 16;

  /// Écart vertical entre deux sections d'un écran.
  static const double sectionGap = 20;
}
