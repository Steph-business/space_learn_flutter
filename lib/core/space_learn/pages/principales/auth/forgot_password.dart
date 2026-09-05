import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/themes/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:space_learn_flutter/core/themes/app_dimensions.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/auth/widgets/en_tete_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:space_learn_flutter/core/utils/app_notifications.dart';

import 'package:space_learn_flutter/core/space_learn/data/dataServices/authServices.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/auth/otp.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/auth/profil.dart';
import 'package:space_learn_flutter/core/utils/message_erreur.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;
  final _authService = AuthService();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _handleSendCode() async {
    if (_isLoading) return;
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      AppNotifications.showSnackBar(
        context,
        message: 'Veuillez entrer votre email.',
        isError: true,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Un échec lève désormais, avec le message du serveur : le `catch`
      // ci-dessous l'affiche tel quel plutôt qu'une phrase générique.
      await _authService.forgotPassword(email);
      if (mounted) {
        AppNotifications.showPremiumDialog(
          context,
          title: "Demande envoyée",
          // Le serveur répond volontairement dans le vague (anti-énumération)
          // : il rend 200 même quand aucun compte n'existe et qu'aucun
          // courriel n'est parti. Affirmer « un code a été envoyé à X »
          // transformait ce flou en certitude — une adresse mal tapée
          // (gmial.com) laissait attendre un code qui ne pouvait pas
          // arriver. On reprend sa formulation conditionnelle.
          message:
              "Si un compte est associé à l'adresse $email, un code de validation à 6 chiffres vient d'y être envoyé. Si rien n'arrive, vérifiez vos courriers indésirables et l'orthographe de l'adresse.",
          confirmText: "Entrer le code",
          isSuccess: true,
          onConfirm: () {
            if (mounted) {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => OtpPage(email: email)),
              );
            }
          },
        );
      }
    } catch (e) {
      if (mounted) {
        AppNotifications.showSnackBar(
          context,
          message: messageLisible(e, repli: "Envoi impossible pour le moment."),
          isError: true,
        );
      }
    } finally {
      // Le bouton retour reste actif pendant l'envoi : sans cette garde, la
      // réponse qui arrive après un retour arrière frappait un State disposé
      // (« setState() called after dispose() ») — défaut jumeau de celui
      // corrigé dans otp.dart.
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    AppColors.suivreLeTheme(context);
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

                const EnTeteAuth(
                  titre: 'Mot de passe oublié',
                  accroche:
                      'Entrez votre e-mail pour recevoir un code de vérification',
                ),

                const SizedBox(height: AppDimensions.spaceXl),

                // Form Card
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusCard,
                    ),
                    border: Border.all(
                      color: AppColors.textPrimary.withOpacity(0.05),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 70,
                          child: Text(
                            'E-mail',
                            style: AppTextStyles.cardTitleSmallSemiBold,
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: AppTextStyles.bodySecondary,
                            decoration: InputDecoration(
                              hintText: 'entrez votre e-mail...',
                              hintStyle: GoogleFonts.poppins(
                                color: AppColors.textHint,
                                fontSize: 13,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 28),

                // Send Code Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSendCode,
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
                            'Envoyer le code',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),

                SizedBox(height: 20),

                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Retour à la connexion',
                    style: AppTextStyles.linkBold,
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
