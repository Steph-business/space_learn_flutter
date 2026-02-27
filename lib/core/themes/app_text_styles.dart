import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Styles de texte centralisés pour SpaceLearn.
/// Tous les styles utilisent Google Fonts Poppins par défaut.
class AppTextStyles {
  AppTextStyles._();

  // ───────────────────────── Titres ──────────────────────────────

  /// Titre héro — 28px extra-bold blanc
  static TextStyle heroTitle = GoogleFonts.poppins(
    color: AppColors.textPrimary,
    fontSize: 28,
    fontWeight: FontWeight.w800,
  );

  /// Titre principal de page — 24px bold blanc
  static TextStyle pageTitle = GoogleFonts.poppins(
    color: AppColors.textPrimary,
    fontSize: 24,
    fontWeight: FontWeight.bold,
  );

  /// Titre héro 22px — 22px extra-bold blanc
  static TextStyle heroTitle22 = GoogleFonts.poppins(
    color: AppColors.textPrimary,
    fontSize: 22,
    fontWeight: FontWeight.w800,
  );

  /// Titre de section — 18px bold blanc
  static TextStyle sectionTitle = GoogleFonts.poppins(
    color: AppColors.textPrimary,
    fontSize: 18,
    fontWeight: FontWeight.bold,
  );

  /// Titre de section semi-bold — 18px w600 blanc
  static TextStyle sectionTitleSemiBold = GoogleFonts.poppins(
    color: AppColors.textPrimary,
    fontSize: 18,
    fontWeight: FontWeight.w600,
  );

  /// Titre de section w700 — 18px w700 blanc
  static TextStyle sectionTitleW700 = GoogleFonts.poppins(
    color: AppColors.textPrimary,
    fontSize: 18,
    fontWeight: FontWeight.w700,
  );

  /// Sous-titre — 16px semi-bold blanc
  static TextStyle subtitle = GoogleFonts.poppins(
    color: AppColors.textPrimary,
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );

  /// Sous-titre bold — 16px bold blanc
  static TextStyle subtitleBold = GoogleFonts.poppins(
    color: AppColors.textPrimary,
    fontSize: 16,
    fontWeight: FontWeight.bold,
  );

  /// Sous-titre 15px — 15px w500 blanc
  static TextStyle subtitle15 = GoogleFonts.poppins(
    color: AppColors.textPrimary,
    fontSize: 15,
    fontWeight: FontWeight.w500,
  );

  /// Titre de carte — 14px bold blanc
  static TextStyle cardTitle = GoogleFonts.poppins(
    color: AppColors.textPrimary,
    fontSize: 14,
    fontWeight: FontWeight.bold,
  );

  /// Titre de carte w700 — 14px w700 blanc
  static TextStyle cardTitleW700 = GoogleFonts.poppins(
    color: AppColors.textPrimary,
    fontSize: 14,
    fontWeight: FontWeight.w700,
  );

  /// Titre de carte w500 — 14px w500 blanc
  static TextStyle cardTitleMedium = GoogleFonts.poppins(
    color: AppColors.textPrimary,
    fontSize: 14,
    fontWeight: FontWeight.w500,
  );

  /// Titre petit — 13px bold blanc
  static TextStyle cardTitleSmall = GoogleFonts.poppins(
    color: AppColors.textPrimary,
    fontSize: 13,
    fontWeight: FontWeight.bold,
  );

  /// Titre 13px semi-bold — 13px w600 blanc
  static TextStyle cardTitleSmallSemiBold = GoogleFonts.poppins(
    color: AppColors.textPrimary,
    fontSize: 13,
    fontWeight: FontWeight.w600,
  );

  /// Titre 12px bold — 12px bold blanc
  static TextStyle cardTitle12Bold = GoogleFonts.poppins(
    color: AppColors.textPrimary,
    fontSize: 12,
    fontWeight: FontWeight.bold,
  );

  /// Titre 12px w700 — 12px w700 blanc
  static TextStyle cardTitle12W700 = GoogleFonts.poppins(
    color: AppColors.textPrimary,
    fontSize: 12,
    fontWeight: FontWeight.w700,
  );

  /// Titre 12px semi-bold — 12px w600 blanc
  static TextStyle cardTitle12SemiBold = GoogleFonts.poppins(
    color: AppColors.textPrimary,
    fontSize: 12,
    fontWeight: FontWeight.w600,
  );

  // ───────────────────────── Corps ───────────────────────────────

  /// Texte de corps principal — 14px normal blanc
  static TextStyle body = GoogleFonts.poppins(
    color: AppColors.textPrimary,
    fontSize: 14,
    fontWeight: FontWeight.normal,
  );

  /// Texte 15px normal blanc
  static TextStyle body15 = GoogleFonts.poppins(
    color: AppColors.textPrimary,
    fontSize: 15,
    fontWeight: FontWeight.normal,
  );

  /// Corps 13px normal blanc
  static TextStyle body13 = GoogleFonts.poppins(
    color: AppColors.textPrimary,
    fontSize: 13,
    fontWeight: FontWeight.normal,
  );

  /// Corps 12px normal blanc
  static TextStyle body12 = GoogleFonts.poppins(
    color: AppColors.textPrimary,
    fontSize: 12,
    fontWeight: FontWeight.normal,
  );

  /// Corps 11px normal blanc
  static TextStyle body11 = GoogleFonts.poppins(
    color: AppColors.textPrimary,
    fontSize: 11,
    fontWeight: FontWeight.normal,
  );

  /// Corps 10px normal blanc
  static TextStyle body10 = GoogleFonts.poppins(
    color: AppColors.textPrimary,
    fontSize: 10,
    fontWeight: FontWeight.normal,
  );

  /// Texte de corps secondaire — 13px normal blanc70
  static TextStyle bodySecondary = GoogleFonts.poppins(
    color: AppColors.textSecondary,
    fontSize: 13,
    fontWeight: FontWeight.normal,
  );

  /// Texte secondaire 14px — 14px normal blanc70
  static TextStyle bodySecondary14 = GoogleFonts.poppins(
    color: AppColors.textSecondary,
    fontSize: 14,
    fontWeight: FontWeight.normal,
  );

  /// Texte petit — 12px normal blanc70
  static TextStyle bodySmall = GoogleFonts.poppins(
    color: AppColors.textSecondary,
    fontSize: 12,
    fontWeight: FontWeight.normal,
  );

  /// Texte petit 11px — 11px normal blanc70
  static TextStyle bodySmall11 = GoogleFonts.poppins(
    color: AppColors.textSecondary,
    fontSize: 11,
    fontWeight: FontWeight.normal,
  );

  /// Texte petit 10px — 10px normal blanc70
  static TextStyle bodySmall10 = GoogleFonts.poppins(
    color: AppColors.textSecondary,
    fontSize: 10,
    fontWeight: FontWeight.normal,
  );

  /// Texte très petit — 11px medium blanc70
  static TextStyle caption = GoogleFonts.poppins(
    color: AppColors.textSecondary,
    fontSize: 11,
    fontWeight: FontWeight.w500,
  );

  /// Texte gris — 12px normal gris
  static TextStyle bodyMuted = GoogleFonts.poppins(
    color: AppColors.textHint,
    fontSize: 12,
    fontWeight: FontWeight.normal,
  );

  /// Texte blanc54 — 16 normal
  static TextStyle bodyFaded16 = GoogleFonts.poppins(
    color: Colors.white54,
    fontSize: 16,
    fontWeight: FontWeight.normal,
  );

  /// Texte blanc54 — 12 normal
  static TextStyle bodyFaded12 = GoogleFonts.poppins(
    color: Colors.white54,
    fontSize: 12,
    fontWeight: FontWeight.normal,
  );

  /// Texte blanc54 — 13 normal
  static TextStyle bodyFaded13 = GoogleFonts.poppins(
    color: Colors.white54,
    fontSize: 13,
    fontWeight: FontWeight.normal,
  );

  // ───────────────────────── Gris ────────────────────────────────

  /// Gris 400 — 12px normal
  static TextStyle grey12 = GoogleFonts.poppins(
    color: Colors.grey[400],
    fontSize: 12,
    fontWeight: FontWeight.normal,
  );

  /// Gris 400 — 11px normal
  static TextStyle grey11 = GoogleFonts.poppins(
    color: Colors.grey[400],
    fontSize: 11,
    fontWeight: FontWeight.normal,
  );

  /// Gris 400 — 14px normal
  static TextStyle grey14 = GoogleFonts.poppins(
    color: Colors.grey[400],
    fontSize: 14,
    fontWeight: FontWeight.normal,
  );

  /// Gris 400 — 13px normal
  static TextStyle grey13 = GoogleFonts.poppins(
    color: Colors.grey[400],
    fontSize: 13,
    fontWeight: FontWeight.normal,
  );

  /// Gris 500 — 14px normal
  static TextStyle greyMedium14 = GoogleFonts.poppins(
    color: Colors.grey[500],
    fontSize: 14,
    fontWeight: FontWeight.normal,
  );

  /// Gris 500 — 12px normal
  static TextStyle greyMedium12 = GoogleFonts.poppins(
    color: Colors.grey[500],
    fontSize: 12,
    fontWeight: FontWeight.normal,
  );

  /// Gris 500 — 13px normal
  static TextStyle greyMedium13 = GoogleFonts.poppins(
    color: Colors.grey[500],
    fontSize: 13,
    fontWeight: FontWeight.normal,
  );

  /// Gris — 13px normal
  static TextStyle greyBody13 = GoogleFonts.poppins(
    color: Colors.grey,
    fontSize: 13,
    fontWeight: FontWeight.normal,
  );

  /// Gris — 14px normal
  static TextStyle greyBody14 = GoogleFonts.poppins(
    color: Colors.grey,
    fontSize: 14,
    fontWeight: FontWeight.normal,
  );

  /// Gris — 12px normal
  static TextStyle greyBody12 = GoogleFonts.poppins(
    color: Colors.grey,
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

  /// Lien 12px — 12px normal primaire
  static TextStyle link12 = GoogleFonts.poppins(
    color: AppColors.primary,
    fontSize: 12,
    fontWeight: FontWeight.normal,
  );

  /// Lien 14px — 14px normal primaire
  static TextStyle link14 = GoogleFonts.poppins(
    color: AppColors.primary,
    fontSize: 14,
    fontWeight: FontWeight.normal,
  );

  /// Prix — 13px bold secondary (sky blue)
  static TextStyle price = GoogleFonts.poppins(
    color: AppColors.secondary,
    fontSize: 13,
    fontWeight: FontWeight.bold,
  );

  /// Prix large — 16px bold secondary
  static TextStyle priceLarge = GoogleFonts.poppins(
    color: AppColors.secondary,
    fontSize: 16,
    fontWeight: FontWeight.bold,
  );

  /// Accent secondaryVariant 13px bold
  static TextStyle accentBold13 = GoogleFonts.poppins(
    color: AppColors.secondaryVariant,
    fontSize: 13,
    fontWeight: FontWeight.bold,
  );

  /// Accent secondaryVariant 12px
  static TextStyle accent12 = GoogleFonts.poppins(
    color: AppColors.secondaryVariant,
    fontSize: 12,
    fontWeight: FontWeight.normal,
  );

  /// Accent secondaryVariant 13px
  static TextStyle accent13 = GoogleFonts.poppins(
    color: AppColors.secondaryVariant,
    fontSize: 13,
    fontWeight: FontWeight.normal,
  );

  /// Accent secondaryVariant 14px
  static TextStyle accent14 = GoogleFonts.poppins(
    color: AppColors.secondaryVariant,
    fontSize: 14,
    fontWeight: FontWeight.normal,
  );

  // ───────────────────────── Boutons ─────────────────────────────

  /// Texte de bouton principal — 16px semi-bold blanc
  static TextStyle button = GoogleFonts.poppins(
    color: AppColors.textPrimary,
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );

  /// Bouton 15px — 15px semi-bold blanc
  static TextStyle button15 = GoogleFonts.poppins(
    color: AppColors.textPrimary,
    fontSize: 15,
    fontWeight: FontWeight.w600,
  );

  /// Bouton 14px — 14px semi-bold blanc
  static TextStyle button14 = GoogleFonts.poppins(
    color: AppColors.textPrimary,
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );

  /// Petit bouton — 12px bold blanc
  static TextStyle buttonSmall = GoogleFonts.poppins(
    color: AppColors.textPrimary,
    fontSize: 12,
    fontWeight: FontWeight.bold,
  );

  /// Bouton 13px — 13px w500 blanc
  static TextStyle button13 = GoogleFonts.poppins(
    color: AppColors.textPrimary,
    fontSize: 13,
    fontWeight: FontWeight.w500,
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

  /// Lettre d'avatar — 24px bold secondary
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

  /// Erreur — 14px w600 rouge
  static TextStyle error14 = GoogleFonts.poppins(
    color: AppColors.error,
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );

  /// Succès — 14px w600 vert
  static TextStyle success14 = GoogleFonts.poppins(
    color: AppColors.success,
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );

  /// Stat big — 32px bold secondary
  static TextStyle statBig = GoogleFonts.poppins(
    color: AppColors.secondary,
    fontSize: 32,
    fontWeight: FontWeight.bold,
  );

  /// Amber star rating — 11px bold amber
  static TextStyle ratingAmber = GoogleFonts.poppins(
    color: Colors.amber,
    fontSize: 11,
    fontWeight: FontWeight.bold,
  );

  // ───────────────────────── Helpers ─────────────────────────────

  /// Applique une couleur différente à un style existant
  static TextStyle withColor(TextStyle style, Color color) =>
      style.copyWith(color: color);

  /// Applique une taille différente à un style existant
  static TextStyle withSize(TextStyle style, double size) =>
      style.copyWith(fontSize: size);
}
