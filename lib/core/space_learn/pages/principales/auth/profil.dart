import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/themes/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:space_learn_flutter/core/utils/app_notifications.dart';

import 'package:space_learn_flutter/core/space_learn/data/model/profilModel.dart';
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

  Future<void> _selectProfile(String profileId, String profileName) async {
    if (isUpdating) return;
    setState(() {
      isUpdating = true;
      error = null;
    });

    await _profileService.saveSelectedProfile(profileId);

    if (!mounted) return;
    AppNotifications.showSnackBar(
      context,
      message: 'Profil "$profileName" sélectionné. Complétez votre inscription.',
      isSuccess: true,
    );

    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const RegisterPage()),
    );

    setState(() => isUpdating = false);
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
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 32.0,
              ),
              child: Column(
                children: [
                  // Back button if can pop
                  if (Navigator.of(context).canPop())
                    Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
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
                            size: 16,
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Rocket Icon
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withOpacity(0.15),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.rocket_launch,
                      size: 32,
                      color: AppColors.primary,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Brand
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Space',
                          style: GoogleFonts.poppins(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 1,
                          ),
                        ),
                        TextSpan(
                          text: 'Learn',
                          style: GoogleFonts.poppins(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Subtitle
                  Text(
                    'Votre bibliothèque numérique intelligente',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.65),
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 48),

                  // Question
                  Text(
                    'Qui êtes-vous ?',
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'Choisissez votre profil pour une\nexpérience personnalisée',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.6),
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 40),

                  if (isLoading || isUpdating)
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                    )
                  else if (error != null)
                    Text(
                      error!,
                      style: GoogleFonts.poppins(
                        color: Colors.redAccent,
                        fontSize: 13,
                      ),
                    )
                  else if (_profiles.isEmpty)
                    Text(
                      'Aucun profil disponible.',
                      style: AppTextStyles.bodySecondary14,
                    )
                  else
                    Row(
                      children: _getFilteredProfiles().map((profile) {
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: _buildProfileCard(
                              context,
                              icon: _getIconForProfile(profile.libelle),
                              description: _getDescriptionForProfile(
                                profile.libelle,
                              ),
                              title: profile.libelle,
                              onTap: () =>
                                  _selectProfile(profile.id, profile.libelle),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<ProfilModel> _getFilteredProfiles() {
    final seen = <String>{};
    return _profiles.where((p) {
      final name = p.libelle.toLowerCase();
      final isRelevant = name.contains('lecteur') || name.contains('auteur');
      if (isRelevant && !seen.contains(name)) {
        seen.add(name);
        return true;
      }
      return false;
    }).toList();
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
    return Icons.person;
  }

  String _getDescriptionForProfile(String libelle) {
    final profileName = libelle.toLowerCase();
    if (profileName.contains('lecteur')) {
      return 'Lire et explorer';
    }
    if (profileName.contains('auteur') || profileName.contains('éditeur')) {
      return 'Publier et instruire';
    }
    if (profileName.contains('administrateur')) {
      return 'Gérer la plateforme';
    }
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 22, color: AppColors.primary),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: AppTextStyles.cardTitleW700,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              description.replaceAll('\n', ' '),
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.white.withOpacity(0.5),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
