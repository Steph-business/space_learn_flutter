import 'package:flutter/material.dart';

import 'package:space_learn_flutter/core/space_learn/data/model/profilModel.dart';
import '../../../../themes/app_colors.dart';
import '../../../data/dataServices/authServices.dart';
import '../../../data/dataServices/profileService.dart';
import 'register.dart';

class ProfilPage extends StatefulWidget {
  const ProfilPage({super.key});

  @override
  _ProfilPageState createState() => _ProfilPageState();
}

class _ProfilPageState extends State<ProfilPage> {
  bool isLoading = true;
  bool isUpdating = false;
  String? error;
  List<ProfilModel> _profiles = [];
  final _profileService = ProfileService();
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  /// ✅ Charge les profils depuis le backend via ProfileService
  Future<void> _loadProfiles() async {
    try {
      final profiles = await _profileService.getProfils();
      if (mounted) {
        setState(() {
          _profiles = profiles;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
          isLoading = false;
        });
      }
    }
  }

  /// ✅ Sélectionne un profil
  Future<void> _selectProfile(String profileId, String profileName) async {
    if (isUpdating) return;
    setState(() {
      isUpdating = true;
      error = null;
    });

    // Temporarily commented out server update for profile selection
    /*
    try {
      // Check if user is authenticated
      final token = await TokenStorage.getToken();
      if (token != null && token.isNotEmpty) {
        // Authenticated: update profile on server
        try {
          final updatedTokenUser = await _authService.updateProfileForUser(
            profileId,
          );

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Profil "$profileName" mis à jour avec succès !'),
            ),
          );

          // Redirect to the correct home page based on the new profile
          Widget targetPage;
          final newProfileName = profileName.toLowerCase();
          if (newProfileName.contains('lecteur')) {
            targetPage = lecteurHome.HomePageLecteur(
              profileId: updatedTokenUser.user.profilId,
              userName: updatedTokenUser.user.nomComplet,
            );
          } else if (newProfileName.contains('auteur') ||
              newProfileName.contains('ecrivain') ||
              newProfileName.contains('éditeur')) {
            targetPage = const ecrivainHome.HomePageAuteur();
          } else {
            targetPage = const ProfilPage(); // Fallback
          }

          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => targetPage),
            (Route<dynamic) route) => false,
          );
        } catch (e) {
          // If token is invalid, clear it and treat as unauthenticated
          if (e.toString().contains('Invalid token')) {
            await TokenStorage.clearToken();
            // Proceed as unauthenticated
            await _profileService.saveSelectedProfile(profileId);

            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Profil "$profileName" sélectionné. Veuillez maintenant vous inscrire.',
                ),
              ),
            );

            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const RegisterPage()),
            );
          } else {
            // Other errors
            if (mounted) {
              setState(() {
                error = "Erreur: ${e.toString()}";
              });
            }
          }
        }
      } else {
        // Not authenticated: save locally and navigate to auth choice
        await _profileService.saveSelectedProfile(profileId);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Profil "$profileName" sélectionné. Veuillez maintenant vous inscrire.',
            ),
          ),
        );

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const RegisterPage()),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = "Erreur: ${e.toString()}";
        });
      }
    } finally {
      setState(() => isUpdating = false);
    }
    */

    // Always save the selected profile and go to registration first
    // The home page redirection will happen after login, not after profile selection
    await _profileService.saveSelectedProfile(profileId);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Profil "$profileName" sélectionné. Veuillez maintenant vous inscrire.',
        ),
      ),
    );

    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const RegisterPage()));

    setState(() => isUpdating = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 40.0,
            ),
            child: Column(
              children: [
                // Rocket Icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.rocket_launch,
                    size: 40,
                    color: AppColors.primary,
                  ),
                ),

                const SizedBox(height: 32),

                // Title
                Text(
                  'SPACE LEARN',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 2.0,
                    fontFamily: 'Arial',
                  ),
                ),

                const SizedBox(height: 8),

                // Subtitle
                Text(
                  'Votre bibliothèque numérique intelligente',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w400,
                    fontFamily: 'Arial',
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 60),

                // Question principale
                Text(
                  'Qui êtes-vous ?',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontFamily: 'Arial',
                  ),
                ),

                const SizedBox(height: 16),

                // Sous-titre
                Text(
                  'Choisissez votre profil pour une expérience personnalisée',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.8),
                    fontWeight: FontWeight.w400,
                    fontFamily: 'Arial',
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 60),

                if (isLoading || isUpdating)
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  )
                else if (error != null)
                  Text(error!, style: const TextStyle(color: Colors.red))
                else if (_profiles.isEmpty)
                  const Text(
                    'Aucun profil disponible.',
                    style: TextStyle(color: Colors.white),
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.8,
                        ),
                    itemCount: _profiles.length,
                    itemBuilder: (context, index) {
                      final profile = _profiles[index];

                      return _buildProfileCard(
                        context,
                        icon: _getIconForProfile(profile.libelle),
                        description: _getDescriptionForProfile(profile.libelle),
                        title: ' ${profile.libelle}',
                        onTap: () =>
                            _selectProfile(profile.id, profile.libelle),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getIconForProfile(String libelle) {
    final profileName = libelle.toLowerCase();
    if (profileName.contains('lecteur')) {
      return Icons.menu_book;
    }
    if (profileName.contains('auteur') || profileName.contains('éditeur')) {
      return Icons.edit;
    }
    if (profileName.contains('administrateur')) {
      return Icons.admin_panel_settings;
    }
    // Icône par défaut pour les autres profils
    return Icons.person;
  }

  String _getDescriptionForProfile(String libelle) {
    final profileName = libelle.toLowerCase();
    if (profileName.contains('lecteur')) {
      return 'Découvrir et lire\ndes livres';
    }
    if (profileName.contains('auteur') || profileName.contains('éditeur')) {
      return 'Publier et vendre\nmes œuvres';
    }
    if (profileName.contains('administrateur')) {
      return 'Gérer la plateforme\net les utilisateurs';
    }
    // Description par défaut
    return 'Accéder à la\nplateforme';
  }

  Widget _buildProfileCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, size: 30, color: AppColors.primary),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.darkGray,
                height: 1.3,
                fontFamily: 'Arial',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // Description
            Text(
              description,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.darkGray.withOpacity(0.7),
                fontWeight: FontWeight.w400,
                height: 1.3,
                fontFamily: 'Arial',
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
