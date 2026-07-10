import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/themes/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pinput/pinput.dart';
import 'package:space_learn_flutter/core/utils/app_notifications.dart';

import 'package:space_learn_flutter/core/space_learn/data/dataServices/authServices.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/auth/profil.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/auth/reset_password.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/auth/login.dart';
import 'package:space_learn_flutter/core/utils/profile_storage.dart';
import 'package:space_learn_flutter/core/utils/token_storage.dart';

import 'package:space_learn_flutter/core/space_learn/data/dataServices/profileService.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/profilModel.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/lecteur/accueil_lecteur_page.dart' as lecteurHome;
import 'package:space_learn_flutter/core/space_learn/pages/principales/ecrivain/accueil_auteur_page.dart' as ecrivainHome;

class OtpPage extends StatefulWidget {
  final String email;
  final String? password;
  final bool isFromRegistration;
  const OtpPage({
    super.key,
    required this.email,
    this.password,
    this.isFromRegistration = false,
  });

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  final TextEditingController _pinController = TextEditingController();
  bool _isLoading = false;
  final _authService = AuthService();
  final _profileService = ProfileService();

  void _handleVerifyCode() async {
    if (_isLoading) return;
    final otp = _pinController.text.trim();
    if (otp.length < 6) return;

    setState(() {
      _isLoading = true;
    });

    try {
      if (widget.isFromRegistration) {
        final tokenUser = await _authService.verifyRegistration(widget.email, otp);
        if (tokenUser != null && mounted) {
          AppNotifications.showSnackBar(
            context,
            message: "Inscription validée avec succès ! Connectez-vous pour compléter votre profil.",
            isSuccess: true,
          );

          final profilId = tokenUser.user.profilId;
          await _profileService.saveSelectedProfile(profilId);
          final allProfiles = await _profileService.getProfils();
          if (!mounted) return;
          final userProfile = allProfiles.firstWhere(
            (p) => p.id.trim().toLowerCase() == profilId.trim().toLowerCase(),
            orElse: () => ProfilModel(id: '', libelle: ''),
          );

          final role = userProfile.libelle.toLowerCase();
          await ProfileStorage.saveSelectedProfileRole(role);
          await ProfileStorage.saveIsRegisteredUser(true);

          // Clear token to force manual login
          await TokenStorage.clearToken();

          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (_) => LoginPage(
                  initialEmail: widget.email,
                  initialPassword: widget.password,
                  isFirstTimeRegistration: true,
                ),
              ),
              (route) => false,
            );
          }
        }
      } else {
        final success = await _authService.verifyOtp(widget.email, otp);

        if (success && mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) =>
                  ResetPasswordPage(email: widget.email, otp: otp),
            ),
          );
        } else if (mounted) {
          AppNotifications.showSnackBar(
            context,
            message: "Code OTP invalide.",
            isError: true,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        AppNotifications.showSnackBar(
          context,
          message: "Erreur: ${e.toString().replaceAll("Exception: ", "")}",
          isError: true,
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _handleResendCode() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final success = await _authService.forgotPassword(widget.email);
      if (success && mounted) {
        AppNotifications.showSnackBar(
          context,
          message: 'Un nouveau code de validation a été envoyé.',
          isSuccess: true,
        );
      } else if (mounted) {
        AppNotifications.showSnackBar(
          context,
          message: "Impossible de renvoyer le code.",
          isError: true,
        );
      }
    } catch (e) {
      if (mounted) {
        AppNotifications.showSnackBar(
          context,
          message: "Erreur: ${e.toString().replaceAll("Exception: ", "")}",
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final defaultPinTheme = PinTheme(
      width: 48,
      height: 52,
      textStyle: GoogleFonts.poppins(
        fontSize: 20,
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        borderRadius: BorderRadius.circular(12),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: AppColors.primary, width: 2),
      borderRadius: BorderRadius.circular(12),
    );

    final submittedPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: AppColors.primary.withOpacity(0.5)),
      borderRadius: BorderRadius.circular(12),
    );

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
                const SizedBox(height: 12),

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
                        color: Colors.white.withOpacity(0.15),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Icon
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withOpacity(0.15),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.pin_outlined,
                    size: 30,
                    color: AppColors.primary,
                  ),
                ),

                const SizedBox(height: 20),

                // Title
                Text(
                  'Vérification',
                  style: AppTextStyles.pageTitle,
                ),
                const SizedBox(height: 8),

                Text(
                  'Entrez le code envoyé à\n${widget.email}',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.65),
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 40),

                // Pinput (OTP field)
                Pinput(
                  controller: _pinController,
                  length: 6,
                  defaultPinTheme: defaultPinTheme,
                  focusedPinTheme: focusedPinTheme,
                  submittedPinTheme: submittedPinTheme,
                  pinputAutovalidateMode: PinputAutovalidateMode.onSubmit,
                  showCursor: true,
                  cursor: Container(
                    width: 2,
                    height: 24,
                    color: AppColors.primary,
                  ),
                  onCompleted: (pin) => _handleVerifyCode(),
                ),

                const SizedBox(height: 36),

                // Verify Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleVerifyCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shadowColor: AppColors.primary.withOpacity(0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(
                            'Vérifier',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 20),

                TextButton(
                  onPressed: _isLoading ? null : _handleResendCode,
                  child: Text(
                    'Renvoyer le code',
                    style: AppTextStyles.linkBold,
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
