import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:developer' as developer;
import 'package:space_learn_flutter/core/space_learn/data/dataSources/authServices.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataSources/profileService.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/auth/profil.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/auth/login.dart';
import '../../../../themes/app_colors.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/lecteur/homePageLecteur.dart'
    as lecteurHome;
import 'package:space_learn_flutter/core/space_learn/pages/principales/ecrivain/homePageAuteur.dart'
    as ecrivainHome;
import 'package:space_learn_flutter/core/space_learn/data/model/profilModel.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _nameController = TextEditingController();
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
    _emailController.dispose();
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

  void _handleRegister() async {
    if (_isLoading) return;
    developer.log('Début de _handleRegister', name: 'RegisterPage');

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    developer.log(
      'Données saisies: nom=$name, email=$email',
      name: 'RegisterPage',
    );

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez remplir tous les champs.')),
      );
      return;
    }

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Les mots de passe ne correspondent pas.'),
        ),
      );
      return;
    }

    // Récupérer le profil sélectionné
    final _profileService = ProfileService();
    final selectedProfile = await _profileService.getSelectedProfile();
    if (selectedProfile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez d\'abord sélectionner un profil.'),
        ),
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const ProfilPage()),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      developer.log('Appel de _authService.register...', name: 'RegisterPage');
      final tokenUser = await _authService.register(
        nomComplet: name,
        email: email,
        password: password,
        profilId: selectedProfile,
      );

      if (mounted) {
        developer.log(
          'Inscription réussie, navigation vers LoginPage.',
          name: 'RegisterPage',
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Inscription réussie ! Veuillez vous connecter.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) =>
                LoginPage(initialEmail: email, initialPassword: password),
          ),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      developer.log(
        "Erreur lors de l'inscription: $e",
        name: 'RegisterPage',
        error: e,
        level: 1000,
      ); // SEVERE
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur d'inscription: ${e.toString()}")),
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFB453),
              Color.fromARGB(255, 249, 196, 126),
              Color.fromARGB(255, 248, 226, 196),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 20.0,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icon
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.person_add_alt_1_outlined,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Title
                  Text(
                    'Inscription',
                    style: GoogleFonts.poppins(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Subtitle
                  Text(
                    'Créez votre compte pour commencer',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                      fontWeight: FontWeight.w400,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 20),

                  // Register Form Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Full Name Field
                        _buildTextField(
                          controller: _nameController,
                          hintText: 'Nom complet',
                          icon: Icons.person_outline,
                        ),
                        const SizedBox(height: 16),

                        // Email Field
                        _buildTextField(
                          controller: _emailController,
                          hintText: 'marie@example.com',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 16),

                        // Password Field
                        _buildTextField(
                          controller: _passwordController,
                          hintText: 'Mot de passe',
                          icon: Icons.lock_outline,
                          obscureText: _obscurePassword,
                          suffixIcon: IconButton(
                            onPressed: _togglePasswordVisibility,
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: AppColors.darkGray.withOpacity(0.6),
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Confirm Password Field
                        _buildTextField(
                          controller: _confirmPasswordController,
                          hintText: 'Confirmer mot de passe',
                          icon: Icons.lock_outline,
                          obscureText: _obscureConfirmPassword,
                          suffixIcon: IconButton(
                            onPressed: _toggleConfirmPasswordVisibility,
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: AppColors.darkGray.withOpacity(0.6),
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Register Button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleRegister,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF59E0B),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    'S\'inscrire',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Login link
                        Center(
                          child: GestureDetector(
                            onTap: _isLoading
                                ? null
                                : () {
                                    Navigator.of(context).pushReplacement(
                                      MaterialPageRoute(
                                        builder: (context) => const LoginPage(),
                                      ),
                                    );
                                  },
                            child: RichText(
                              text: TextSpan(
                                text: 'Vous avez déjà un compte ? ',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: AppColors.darkGray.withOpacity(0.7),
                                  fontWeight: FontWeight.w400,
                                ),
                                children: [
                                  TextSpan(
                                    text: 'Se connecter',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: const Color(0xFFF9A826),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
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
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        prefixIcon: Container(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, color: const Color(0xFFF9A826), size: 20),
        ),
        suffixIcon: suffixIcon,
        hintText: hintText,
        hintStyle: GoogleFonts.poppins(
          color: AppColors.darkGray.withOpacity(0.5),
        ),
        filled: true,
        fillColor: AppColors.lightGray,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      style: GoogleFonts.poppins(fontSize: 16, color: AppColors.darkGray),
    );
  }
}
