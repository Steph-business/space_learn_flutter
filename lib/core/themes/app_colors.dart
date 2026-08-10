import 'package:flutter/material.dart';

/// Palette de couleurs centralisée pour SpaceLearn.
/// Toutes les pages doivent référencer ces constantes au lieu de
/// définir des couleurs en dur.
///
/// `isDark` est volontairement un état global : la quasi-totalité des écrans
/// lit les couleurs via ces getters, sans passer par `Theme.of(context)`.
/// Il est resynchronisé sur le thème réellement actif à chaque construction de
/// `MaterialApp` (cf. `main.dart`) — ne l'affectez nulle part ailleurs, sous
/// peine de voir une partie de l'interface se désynchroniser de l'autre.
class AppColors {
  AppColors._(); // empêche l'instanciation

  /// Clair par défaut : c'est le thème par défaut de l'application, et cela
  /// garantit que la toute première frame (rendue avant la lecture asynchrone
  /// des préférences) est déjà dans la bonne palette.
  static bool isDark = false;

  // ───────────────────────── Backgrounds ─────────────────────────
  /// Valeurs absolues des fonds, indépendantes de [isDark]. Elles servent à
  /// construire les deux ThemeData de MaterialApp, qui doivent chacun décrire
  /// leur propre palette et non celle du mode actif.
  static const Color scaffoldLight = Color(0xFFFFFFFF);
  static const Color scaffoldDark = Color(0xFF000000);
  static const Color cardLight = Color(0xFFF8F9FA);
  static const Color cardDark = Color(0xFF121212);
  static const Color textOnLight = Color(0xFF000000);
  static const Color textOnDark = Color(0xFFFFFFFF);

  /// Fond principal du Scaffold
  static Color get scaffoldBackground => isDark ? scaffoldDark : scaffoldLight;

  /// Fond des cartes, conteneurs, champs de saisie
  static Color get cardBackground => isDark ? cardDark : cardLight;

  /// Fond alternatif (plus clair que le scaffold)
  static Color get surfaceVariant =>
      isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF1F3F5);

  /// Fond alternatif très sombre
  static Color get darkSurface =>
      isDark ? const Color(0xFF0A0A0A) : const Color(0xFFE9ECEF);

  // ───────────────────────── Accents / Primaires ─────────────────
  /// Couleur primaire d'accent (orange) — boutons, liens, icônes actives
  static const Color primary = Color(0xFFFFB156);

  /// Texte et icônes posés sur un aplat d'accent (bouton orange, badge coloré).
  /// Reste identique dans les deux thèmes : c'est le fond qui est coloré, pas
  /// la surface du thème. À utiliser à la place d'un `Colors.white` en dur.
  static const Color onAccent = Color(0xFF1A1A1A);

  /// L'accent **posé sur une surface du thème** : texte de lien, icône active,
  /// prix, libellé de bouton plat.
  ///
  /// [primary] est un orange clair. C'est excellent en aplat, mais illisible en
  /// encre sur fond clair — 1,80:1 sur blanc, là où le seuil est de 4,5:1. Ce
  /// jeton reprend donc l'orange de la marque en sombre, et sa déclinaison
  /// foncée en clair (5,02:1 sur blanc, 4,76:1 sur une carte).
  ///
  /// Règle : un accent qui **porte** du texte, c'est [primary] + [onAccent] ;
  /// un accent qui **est** du texte, c'est [accentInk].
  static Color get accentInk => isDark ? primary : amberDark;

  // ───────────────────────── Sélecteurs segmentés ────────────────
  /// Piste d'un sélecteur segmenté (le rail derrière la pastille active).
  static Color get segmentTrack =>
      isDark ? surfaceVariant : const Color(0xFFE9ECEF);

  /// Pastille active d'un sélecteur segmenté.
  static Color get segmentThumb =>
      isDark ? const Color(0xFF2A2A2A) : scaffoldLight;

  /// Libellé du segment actif — doit contraster avec [segmentThumb].
  static Color get segmentLabelActive => textPrimary;

  /// Libellé d'un segment inactif.
  static Color get segmentLabelInactive => textHint;

  /// Variante plus claire du primaire — hover, highlights
  static const Color primaryLight = Color(0xFFFFC37D);

  /// Variante plus sombre du primaire
  static const Color primaryDark = Color(0xFFE09841);

  // ───────────────────────── Secondaires ─────────────────────────
  /// Couleur secondaire (orange clair) — badges, accents secondaires
  static const Color secondary = Color(0xFFFFC37D);

  /// Variante de secondaire (orange écrivain)
  static const Color secondaryVariant = Color(0xFFE09841);

  // ───────────────────────── Sémantiques ─────────────────────────
  /// Succès / validation
  static const Color success = Color(0xFF10B981);

  /// Erreur / suppression
  static const Color error = Color(0xFFEF4444);

  /// Avertissement
  static const Color warning = Color(0xFFF59E0B);

  /// Orange — prix, infos chaudes
  static const Color orange = Color(0xFFD97706);

  /// Couleur orange foncée
  static const Color orangeDark = Color(0xFF92400E);

  /// Rose
  static const Color pink = Color(0xFFF472B6);

  /// Rouge clair (alerte douce)
  static const Color redLight = Color(0xFFF87171);

  // ───────────────────────── Indigo / Violet ─────────────────────
  /// Indigo principal
  static const Color indigo = Color(0xFF6366F1);

  /// Indigo clair
  static const Color indigoLight = Color(0xFF818CF8);

  /// Violet accent
  static const Color purple = Color(0xFF6A5AE0);

  /// Indigo foncé
  static const Color indigoDark = Color(0xFF4338CA);

  // ───────────────────────── Slate / Gris ────────────────────────
  /// Gris ardoise — sous-titres, dégradés
  static const Color slate = Color(0xFF475569);

  /// Gris ardoise clair — textes secondaires
  static const Color slateLight = Color(0xFF94A3B8);

  // ───────────────────────── Textes ──────────────────────────────
  /// Texte principal
  static Color get textPrimary => isDark ? textOnDark : textOnLight;

  /// Texte secondaire
  static Color get textSecondary =>
      isDark ? const Color(0xFFAAAAAA) : const Color(0xFF555555);

  /// Texte désactivé / placeholder
  static Color get textHint =>
      isDark ? const Color(0xFF777777) : const Color(0xFF888888);

  /// Texte sur fond sombre - gris clair
  static Color get textMuted =>
      isDark ? const Color(0xFF909097) : const Color(0xFF94A3B8);

  // ───────────────────────── Bordures ────────────────────────────
  /// Bordure subtile
  static Color get border =>
      isDark ? const Color(0xFF45464D) : const Color(0xFFE2E8F0);

  /// Bordure très subtile (blanc 5%)
  static Color get borderLight =>
      isDark ? const Color(0x0DFFFFFF) : const Color(0x0F000000);

  // ───────────────────────── Spécifiques ─────────────────────────
  /// Orange pour badge "Rejoindre" (fond)
  static const Color joinBadgeBg = Color(0xFFFFEDD5);

  /// Orange pour badge "Rejoindre" (texte)
  static const Color joinBadgeText = Color(0xFF9A3412);

  /// Étoiles / notes
  static const Color starColor = Colors.amber;

  // ───────────────────────── Violets supplémentaires ──────────────
  /// Violet vif
  static const Color violet = Color(0xFF8B5CF6);

  /// Violet foncé
  static const Color violetDark = Color(0xFF7C3AED);

  /// Violet pastel
  static const Color violetLight = Color(0xFFC084FC);

  /// Indigo profond
  static const Color indigoDeep = Color(0xFF4F46E5);

  /// Indigo très foncé
  static const Color indigoVeryDark = Color(0xFF1E1B4B);

  /// Rose vif
  static const Color pinkVivid = Color(0xFFEC4899);

  /// Rose foncé
  static const Color pinkDark = Color(0xFFDB2777);

  /// Rose très foncé
  static const Color pinkDeepDark = Color(0xFF9D174D);

  // ───────────────────────── Lecture / Reading ───────────────────
  /// Marron fond de lecture (sépia)
  static const Color readingBrown = Color(0xFF4A3728);

  /// Marron lecture foncé
  static const Color readingBrownDark = Color(0xFF5B4636);

  /// Crème / Parchemin
  static const Color parchment = Color(0xFFF4ECD8);

  /// Crème clair
  static const Color parchmentLight = Color(0xFFFDF7E2);

  /// Fond très sombre lecture
  static const Color readingDark = Color(0xFF121212);

  // ───────────────────────── Pastels / Fonds clairs ─────────────
  /// Gris très clair (fond alternatif)
  static const Color lightSurface = Color(0xFFF1F5F9);

  /// Gris quasi-blanc
  static const Color lightSurfaceAlt = Color(0xFFF8FAFC);

  /// Gris surface iOS
  static const Color iosSurface = Color(0xFFF2F2F7);

  /// Gris ardoise clair (bordures)
  static const Color slateBorder = Color(0xFFCBD5E1);

  // ───────────────────────── Jaune ──────────────────────────────
  /// Jaune vif
  static const Color yellow = Color(0xFFFACC15);

  /// Jaune doré
  static const Color yellowGold = Color(0xFFFBBF24);

  /// Jaune pastel
  static const Color yellowLight = Color(0xFFFDE68A);

  /// Jaune fond
  static const Color yellowBg = Color(0xFFFEF3C7);

  // ───────────────────────── Verts foncés ───────────────────────
  /// Vert forêt
  static const Color greenDark = Color(0xFF166534);

  /// Vert émeraude foncé
  static const Color greenDeep = Color(0xFF065F46);

  /// Vert fond pastel
  static const Color greenLightBg = Color(0xFFDCFCE7);

  /// Teal foncé
  static const Color tealDark = Color(0xFF0F766E);

  // ───────────────────────── Oranges supplémentaires ──────────────
  /// Orange royal
  static const Color blueRoyal = Color(0xFFD97706);

  /// Orange foncé
  static const Color blueSkyDark = Color(0xFFB45309);

  /// Orange ambre foncé
  static const Color amberDark = Color(0xFFB45309);

  // ───────────────────────── Dégradés (Dépréciés - Remplacés par unies) ────────────────────────────
  /// Dégradé d'en-tête (haut de page) - UTILISER scaffoldBackground à la place
  static List<Color> get headerGradient => [
    scaffoldBackground,
    scaffoldBackground,
  ];

  /// Dégradé d'en-tête simplifié (2 couleurs) - UTILISER scaffoldBackground à la place
  static List<Color> get headerGradientSimple => [
    scaffoldBackground,
    scaffoldBackground,
  ];

  /// Dégradé de card notification - UTILISER cardBackground à la place
  static List<Color> get notificationCardGradient => [
    cardBackground,
    cardBackground,
  ];
}
