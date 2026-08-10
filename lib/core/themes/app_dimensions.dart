/// Constantes de mise en page partagées par toute l'application.
///
/// Les écrans définissaient chacun leurs rayons et leurs marges (16, 20, 12,
/// 10…), ce qui donnait des cartes visiblement différentes sur un même écran.
/// Toute nouvelle surface doit piocher ici plutôt que réintroduire une valeur.
class AppDimensions {
  AppDimensions._();

  // ───────────────────────── Rayons ─────────────────────────
  /// Rayon des cartes et grandes surfaces.
  static const double radiusCard = 16;

  /// Rayon des éléments internes (pastilles, champs, puces).
  static const double radiusInner = 12;

  /// Rayon des petits éléments (badges, sélecteurs).
  static const double radiusSmall = 8;

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
