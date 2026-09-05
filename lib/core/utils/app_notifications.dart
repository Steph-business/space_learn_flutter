import 'package:flutter/material.dart';
import 'package:space_learn_flutter/core/themes/app_dimensions.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:space_learn_flutter/core/themes/app_colors.dart';

/// Un utilitaire de notifications/modales premium pour SpaceLearn.
class AppNotifications {
  AppNotifications._();

  /// Affiche un SnackBar stylisé avec des micro-animations
  static void showSnackBar(
    BuildContext context, {
    required String message,
    bool isError = false,
    bool isSuccess = false,
  }) {
    // Le fond se construit toujours à partir de la surface du thème, teintée de
    // la couleur sémantique. Les fonds sombres écrits en dur qui figuraient ici
    // ne suivaient pas le passage en mode clair : le message, peint en
    // textPrimary donc en noir, se retrouvait noir sur noir (1,23:1).
    Color teinter(Color semantique) => Color.alphaBlend(
      semantique.withValues(alpha: 0.14),
      AppColors.cardBackground,
    );

    Color bg = AppColors.cardBackground;
    Color borderCol = AppColors.textHint;
    IconData icon = Icons.info_outline;
    Color iconColor = AppColors.primary;

    if (isError) {
      bg = teinter(AppColors.error);
      borderCol = AppColors.error.withValues(alpha: 0.35);
      icon = Icons.error_outline_rounded;
      iconColor = AppColors.error;
    } else if (isSuccess) {
      bg = teinter(AppColors.success);
      borderCol = AppColors.success.withValues(alpha: 0.35);
      icon = Icons.check_circle_outline_rounded;
      iconColor = AppColors.success;
    }

    final snackBar = SnackBar(
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      content: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          border: Border.all(color: borderCol, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.poppins(
                  color: AppColors.textPrimary.withValues(alpha: 0.9),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
      duration: const Duration(seconds: 4),
    );

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(snackBar);
  }

  /// Affiche un dialogue premium (Popup) pour des confirmations ou erreurs critiques
  ///
  /// [barrierDismissible] et [fermerAvantConfirmation] valent par défaut ce que
  /// ce dialogue faisait déjà : un appui à côté ferme, et la confirmation
  /// ferme AVANT d'exécuter [onConfirm]. Les appelants qui ne les passent pas
  /// ne changent donc pas d'un iota. Les deux existent pour les gestes
  /// terminaux — supprimer un compte, basculer de profil — que ce
  /// comportement-là dessert :
  ///
  /// * fermer avant l'appel laisse l'écran d'origine affiché et inerte pendant
  ///   toute la requête, sans rien à quoi s'accrocher : deux écrans de
  ///   réglages ont dû fabriquer chacun leur voile de chargement pour combler
  ///   ce trou ;
  /// * un appui sur le fond vaut alors annulation SILENCIEUSE — ni [onCancel]
  ///   ni [onConfirm] ne partent, et l'appelant ne sait pas que la personne
  ///   n'a rien décidé.
  ///
  /// Avec `fermerAvantConfirmation: false`, [onConfirm] s'exécute pendant que
  /// le dialogue tient l'écran : c'est alors à l'appelant de le fermer
  /// (`Navigator.pop` sur le contexte du dialogue), et il doit le faire dans
  /// tous les cas, succès comme échec. Le bouton se verrouille après le
  /// premier appui, sans quoi le dialogue restant ouvert, deux appuis
  /// rapprochés enverraient deux fois le même geste irréversible.
  static Future<void> showPremiumDialog(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmText,
    String? cancelText,
    bool isError = false,
    bool isSuccess = false,
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
    bool barrierDismissible = true,
    bool fermerAvantConfirmation = true,
  }) async {
    IconData icon = Icons.info_outline;
    Color accentColor = AppColors.primary;

    if (isError) {
      icon = Icons.report_gmailerrorred_rounded;
      accentColor = AppColors.error;
    } else if (isSuccess) {
      icon = Icons.verified_user_outlined;
      accentColor = AppColors.primary;
    }

    // Un geste terminal ne part qu'une fois. Le drapeau vit hors du builder :
    // le dialogue restant ouvert (fermerAvantConfirmation: false), rien
    // n'empêchait sinon un second appui pendant la requête.
    var confirmationDejaPartie = false;

    return showDialog(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (BuildContext context) {
        // Le retour système suit la même règle que le fond.
        //
        // `barrierDismissible: false` ne ferme que la porte de devant : sur
        // Android, le geste de retour refermait quand même le dialogue, et
        // l'annulation silencieuse qu'on venait d'interdire revenait par la
        // fenêtre. Quand le fond ferme (le cas par défaut), rien ne change.
        return PopScope(
          canPop: barrierDismissible,
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 24,
            ),
            child: Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                border: Border.all(
                  color: AppColors.textPrimary.withValues(alpha: 0.08),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animated accent icon
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accentColor.withValues(alpha: 0.12),
                      border: Border.all(
                        color: accentColor.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(icon, size: 28, color: accentColor),
                  ),
                  SizedBox(height: 20),
                  // Title
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 12),
                  // Message
                  Text(
                    message,
                    style: GoogleFonts.poppins(
                      color: AppColors.textPrimary.withValues(alpha: 0.7),
                      fontSize: 14,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 24),
                  // Actions
                  Row(
                    children: [
                      if (cancelText != null) ...[
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                if (onCancel != null) onCancel();
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.textHint,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppDimensions.radiusInner,
                                  ),
                                ),
                              ),
                              child: Text(
                                cancelText,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                      ],
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () {
                              if (fermerAvantConfirmation) {
                                Navigator.of(context).pop();
                                if (onConfirm != null) onConfirm();
                                return;
                              }
                              // Le dialogue RESTE ouvert : c'est lui qui porte
                              // l'attente, et c'est l'appelant qui le fermera.
                              if (confirmationDejaPartie) return;
                              confirmationDejaPartie = true;
                              if (onConfirm != null) onConfirm();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accentColor,
                              foregroundColor: AppColors.onAccent,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppDimensions.radiusInner,
                                ),
                              ),
                            ),
                            child: Text(
                              confirmText,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
