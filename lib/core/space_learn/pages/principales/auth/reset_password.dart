import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/themes/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:space_learn_flutter/core/themes/app_dimensions.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:space_learn_flutter/core/utils/app_notifications.dart';

import 'package:space_learn_flutter/core/space_learn/data/dataServices/authServices.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/auth/login.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/auth/profil.dart';

class ResetPasswordPage extends StatefulWidget {
  final String email;
  final String otp;
  const ResetPasswordPage({super.key, required this.email, required this.otp});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  final _authService = AuthService();

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _togglePasswordVisibility() {
    setState(() {
      _obscurePassword = !_obscurePassword;
    });
  }

  void _toggleConfirmPasswordVisibility() {
    setState(() {
      _obscureConfirmPassword = !_obscureConfirmPassword;
    });
  }

  void _handleResetPassword() async {
    if (_isLoading) return;

    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (password.isEmpty || confirmPassword.isEmpty) {
      AppNotifications.showSnackBar(
        context,
        message: 'Veuillez remplir tous les champs.',
        isError: true,
      );
      return;
    }

    if (password != confirmPassword) {
      AppNotifications.showSnackBar(
        context,
        message: 'Les mots de passe ne correspondent pas.',
        isError: true,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await _authService.resetPassword(
        widget.email,
        widget.otp,
        password,
      );

      if (success && mounted) {
        AppNotifications.showPremiumDialog(
          context,
          title: "Mot de passe réinitialisé",
          message:
              "Votre mot de passe a été modifié avec succès ! Vous pouvez maintenant vous connecter.",
          confirmText: "Se connecter",
          isSuccess: true,
          onConfirm: () {
            if (mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => LoginPage(initialEmail: widget.email),
                ),
                (route) => false,
              );
            }
          },
        );
      } else if (mounted) {
        AppNotifications.showSnackBar(
          context,
          message: "Impossible de réinitialiser le mot de passe.",
          isError: true,
        );
      }
    } catch (e) {
      if (mounted) {
        AppNotifications.showSnackBar(
          context,
          message: "Erreur : ${e.toString().replaceAll("Exception: ", "")}",
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: AppColors.scaffoldBackground,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                SizedBox(height: 12),

                // Close button
                Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: () {
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      } else {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (_) => const ProfilPage()),
                        );
                      }
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.textPrimary.withOpacity(0.15),
                        border: Border.all(
                          color: AppColors.textPrimary.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new,
                        color: AppColors.textPrimary,
                        size: 20,
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 32),

                // Brand Logo
                Image.asset(
                  'asset/logo_space_learn.png',
                  width: 110,
                  height: 110,
                  fit: BoxFit.contain,
                ),

                SizedBox(height: 20),

                // Title
                Text('Nouveau mot de passe', style: AppTextStyles.pageTitle),
                SizedBox(height: 8),

                Text(
                  'Veuillez entrer votre\nnouveau mot de passe',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: AppColors.textPrimary.withOpacity(0.65),
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),

                SizedBox(height: 36),

                // Form Card
                Container(
                  padding: const EdgeInsets.all(AppDimensions.cardPadding),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusCard,
                    ),
                    border: Border.all(color: AppColors.border),
                  ),
                  // Libellé au-dessus, champ sur toute la largeur — comme à
                  // la connexion et à l'inscription. La colonne de libellé
                  // fixe de 110 px ne laissait pas la place d'afficher une
                  // invite complète : « confirmer le mot de... » était tronqué
                  // à la main dans le code.
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Mot de passe',
                        style: AppTextStyles.cardTitleSmallSemiBold,
                      ),
                      const SizedBox(height: AppDimensions.spaceSm),
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: AppTextStyles.bodySecondary,
                        decoration: InputDecoration(
                          hintText: 'nouveau mot de passe',
                          hintStyle: GoogleFonts.poppins(
                            color: AppColors.textHint,
                            fontSize: 13,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: AppColors.textHint,
                              size: 18,
                            ),
                            onPressed: _togglePasswordVisibility,
                          ),
                        ),
                      ),

                      const SizedBox(height: AppDimensions.spaceLg),

                      Text(
                        'Confirmer',
                        style: AppTextStyles.cardTitleSmallSemiBold,
                      ),
                      const SizedBox(height: AppDimensions.spaceSm),
                      TextField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        style: AppTextStyles.bodySecondary,
                        decoration: InputDecoration(
                          hintText: 'confirmez le mot de passe',
                          hintStyle: GoogleFonts.poppins(
                            color: AppColors.textHint,
                            fontSize: 13,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: AppColors.textHint,
                              size: 18,
                            ),
                            onPressed: _toggleConfirmPasswordVisibility,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 28),

                // Reset Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleResetPassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onAccent,
                      elevation: 4,
                      shadowColor: AppColors.primary.withOpacity(0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusInner,
                        ),
                      ),
                    ),
                    child: _isLoading
                        ? SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: AppColors.onAccent,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(
                            'Réinitialiser',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),

                SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
