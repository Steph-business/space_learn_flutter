import 'dart:developer' as developer;

import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';

import 'package:space_learn_flutter/core/space_learn/data/dataServices/authServices.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/profileService.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/profilModel.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/auth/forgot_password.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/auth/profil.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/auth/register.dart';
import '../../../../themes/app_colors.dart';

import 'package:space_learn_flutter/core/space_learn/pages/principales/lecteur/homePageLecteur.dart'
    as lecteurHome;
import 'package:space_learn_flutter/core/space_learn/pages/principales/ecrivain/homePageAuteur.dart'
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

      // 🔹 Correction principale : comparaison insensible à la casse
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

      // Redirection selon le rôle
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
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => destination),
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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFB453), Color(0xFFF9C47E), Color(0xFFF8E2C4)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // 🔹 Logo
                  const Icon(Icons.lock_outline, size: 80, color: Colors.white),
                  const SizedBox(height: 16),
                  Text(
                    'Connexion',
                    style: GoogleFonts.poppins(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // 🔹 Email
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: 'Adresse e-mail',
                      prefixIcon: const Icon(Icons.email_outlined),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 🔹 Mot de passe
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      hintText: 'Mot de passe',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 🔹 Bouton de connexion
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF59E0B),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            )
                          : const Text(
                              "Se connecter",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 🔹 Lien mot de passe oublié
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ForgotPasswordPage(),
                        ),
                      );
                    },
                    child: const Text(
                      'Mot de passe oublié ?',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 🔹 Lien inscription
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RegisterPage()),
                    ),
                    child: RichText(
                      text: TextSpan(
                        text: "Pas encore de compte ? ",
                        style: const TextStyle(color: Colors.white70),
                        children: [
                          TextSpan(
                            text: "S'inscrire",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
