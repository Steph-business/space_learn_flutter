import 'package:flutter/material.dart';
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
    Color bg = AppColors.cardBackground;
    Color borderCol = AppColors.textHint;
    IconData icon = Icons.info_outline;
    Color iconColor = AppColors.primary;

    if (isError) {
      bg = const Color(0xFF1E1B1B);
      borderCol = AppColors.error.withOpacity(0.3);
      icon = Icons.error_outline_rounded;
      iconColor = AppColors.error;
    } else if (isSuccess) {
      bg = const Color(0xFF14201A);
      borderCol = AppColors.success.withOpacity(0.3);
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
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderCol, width: 1.5),
          
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.poppins(
                  color: AppColors.textPrimary.withOpacity(0.9),
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
  }) async {
    IconData icon = Icons.info_outline;
    Color accentColor = AppColors.primary;

    if (isError) {
      icon = Icons.report_gmailerrorred_rounded;
      accentColor = AppColors.error;
    } else if (isSuccess) {
      icon = Icons.verified_user_outlined;
      accentColor = AppColors.success;
    }

    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.textPrimary.withOpacity(0.08)),
              
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
                    color: accentColor.withOpacity(0.12),
                    border: Border.all(
                      color: accentColor.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    icon,
                    size: 28,
                    color: accentColor,
                  ),
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
                    color: AppColors.textPrimary.withOpacity(0.7),
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
                                borderRadius: BorderRadius.circular(12),
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
                            Navigator.of(context).pop();
                            if (onConfirm != null) onConfirm();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentColor,
                            foregroundColor: AppColors.textPrimary,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
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
        );
      },
    );
  }
}