import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/themes/app_text_styles.dart';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';

import 'package:space_learn_flutter/core/space_learn/data/dataServices/authServices.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/profileService.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/profilModel.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/auth/forgot_password.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/auth/profil.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/auth/register.dart';

import 'package:space_learn_flutter/core/space_learn/pages/principales/lecteur/accueil_lecteur_page.dart'
    as lecteurHome;
import 'package:space_learn_flutter/core/space_learn/pages/principales/ecrivain/accueil_auteur_page.dart'
    as ecrivainHome;

class LoginPage extends StatefulWidget {
  final String? initialEmail;
  final String? initialPassword;
  const LoginPage({super.key, this.initialEmail, this.initialPassword});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  final _profileService = ProfileService();

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialEmail != null) {
      _emailController.text = widget.initialEmail!;
    }
    if (widget.initialPassword != null) {
      _passwordController.text = widget.initialPassword!;
    }
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez remplir tous les champs.")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      developer.log('Tentative de connexion avec $email');
      final tokenUser = await _authService.login(email, password);

      final profilId = tokenUser.user.profilId;
      if (profilId.isEmpty) {
        throw Exception("Profil ID non reçu du backend.");
      }

      final allProfiles = await _profileService.getProfils();

      developer.log("Profil ID reçu : $profilId");
      for (final p in allProfiles) {
        developer.log("Profil en base : ${p.id} | ${p.libelle}");
      }

      final userProfile = allProfiles.firstWhere(
        (p) => p.id.trim().toLowerCase() == profilId.trim().toLowerCase(),
        orElse: () => ProfilModel(id: '', libelle: ''),
      );

      if (userProfile.id.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Aucun profil correspondant trouvé pour l'ID : $profilId",
            ),
          ),
        );
        setState(() => _isLoading = false);
        return;
      }

      final role = userProfile.libelle.toLowerCase();
      Widget destination;

      if (role.contains("lecteur")) {
        destination = lecteurHome.HomePageLecteur(
          profileId: profilId,
          userName: tokenUser.user.nomComplet,
        );
      } else if (role.contains("auteur") ||
          role.contains("administrateur") ||
          role.contains("éditeur")) {
        destination = ecrivainHome.HomePageAuteur(
          profileId: profilId,
          userName: tokenUser.user.nomComplet,
        );
      } else {
        destination = const ProfilPage();
      }

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => destination),
          (route) => false,
        );
      }
    } catch (e) {
      developer.log("Erreur lors de la connexion : $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur de connexion : ${e.toString()}")),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const ProfilPage()),
          );
        }
      },
      child: Scaffold(
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

                  // Close button (X) top-left
                  Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: () {
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        } else {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => const ProfilPage(),
                            ),
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

                  const SizedBox(height: 24),

                  // Title
                  Text(
                    'Connexion',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withOpacity(0.8),
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Brand
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Space',
                          style: GoogleFonts.poppins(
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        TextSpan(
                          text: 'Learn',
                          style: GoogleFonts.poppins(
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Subtitle
                  Text(
                    'Votre bibliothèque numérique\nintelligente',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      color: Colors.white.withOpacity(0.75),
                      height: 1.4,
                    ),
                  ),

                  const SizedBox(height: 36),

                  // Dark form card
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Email field
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 110,
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
                                    hintText: 'exemple@email.com',
                                    hintStyle: GoogleFonts.poppins(
                                      color: Colors.white30,
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

                        // Divider
                        Divider(
                          color: Colors.white.withOpacity(0.08),
                          height: 1,
                          indent: 16,
                          endIndent: 16,
                        ),

                        // Password field
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 110,
                                child: Text(
                                  'Mot de passe',
                                  style: AppTextStyles.cardTitleSmallSemiBold,
                                ),
                              ),
                              Expanded(
                                child: TextField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  style: AppTextStyles.bodySecondary,
                                  decoration: InputDecoration(
                                    hintText: 'votre mot de passe',
                                    hintStyle: GoogleFonts.poppins(
                                      color: Colors.white30,
                                      fontSize: 13,
                                    ),
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                        color: Colors.white30,
                                        size: 18,
                                      ),
                                      onPressed: () => setState(
                                        () => _obscurePassword =
                                            !_obscurePassword,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Subtitle under form
                  Text(
                    'Accédez à vos livres et contenus favoris',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.55),
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Login button (golden)
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
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
                              'Se connecter',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // "ou" separator
                  Text(
                    'ou',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Continue with Apple button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        // Apple sign-in placeholder
                      },
                      icon: const Icon(Icons.apple, size: 22),
                      label: Text(
                        'Continuer avec Apple',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black87,
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        side: BorderSide.none,
                        elevation: 2,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Forgot password
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ForgotPasswordPage(),
                        ),
                      );
                    },
                    child: Text(
                      'Mot de passe oublié ?',
                      style: GoogleFonts.poppins(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Register link
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RegisterPage()),
                    ),
                    child: RichText(
                      text: TextSpan(
                        text: "Pas encore de compte ? ",
                        style: GoogleFonts.poppins(
                          color: Colors.white60,
                          fontSize: 13,
                        ),
                        children: [
                          TextSpan(
                            text: "S'inscrire",
                            style: GoogleFonts.poppins(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
