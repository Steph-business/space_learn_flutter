import 'package:flutter/material.dart';

/// Palette de couleurs centralisée pour SpaceLearn (thème sombre).
/// Toutes les pages doivent référencer ces constantes au lieu de
/// définir des couleurs en dur.
class AppColors {
  AppColors._(); // empêche l'instanciation

  // ───────────────────────── Backgrounds ─────────────────────────
  /// Fond principal du Scaffold
  static const Color scaffoldBackground = Color(0xFF111827);

  /// Fond des cartes, conteneurs, champs de saisie
  static const Color cardBackground = Color(0xFF1E293B);

  /// Fond alternatif (plus clair que le scaffold)
  static const Color surfaceVariant = Color(0xFF1F2937);

  /// Fond alternatif très sombre
  static const Color darkSurface = Color(0xFF111827);

  // ───────────────────────── Accents / Primaires ─────────────────
  /// Couleur primaire d'accent (cyan) — boutons, liens, icônes actives
  static const Color primary = Color(0xFF06B6D4);

  /// Variante plus claire du primaire — hover, highlights
  static const Color primaryLight = Color(0xFF22D3EE);

  /// Variante plus sombre du primaire
  static const Color primaryDark = Color(0xFF0891B2);

  // ───────────────────────── Secondaires ─────────────────────────
  /// Couleur secondaire (sky blue) — badges, accents secondaires
  static const Color secondary = Color(0xFF38BDF8);

  /// Variante de secondaire (sky / bleu écrivain)
  static const Color secondaryVariant = Color(0xFF0EA5E9);

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
  /// Texte principal (blanc)
  static const Color textPrimary = Colors.white;

  /// Texte secondaire (blanc 70%)
  static const Color textSecondary = Colors.white70;

  /// Texte désactivé / placeholder
  static const Color textHint = Color(0xFF9CA3AF);

  /// Texte sur fond sombre - gris clair
  static const Color textMuted = Color(0xFF6B7280);

  // ───────────────────────── Bordures ────────────────────────────
  /// Bordure subtile
  static const Color border = Color(0xFF334155);

  /// Bordure très subtile (blanc 5%)
  static const Color borderLight = Color(0x0DFFFFFF);

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

  // ───────────────────────── Bleus supplémentaires ──────────────
  /// Bleu royal
  static const Color blueRoyal = Color(0xFF2563EB);

  /// Bleu ciel foncé
  static const Color blueSkyDark = Color(0xFF0284C7);

  /// Orange ambre foncé
  static const Color amberDark = Color(0xFFB45309);

  // ───────────────────────── Dégradés ────────────────────────────
  /// Dégradé d'en-tête (haut de page)
  static const List<Color> headerGradient = [
    Color(0xFF475569),
    Color(0xFF1E293B),
    Color(0xFF0F172A),
  ];

  /// Dégradé d'en-tête simplifié (2 couleurs)
  static const List<Color> headerGradientSimple = [
    Color(0xFF475569),
    Color(0xFF0F172A),
  ];

  /// Dégradé de card notification
  static const List<Color> notificationCardGradient = [
    Color(0xFF1E293B),
    Color(0xFF0F172A),
  ];
}
