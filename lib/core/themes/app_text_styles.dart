import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Styles de texte centralisés pour SpaceLearn.
/// Tous les styles utilisent Google Fonts Poppins par défaut.
class AppTextStyles {
  AppTextStyles._();

  // ───────────────────────── Titres ──────────────────────────────

  /// Titre héro — 28px extra-bold blanc
  static TextStyle get heroTitle => GoogleFonts.hankenGrotesk(
    color: AppColors.textPrimary,
    fontSize: 28,
    fontWeight: FontWeight.w800,
  );

  /// Titre principal de page — 24px bold blanc
  static TextStyle get pageTitle => GoogleFonts.hankenGrotesk(
    color: AppColors.textPrimary,
    fontSize: 24,
    fontWeight: FontWeight.bold,
  );

  /// Titre héro 22px — 22px extra-bold blanc
  static TextStyle get heroTitle22 => GoogleFonts.hankenGrotesk(
    color: AppColors.textPrimary,
    fontSize: 22,
    fontWeight: FontWeight.w800,
  );

  /// Titre de section — 18px bold blanc
  static TextStyle get sectionTitle => GoogleFonts.hankenGrotesk(
    color: AppColors.textPrimary,
    fontSize: 18,
    fontWeight: FontWeight.bold,
  );

  /// Titre de section semi-bold — 18px w600 blanc
  static TextStyle get sectionTitleSemiBold => GoogleFonts.hankenGrotesk(
    color: AppColors.textPrimary,
    fontSize: 18,
    fontWeight: FontWeight.w600,
  );

  /// Titre de section w700 — 18px w700 blanc
  static TextStyle get sectionTitleW700 => GoogleFonts.hankenGrotesk(
    color: AppColors.textPrimary,
    fontSize: 18,
    fontWeight: FontWeight.w700,
  );

  /// Sous-titre — 16px semi-bold blanc
  static TextStyle get subtitle => GoogleFonts.hankenGrotesk(
    color: AppColors.textPrimary,
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );

  /// Sous-titre bold — 16px bold blanc
  static TextStyle get subtitleBold => GoogleFonts.hankenGrotesk(
    color: AppColors.textPrimary,
    fontSize: 16,
    fontWeight: FontWeight.bold,
  );

  /// Sous-titre 15px — 15px w500 blanc
  static TextStyle get subtitle15 => GoogleFonts.hankenGrotesk(
    color: AppColors.textPrimary,
    fontSize: 15,
    fontWeight: FontWeight.w500,
  );

  /// Titre de carte — 14px bold blanc
  static TextStyle get cardTitle => GoogleFonts.hankenGrotesk(
    color: AppColors.textPrimary,
    fontSize: 14,
    fontWeight: FontWeight.bold,
  );

  /// Titre de carte w700 — 14px w700 blanc
  static TextStyle get cardTitleW700 => GoogleFonts.hankenGrotesk(
    color: AppColors.textPrimary,
    fontSize: 14,
    fontWeight: FontWeight.w700,
  );

  /// Titre de carte w500 — 14px w500 blanc
  static TextStyle get cardTitleMedium => GoogleFonts.hankenGrotesk(
    color: AppColors.textPrimary,
    fontSize: 14,
    fontWeight: FontWeight.w500,
  );

  /// Titre petit — 13px bold blanc
  static TextStyle get cardTitleSmall => GoogleFonts.hankenGrotesk(
    color: AppColors.textPrimary,
    fontSize: 13,
    fontWeight: FontWeight.bold,
  );

  /// Titre 13px semi-bold — 13px w600 blanc
  static TextStyle get cardTitleSmallSemiBold => GoogleFonts.hankenGrotesk(
    color: AppColors.textPrimary,
    fontSize: 13,
    fontWeight: FontWeight.w600,
  );

  /// Titre 12px bold — 12px bold blanc
  static TextStyle get cardTitle12Bold => GoogleFonts.hankenGrotesk(
    color: AppColors.textPrimary,
    fontSize: 12,
    fontWeight: FontWeight.bold,
  );

  /// Titre 12px w700 — 12px w700 blanc
  static TextStyle get cardTitle12W700 => GoogleFonts.hankenGrotesk(
    color: AppColors.textPrimary,
    fontSize: 12,
    fontWeight: FontWeight.w700,
  );

  /// Titre 12px semi-bold — 12px w600 blanc
  static TextStyle get cardTitle12SemiBold => GoogleFonts.hankenGrotesk(
    color: AppColors.textPrimary,
    fontSize: 12,
    fontWeight: FontWeight.w600,
  );

  // ───────────────────────── Corps ───────────────────────────────

  /// Texte de corps principal — 14px normal blanc
  static TextStyle get body => GoogleFonts.hankenGrotesk(
    color: AppColors.textPrimary,
    fontSize: 14,
    fontWeight: FontWeight.normal,
  );

  /// Texte 15px normal blanc
  static TextStyle get body15 => GoogleFonts.hankenGrotesk(
    color: AppColors.textPrimary,
    fontSize: 15,
    fontWeight: FontWeight.normal,
  );

  /// Corps 13px normal blanc
  static TextStyle get body13 => GoogleFonts.hankenGrotesk(
    color: AppColors.textPrimary,
    fontSize: 13,
    fontWeight: FontWeight.normal,
  );

  /// Corps 12px normal blanc
  static TextStyle get body12 => GoogleFonts.hankenGrotesk(
    color: AppColors.textPrimary,
    fontSize: 12,
    fontWeight: FontWeight.normal,
  );

  /// Corps 11px normal blanc
  static TextStyle get body11 => GoogleFonts.hankenGrotesk(
    color: AppColors.textPrimary,
    fontSize: 11,
    fontWeight: FontWeight.normal,
  );

  /// Corps 10px normal blanc
  static TextStyle get body10 => GoogleFonts.hankenGrotesk(
    color: AppColors.textPrimary,
    fontSize: 10,
    fontWeight: FontWeight.normal,
  );

  /// Texte de corps secondaire — 13px normal blanc70
  static TextStyle get bodySecondary => GoogleFonts.hankenGrotesk(
    color: AppColors.textSecondary,
    fontSize: 13,
    fontWeight: FontWeight.normal,
  );

  /// Texte secondaire 14px — 14px normal blanc70
  static TextStyle get bodySecondary14 => GoogleFonts.hankenGrotesk(
    color: AppColors.textSecondary,
    fontSize: 14,
    fontWeight: FontWeight.normal,
  );

  /// Texte petit — 12px normal blanc70
  static TextStyle get bodySmall => GoogleFonts.hankenGrotesk(
    color: AppColors.textSecondary,
    fontSize: 12,
    fontWeight: FontWeight.normal,
  );

  /// Texte petit 11px — 11px normal blanc70
  static TextStyle get bodySmall11 => GoogleFonts.hankenGrotesk(
    color: AppColors.textSecondary,
    fontSize: 11,
    fontWeight: FontWeight.normal,
  );

  /// Texte petit 10px — 10px normal blanc70
  static TextStyle get bodySmall10 => GoogleFonts.hankenGrotesk(
    color: AppColors.textSecondary,
    fontSize: 10,
    fontWeight: FontWeight.normal,
  );

  /// Texte très petit — 11px medium blanc70
  static TextStyle get caption => GoogleFonts.hankenGrotesk(
    color: AppColors.textSecondary,
    fontSize: 11,
    fontWeight: FontWeight.w500,
  );

  /// Texte gris — 12px normal gris
  static TextStyle get bodyMuted => GoogleFonts.hankenGrotesk(
    color: AppColors.textHint,
    fontSize: 12,
    fontWeight: FontWeight.normal,
  );

  /// Texte blanc54 — 16 normal
  static TextStyle get bodyFaded16 => GoogleFonts.hankenGrotesk(
    color: AppColors.textHint,
    fontSize: 16,
    fontWeight: FontWeight.normal,
  );

  /// Texte blanc54 — 12 normal
  static TextStyle get bodyFaded12 => GoogleFonts.hankenGrotesk(
    color: AppColors.textHint,
    fontSize: 12,
    fontWeight: FontWeight.normal,
  );

  /// Texte blanc54 — 13 normal
  static TextStyle get bodyFaded13 => GoogleFonts.hankenGrotesk(
    color: AppColors.textHint,
    fontSize: 13,
    fontWeight: FontWeight.normal,
  );

  // ───────────────────────── Gris ────────────────────────────────

  /// Gris 400 — 12px normal
  static TextStyle get grey12 => GoogleFonts.hankenGrotesk(
    color: AppColors.textSecondary,
    fontSize: 12,
    fontWeight: FontWeight.normal,
  );

  /// Gris 400 — 11px normal
  static TextStyle get grey11 => GoogleFonts.hankenGrotesk(
    color: AppColors.textSecondary,
    fontSize: 11,
    fontWeight: FontWeight.normal,
  );

  /// Gris 400 — 14px normal
  static TextStyle get grey14 => GoogleFonts.hankenGrotesk(
    color: AppColors.textSecondary,
    fontSize: 14,
    fontWeight: FontWeight.normal,
  );

  /// Gris 400 — 13px normal
  static TextStyle get grey13 => GoogleFonts.hankenGrotesk(
    color: AppColors.textSecondary,
    fontSize: 13,
    fontWeight: FontWeight.normal,
  );

  /// Gris 500 — 14px normal
  static TextStyle get greyMedium14 => GoogleFonts.hankenGrotesk(
    color: AppColors.textSecondary,
    fontSize: 14,
    fontWeight: FontWeight.normal,
  );

  /// Gris 500 — 12px normal
  static TextStyle get greyMedium12 => GoogleFonts.hankenGrotesk(
    color: AppColors.textSecondary,
    fontSize: 12,
    fontWeight: FontWeight.normal,
  );

  /// Gris 500 — 13px normal
  static TextStyle get greyMedium13 => GoogleFonts.hankenGrotesk(
    color: AppColors.textSecondary,
    fontSize: 13,
    fontWeight: FontWeight.normal,
  );

  /// Gris — 13px normal
  static TextStyle get greyBody13 => GoogleFonts.hankenGrotesk(
    color: Colors.grey,
    fontSize: 13,
    fontWeight: FontWeight.normal,
  );

  /// Gris — 14px normal
  static TextStyle get greyBody14 => GoogleFonts.hankenGrotesk(
    color: Colors.grey,
    fontSize: 14,
    fontWeight: FontWeight.normal,
  );

  /// Gris — 12px normal
  static TextStyle get greyBody12 => GoogleFonts.hankenGrotesk(
    color: Colors.grey,
    fontSize: 12,
    fontWeight: FontWeight.normal,
  );

  // ───────────────────────── Accents ─────────────────────────────

  /// Lien / texte accent — 13px normal primaire
  static TextStyle get link => GoogleFonts.hankenGrotesk(
    color: AppColors.primary,
    fontSize: 13,
    fontWeight: FontWeight.normal,
  );

  /// Lien gras — 13px semi-bold primaire
  static TextStyle get linkBold => GoogleFonts.hankenGrotesk(
    color: AppColors.primary,
    fontSize: 13,
    fontWeight: FontWeight.w600,
  );

  /// Lien 12px — 12px normal primaire
  static TextStyle get link12 => GoogleFonts.hankenGrotesk(
    color: AppColors.primary,
    fontSize: 12,
    fontWeight: FontWeight.normal,
  );

  /// Lien 14px — 14px normal primaire
  static TextStyle get link14 => GoogleFonts.hankenGrotesk(
    color: AppColors.primary,
    fontSize: 14,
    fontWeight: FontWeight.normal,
  );

  /// Prix — 13px bold secondary (sky blue)
  static TextStyle get price => GoogleFonts.hankenGrotesk(
    color: AppColors.secondary,
    fontSize: 13,
    fontWeight: FontWeight.bold,
  );

  /// Prix large — 16px bold secondary
  static TextStyle get priceLarge => GoogleFonts.hankenGrotesk(
    color: AppColors.secondary,
    fontSize: 16,
    fontWeight: FontWeight.bold,
  );

  /// Accent secondaryVariant 13px bold
  static TextStyle get accentBold13 => GoogleFonts.hankenGrotesk(
    color: AppColors.secondaryVariant,
    fontSize: 13,
    fontWeight: FontWeight.bold,
  );

  /// Accent secondaryVariant 12px
  static TextStyle get accent12 => GoogleFonts.hankenGrotesk(
    color: AppColors.secondaryVariant,
    fontSize: 12,
    fontWeight: FontWeight.normal,
  );

  /// Accent secondaryVariant 13px
  static TextStyle get accent13 => GoogleFonts.hankenGrotesk(
    color: AppColors.secondaryVariant,
    fontSize: 13,
    fontWeight: FontWeight.normal,
  );

  /// Accent secondaryVariant 14px
  static TextStyle get accent14 => GoogleFonts.hankenGrotesk(
    color: AppColors.secondaryVariant,
    fontSize: 14,
    fontWeight: FontWeight.normal,
  );

  // ───────────────────────── Boutons ─────────────────────────────

  /// Texte de bouton principal — 16px semi-bold blanc
  static TextStyle get button => GoogleFonts.hankenGrotesk(
    color: AppColors.textPrimary,
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );

  /// Bouton 15px — 15px semi-bold blanc
  static TextStyle get button15 => GoogleFonts.hankenGrotesk(
    color: AppColors.textPrimary,
    fontSize: 15,
    fontWeight: FontWeight.w600,
  );

  /// Bouton 14px — 14px semi-bold blanc
  static TextStyle get button14 => GoogleFonts.hankenGrotesk(
    color: AppColors.textPrimary,
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );

  /// Petit bouton — 12px bold blanc
  static TextStyle get buttonSmall => GoogleFonts.hankenGrotesk(
    color: AppColors.textPrimary,
    fontSize: 12,
    fontWeight: FontWeight.bold,
  );

  /// Bouton 13px — 13px w500 blanc
  static TextStyle get button13 => GoogleFonts.hankenGrotesk(
    color: AppColors.textPrimary,
    fontSize: 13,
    fontWeight: FontWeight.w500,
  );

  /// Label de catégorie sélectionnée — 13px semi-bold blanc
  static TextStyle get chipSelected => GoogleFonts.hankenGrotesk(
    color: AppColors.textPrimary,
    fontSize: 13,
    fontWeight: FontWeight.w600,
  );

  /// Label de catégorie non sélectionnée — 13px normal gris clair
  static TextStyle get chipUnselected => GoogleFonts.hankenGrotesk(
    color: AppColors.slateLight,
    fontSize: 13,
    fontWeight: FontWeight.normal,
  );

  // ───────────────────────── Auth pages ──────────────────────────

  /// Titre grand pour pages d'authentification — 28px bold blanc
  static TextStyle get authTitle => GoogleFonts.hankenGrotesk(
    color: AppColors.textPrimary,
    fontSize: 28,
    fontWeight: FontWeight.bold,
  );

  /// Sous-titre auth — 15px normal blanc70
  static TextStyle get authSubtitle => GoogleFonts.hankenGrotesk(
    color: AppColors.textSecondary,
    fontSize: 15,
    fontWeight: FontWeight.normal,
  );

  /// Label de champ — 14px medium blanc
  static TextStyle get fieldLabel => GoogleFonts.hankenGrotesk(
    color: AppColors.textPrimary,
    fontSize: 14,
    fontWeight: FontWeight.w500,
  );

  /// Hint de champ — 14px normal gris
  static TextStyle get fieldHint => GoogleFonts.hankenGrotesk(
    color: AppColors.textHint,
    fontSize: 14,
    fontWeight: FontWeight.normal,
  );

  // ───────────────────────── Divers ──────────────────────────────

  /// Nom d'auteur — 12px medium blanc
  static TextStyle get authorName => GoogleFonts.hankenGrotesk(
    color: AppColors.textPrimary,
    fontSize: 12,
    fontWeight: FontWeight.w500,
  );

  /// Lettre d'avatar — 24px bold secondary
  static TextStyle get avatarLetter => GoogleFonts.hankenGrotesk(
    color: AppColors.secondary,
    fontSize: 24,
    fontWeight: FontWeight.bold,
  );

  /// Citation italique — Lora 14px italic blanc
  static TextStyle get quote => GoogleFonts.lora(
    color: AppColors.textPrimary,
    fontSize: 14,
    fontStyle: FontStyle.italic,
    fontWeight: FontWeight.w500,
    height: 1.3,
  );

  /// Notification titre — 14px bold blanc
  static TextStyle get notificationTitle => GoogleFonts.hankenGrotesk(
    color: AppColors.textPrimary,
    fontSize: 14,
    fontWeight: FontWeight.bold,
  );

  /// Statistique valeur — 18px bold blanc
  static TextStyle get statValue => GoogleFonts.hankenGrotesk(
    color: AppColors.textPrimary,
    fontSize: 18,
    fontWeight: FontWeight.bold,
  );

  /// Statistique label — 11px normal blanc70
  static TextStyle get statLabel => GoogleFonts.hankenGrotesk(
    color: AppColors.textSecondary,
    fontSize: 11,
    fontWeight: FontWeight.normal,
  );

  /// Erreur — 14px w600 rouge
  static TextStyle get error14 => GoogleFonts.hankenGrotesk(
    color: AppColors.error,
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );

  /// Succès — 14px w600 vert
  static TextStyle get success14 => GoogleFonts.hankenGrotesk(
    color: AppColors.success,
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );

  /// Stat big — 32px bold secondary
  static TextStyle get statBig => GoogleFonts.hankenGrotesk(
    color: AppColors.secondary,
    fontSize: 32,
    fontWeight: FontWeight.bold,
  );

  /// Amber star rating — 11px bold amber
  static TextStyle get ratingAmber => GoogleFonts.hankenGrotesk(
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