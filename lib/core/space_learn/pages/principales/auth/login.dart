import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:developer' as developer;
import 'package:space_learn_flutter/core/space_learn/data/dataSources/authServices.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/auth/register.dart';
import '../../../../themes/app_colors.dart';
import 'forgot_password.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/auth/profil.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/lecteur/homePageLecteur.dart'
    as lecteurHome;
import 'package:space_learn_flutter/core/space_learn/pages/principales/ecrivain/homePageEcrivain.dart'
    as ecrivainHome;
import 'package:space_learn_flutter/core/space_learn/data/dataSources/profileService.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/profilModel.dart';

class LoginPage extends StatefulWidget {
  final String? initialEmail;
  final String? initialPassword;
  const LoginPage({super.key, this.initialEmail, this.initialPassword});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _rememberMe = false;
  final _authService = AuthService();
  final _profileService = ProfileService();

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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _togglePasswordVisibility() {
    setState(() {
      _obscurePassword = !_obscurePassword;
    });
  }

  void _handleLogin() async {
    if (_isLoading) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    developer.log(
      'Début de _handleLogin pour email: $email',
      name: 'LoginPage',
    );

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez remplir tous les champs.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      developer.log('Appel de _authService.login...', name: 'LoginPage');
      final tokenUser = await _authService.login(email, password);

      // On récupère dynamiquement les profils pour la comparaison
      // final allProfiles = await _profileService.getProfils();
      // developer.log('All profiles: $allProfiles', name: 'LoginPage');
      // developer.log('User profilId: ${tokenUser.user.profilId}', name: 'LoginPage');
      // final userProfile = allProfiles.firstWhere(
      //   (p) => p.id == tokenUser.user.profilId,
      //   orElse: () =>
      //       ProfilModel(id: '', libelle: ''), // Profil par défaut si non trouvé
      // );
      // developer.log('User profile found: ${userProfile.libelle}', name: 'LoginPage');

      // Temporary: assume lecteur profile
      final userProfile = ProfilModel(
        id: tokenUser.user.profilId,
        libelle: 'Lecteur',
      );

      if (mounted) {
        Widget targetPage;
        final profileName = userProfile.libelle.toLowerCase();

        developer.log(
          'Profil utilisateur détecté: ${userProfile.libelle}',
          name: 'LoginPage',
        );

        if (profileName.contains('lecteur')) {
          targetPage = lecteurHome.HomePageLecteur(
            profileId: tokenUser.user.profilId,
            userName: tokenUser.user.nomComplet,
          );
          developer.log('Redirection vers homePageLecteur.', name: 'LoginPage');
        } else if (profileName.contains('Auteur') ||
            profileName.contains('Administrateur')) {
          targetPage = const ecrivainHome.HomePageEcrivain();
          developer.log(
            'Redirection vers homePageEcrivain.',
            name: 'LoginPage',
          );
        } else {
          // Si le profil n'est pas reconnu ou si l'utilisateur n'a pas de profil
          // on le redirige vers la page de sélection de profil.
          // targetPage = const ProfilPage();
          // developer.log(
          //   'Profil non reconnu ou manquant. Redirection vers ProfilPage.',
          //   name: 'LoginPage',
          // );
          // Pour l'instant, rediriger vers une page par défaut ou afficher une erreur
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profil non reconnu. Contactez le support.')),
          );
          return;
        }

        Navigator.of(
          context,
        ).pushReplacement(MaterialPageRoute(builder: (context) => targetPage));
      }
    } catch (e) {
      developer.log(
        "Erreur lors de la connexion: $e",
        name: 'LoginPage',
        error: e,
        level: 1000,
      ); // SEVERE
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur de connexion: ${e.toString()}")),
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

  void _handleGoogleLogin() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });

    try {
      // Simulate Google login process
      await Future.delayed(const Duration(seconds: 2));

      // TODO: Implémentez la vraie logique de connexion Google ici.
      // Après une connexion réussie, vous obtiendrez les informations de l'utilisateur
      // et vous pourrez le rediriger vers la page de sélection de profil ou la page d'accueil.

      if (mounted) {
        // Pour la simulation, nous naviguons vers la page de profil.
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const ProfilPage()),
        );
      }
    } catch (e) {
      // Gérer les erreurs de connexion Google
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
              Color(0xFFFFB453), // Purple
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
                  // Lock Icon
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
                      Icons.lock_outline,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Title
                  Text(
                    'Connexion',
                    style: GoogleFonts.poppins(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Subtitle
                  Text(
                    'Bon retour parmi nous !',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                      fontWeight: FontWeight.w400,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 20),

                  // Login Form Card
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
                        const SizedBox(height: 8),

                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            prefixIcon: Container(
                              padding: const EdgeInsets.all(12),
                              child: const Icon(
                                Icons.email_outlined,
                                color: Color(0xFFF9A826),
                                size: 20,
                              ),
                            ),
                            hintText: 'example@gmail.com',
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
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: AppColors.darkGray,
                          ),
                        ),

                        const SizedBox(height: 16),

                        const SizedBox(height: 8),

                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            prefixIcon: Container(
                              padding: const EdgeInsets.all(12),
                              child: const Icon(
                                Icons.lock_outline,
                                color: Color(0xFFF9A826),
                                size: 20,
                              ),
                            ),
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
                            hintText: 'Votre mot de passe',
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
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: AppColors.darkGray,
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Remember me & Forgot Password
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: Checkbox(
                                    value: _rememberMe,
                                    onChanged: (value) {
                                      setState(() {
                                        _rememberMe = value ?? false;
                                      });
                                    },
                                    activeColor: const Color(0xFFF9A826),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Se souvenir de moi',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: AppColors.darkGray,
                                  ),
                                ),
                              ],
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const ForgotPasswordPage(),
                                  ),
                                );
                              },
                              child: Text(
                                'Mot de passe oublié ?',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: const Color(0xFFF9A826),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Login Button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleLogin,
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
                                    'Se connecter',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Divider
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 1,
                                color: AppColors.darkGray.withOpacity(0.2),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Text(
                                'ou',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: AppColors.darkGray.withOpacity(0.6),
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Container(
                                height: 1,
                                color: AppColors.darkGray.withOpacity(0.2),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Google Login Button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: OutlinedButton(
                            onPressed: _isLoading ? null : _handleGoogleLogin,
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: AppColors.darkGray.withOpacity(0.3),
                                width: 1,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.darkGray,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Google Icon (using a simple colored circle for now)
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Center(
                                    child: Text(
                                      'G',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Continuer avec Google',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Sign up link
                        Center(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => const RegisterPage(),
                                ),
                              );
                            },
                            child: RichText(
                              text: TextSpan(
                                text: 'Vous n\'avez pas de compte ? ',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: AppColors.darkGray.withOpacity(0.7),
                                  fontWeight: FontWeight.w400,
                                ),
                                children: [
                                  TextSpan(
                                    text: 'S\'inscrire',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14, // F9A826
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
          ), // Center
        ), // SafeArea
      ),
    );
  }
}
