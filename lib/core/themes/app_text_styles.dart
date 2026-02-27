import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Styles de texte centralisés pour SpaceLearn.
/// Tous les styles utilisent Google Fonts Poppins par défaut.
class AppTextStyles {
  AppTextStyles._();

  // ───────────────────────── Titres ──────────────────────────────

  /// Titre principal de page — 24px bold blanc
  static TextStyle pageTitle = GoogleFonts.poppins(
    color: AppColors.textPrimary,
    fontSize: 24,
    fontWeight: FontWeight.bold,
  );

  /// Titre de section — 18px bold blanc
  static TextStyle sectionTitle = GoogleFonts.poppins(
    color: AppColors.textPrimary,
    fontSize: 18,
    fontWeight: FontWeight.bold,
  );

  /// Sous-titre — 16px semi-bold blanc
  static TextStyle subtitle = GoogleFonts.poppins(
    color: AppColors.textPrimary,
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );

  /// Titre de carte — 14px bold blanc
  static TextStyle cardTitle = GoogleFonts.poppins(
    color: AppColors.textPrimary,
    fontSize: 14,
    fontWeight: FontWeight.bold,
  );

  /// Titre petit — 13px bold blanc
  static TextStyle cardTitleSmall = GoogleFonts.poppins(
    color: AppColors.textPrimary,
    fontSize: 13,
    fontWeight: FontWeight.bold,
  );

  // ───────────────────────── Corps ───────────────────────────────

  /// Texte de corps principal — 14px normal blanc
  static TextStyle body = GoogleFonts.poppins(
    color: AppColors.textPrimary,
    fontSize: 14,
    fontWeight: FontWeight.normal,
  );

  /// Texte de corps secondaire — 13px normal blanc70
  static TextStyle bodySecondary = GoogleFonts.poppins(
    color: AppColors.textSecondary,
    fontSize: 13,
    fontWeight: FontWeight.normal,
  );

  /// Texte petit — 12px normal blanc70
  static TextStyle bodySmall = GoogleFonts.poppins(
    color: AppColors.textSecondary,
    fontSize: 12,
    fontWeight: FontWeight.normal,
  );

  /// Texte très petit — 11px medium blanc70
  static TextStyle caption = GoogleFonts.poppins(
    color: AppColors.textSecondary,
    fontSize: 11,
    fontWeight: FontWeight.w500,
  );

  /// Texte gris — 12px normal gris 400
  static TextStyle bodyMuted = GoogleFonts.poppins(
    color: AppColors.textHint,
    fontSize: 12,
    fontWeight: FontWeight.normal,
  );

  // ───────────────────────── Accents ─────────────────────────────

  /// Lien / texte accent — 13px normal primaire
  static TextStyle link = GoogleFonts.poppins(
    color: AppColors.primary,
    fontSize: 13,
    fontWeight: FontWeight.normal,
  );

  /// Lien gras — 13px semi-bold primaire
  static TextStyle linkBold = GoogleFonts.poppins(
    color: AppColors.primary,
    fontSize: 13,
    fontWeight: FontWeight.w600,
  );

  /// Prix — 13px bold secondary (sky blue)
  static TextStyle price = GoogleFonts.poppins(
    color: AppColors.secondary,
    fontSize: 13,
    fontWeight: FontWeight.bold,
  );

  // ───────────────────────── Boutons ─────────────────────────────

  /// Texte de bouton principal — 16px semi-bold blanc
  static TextStyle button = GoogleFonts.poppins(
    color: AppColors.textPrimary,
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );

  /// Petit bouton — 12px bold blanc
  static TextStyle buttonSmall = GoogleFonts.poppins(
    color: AppColors.textPrimary,
    fontSize: 12,
    fontWeight: FontWeight.bold,
  );

  /// Label de catégorie sélectionnée — 13px semi-bold blanc
  static TextStyle chipSelected = GoogleFonts.poppins(
    color: AppColors.textPrimary,
    fontSize: 13,
    fontWeight: FontWeight.w600,
  );

  /// Label de catégorie non sélectionnée — 13px normal gris clair
  static TextStyle chipUnselected = GoogleFonts.poppins(
    color: AppColors.slateLight,
    fontSize: 13,
    fontWeight: FontWeight.normal,
  );

  // ───────────────────────── Auth pages ──────────────────────────

  /// Titre grand pour pages d'authentification — 28px bold blanc
  static TextStyle authTitle = GoogleFonts.poppins(
    color: AppColors.textPrimary,
    fontSize: 28,
    fontWeight: FontWeight.bold,
  );

  /// Sous-titre auth — 15px normal blanc70
  static TextStyle authSubtitle = GoogleFonts.poppins(
    color: AppColors.textSecondary,
    fontSize: 15,
    fontWeight: FontWeight.normal,
  );

  /// Label de champ — 14px medium blanc
  static TextStyle fieldLabel = GoogleFonts.poppins(
    color: AppColors.textPrimary,
    fontSize: 14,
    fontWeight: FontWeight.w500,
  );

  /// Hint de champ — 14px normal gris
  static TextStyle fieldHint = GoogleFonts.poppins(
    color: AppColors.textHint,
    fontSize: 14,
    fontWeight: FontWeight.normal,
  );

  // ───────────────────────── Divers ──────────────────────────────

  /// Nom d'auteur — 12px medium blanc
  static TextStyle authorName = GoogleFonts.poppins(
    color: AppColors.textPrimary,
    fontSize: 12,
    fontWeight: FontWeight.w500,
  );

  /// Lettre d'avatar — 24px bold primary
  static TextStyle avatarLetter = GoogleFonts.poppins(
    color: AppColors.secondary,
    fontSize: 24,
    fontWeight: FontWeight.bold,
  );

  /// Citation italique — Lora 14px italic blanc
  static TextStyle quote = GoogleFonts.lora(
    color: AppColors.textPrimary,
    fontSize: 14,
    fontStyle: FontStyle.italic,
    fontWeight: FontWeight.w500,
    height: 1.3,
  );

  /// Notification titre — 14px bold blanc
  static TextStyle notificationTitle = GoogleFonts.poppins(
    color: AppColors.textPrimary,
    fontSize: 14,
    fontWeight: FontWeight.bold,
  );

  /// Statistique valeur — 18px bold blanc
  static TextStyle statValue = GoogleFonts.poppins(
    color: AppColors.textPrimary,
    fontSize: 18,
    fontWeight: FontWeight.bold,
  );

  /// Statistique label — 11px normal blanc70
  static TextStyle statLabel = GoogleFonts.poppins(
    color: AppColors.textSecondary,
    fontSize: 11,
    fontWeight: FontWeight.normal,
  );

  // ───────────────────────── Helpers ─────────────────────────────

  /// Applique une couleur différente à un style existant
  static TextStyle withColor(TextStyle style, Color color) =>
      style.copyWith(color: color);

  /// Applique une taille différente à un style existant
  static TextStyle withSize(TextStyle style, double size) =>
      style.copyWith(fontSize: size);
}
