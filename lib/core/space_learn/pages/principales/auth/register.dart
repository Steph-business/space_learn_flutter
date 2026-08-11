import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/themes/app_text_styles.dart';
import 'package:space_learn_flutter/core/utils/app_notifications.dart';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:space_learn_flutter/core/themes/app_dimensions.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/auth/widgets/en_tete_auth.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:space_learn_flutter/core/space_learn/data/dataServices/authServices.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/profileService.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/auth/login.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/auth/otp.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/auth/profil.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _pseudoController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  final _authService = AuthService();

  @override
  void dispose() {
    _nameController.dispose();
    _pseudoController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _togglePasswordVisibility() {
    setState(() => _obscurePassword = !_obscurePassword);
  }

  void _toggleConfirmPasswordVisibility() {
    setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
  }

  void _handleRegister() async {
    if (_isLoading) return;

    developer.log('Début de _handleRegister', name: 'RegisterPage');

    final name = _nameController.text.trim();
    final pseudo = _pseudoController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (name.isEmpty || pseudo.isEmpty || email.isEmpty || password.isEmpty) {
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

    final profileService = ProfileService();
    final selectedProfile = await profileService.getSelectedProfile();

    if (!mounted) return;

    if (selectedProfile == null) {
      AppNotifications.showSnackBar(
        context,
        message: "Veuillez d'abord sélectionner un profil.",
        isError: true,
      );
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const ProfilPage()));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final success = await _authService.register(
        nomComplet: name,
        pseudo: pseudo,
        email: email,
        password: password,
        profilId: selectedProfile,
      );

      if (!mounted) return;

      if (success) {
        AppNotifications.showPremiumDialog(
          context,
          title: "Inscription réussie !",
          message:
              "Votre compte a été créé avec succès. Un code OTP a été envoyé à l'adresse $email pour valider votre compte.",
          confirmText: "Saisir le code",
          isSuccess: true,
          onConfirm: () {
            if (mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (_) => OtpPage(
                    email: email,
                    password: password,
                    isFromRegistration: true,
                  ),
                ),
                (route) => false,
              );
            }
          },
        );
      }
    } catch (e) {
      developer.log(
        "Erreur lors de l'inscription: $e",
        name: 'RegisterPage',
        error: e,
        level: 1000,
      );

      if (!mounted) return;

      AppNotifications.showSnackBar(
        context,
        message:
            "Erreur d'inscription: ${e.toString().replaceAll("Exception: ", "")}",
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
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

                // Close button (X) top-left
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

                SizedBox(height: 12),

                const EnTeteAuth(accroche: 'Créez votre compte pour commencer'),

                const SizedBox(height: AppDimensions.spaceXl),

                // Formulaire
                Container(
                  padding: const EdgeInsets.all(AppDimensions.cardPadding),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusCard,
                    ),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Name field
                      _buildFormField(
                        label: 'Nom complet',
                        controller: _nameController,
                        hintText: 'entrez votre nom complet',
                      ),
                      const SizedBox(height: AppDimensions.spaceMd),

                      // Pseudo field
                      _buildFormField(
                        label: 'Pseudo',
                        controller: _pseudoController,
                        hintText: 'choisissez un pseudo',
                      ),
                      const SizedBox(height: AppDimensions.spaceMd),

                      // Email field
                      _buildFormField(
                        label: 'E-mail',
                        controller: _emailController,
                        hintText: 'entrez votre adresse e-mail',
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: AppDimensions.spaceMd),

                      // Password field
                      _buildFormField(
                        label: 'Mot de passe',
                        controller: _passwordController,
                        hintText: 'entrez votre mot de passe',
                        obscureText: _obscurePassword,
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
                      const SizedBox(height: AppDimensions.spaceMd),

                      // Confirm password field
                      _buildFormField(
                        label: 'Confirmer',
                        controller: _confirmPasswordController,
                        hintText: 'confirmez votre mot de passe',
                        obscureText: _obscureConfirmPassword,
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
                    ],
                  ),
                ),

                SizedBox(height: 24),

                // Register button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleRegister,
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
                            "S'inscrire",
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),

                SizedBox(height: 20),

                // Login link
                GestureDetector(
                  onTap: _isLoading
                      ? null
                      : () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const LoginPage(),
                            ),
                          );
                        },
                  child: RichText(
                    text: TextSpan(
                      text: 'Vous avez déjà un compte ? ',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: AppColors.textHint,
                      ),
                      children: [
                        TextSpan(
                          text: 'Se connecter',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: AppColors.accentInk,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
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

  /// Libellé au-dessus, champ sur toute la largeur.
  ///
  /// Le libellé occupait auparavant une colonne fixe de 100 px à gauche du
  /// champ. Il ne restait pas la place d'afficher une invite complète : elles
  /// avaient été tronquées à la main dans le code — « entrez le mot de pa... »,
  /// « confirmer le mot de... ». Un formulaire d'inscription qui coupe ses
  /// propres consignes n'inspire pas confiance au moment précis où on demande
  /// un mot de passe.
  Widget _buildFormField({
    required String label,
    required TextEditingController controller,
    required String hintText,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.cardTitleSmallSemiBold),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          style: AppTextStyles.bodySecondary,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: GoogleFonts.poppins(
              color: AppColors.textHint,
              fontSize: 13,
            ),
            suffixIcon: suffixIcon,
          ),
        ),
      ],
    );
  }
}
