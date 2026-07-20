import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';

import '../../../themes/app_colors.dart';
import '../../../themes/app_text_styles.dart';
import '../../data/dataServices/favoriteService.dart';
import '../../data/dataServices/profileService.dart';
import '../../data/dataServices/authServices.dart';
import '../../data/dataServices/libraryService.dart';
import '../../data/model/user_model.dart';
import '../../data/model/profilModel.dart';
import '../../data/model/library_model.dart';
import '../../../utils/token_storage.dart';
import '../../../utils/app_notifications.dart';
import 'package:space_learn_flutter/core/utils/profile_image_helper.dart';
import 'lecteur/favorites_page.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/lecteur/accueil_lecteur_page.dart' as lecteurHome;
import 'package:space_learn_flutter/core/space_learn/pages/principales/ecrivain/accueil_auteur_page.dart' as ecrivainHome;
import 'package:space_learn_flutter/core/utils/profile_storage.dart';

class ProfilePage extends StatefulWidget {
  final bool forceComplete;
  const ProfilePage({super.key, this.forceComplete = false});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  UserModel? _user;
  bool _isLoading = true;
  int _favoritesCount = 0;
  int _libraryCount = 0;
  int _inProgressCount = 0;
  List<ProfilModel> _profilesCache = [];
  final FavoriteService _favoriteService = FavoriteService();
  final ProfileService _profileService = ProfileService();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _socialLinksController = TextEditingController();
  final TextEditingController _walletAddressController =
      TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  
  String? _selectedGender;
  String? _selectedAgeRange;

  final List<String> _genders = ["Homme", "Femme", "Autre", "Ne pas spécifier"];
  final List<String> _ageRanges = ["Moins de 18 ans", "18 à 25 ans", "26 à 35 ans", "36 à 50 ans", "Plus de 50 ans"];

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _bioController.dispose();
    _socialLinksController.dispose();
    _walletAddressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // Contrôle de l'onboarding par étapes (Wizard)
  int _currentStep = 0;

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.scaffoldBackground,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (widget.forceComplete) {
      return _buildOnboardingWizard();
    }

    return _buildStandardProfilePage();
  }

  Widget _buildStandardProfilePage() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.scaffoldBackground : Color.fromARGB(255, 250, 249, 246),
      appBar: AppBar(
        backgroundColor: AppColors.scaffoldBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          "Informations personnelles",
          style: GoogleFonts.poppins(
            color: isDark ? Colors.white : AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Photo de profil
            GestureDetector(
              onTap: _pickProfilePhoto,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withOpacity(0.1),
                      border: Border.all(color: AppColors.primary, width: 3),
                    ),
                    child: ClipOval(
                      child: ProfileImageHelper.buildProfileImage(
                        _user?.profilePhoto,
                        fallbackInitial: _user?.nomComplet.isNotEmpty == true
                            ? _user!.nomComplet.substring(0, 1).toUpperCase()
                            : "?",
                        textStyle: GoogleFonts.poppins(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                        width: 120,
                        height: 120,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.camera_alt,
                      color: AppColors.textPrimary,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),

            // Titre
            Text(
              "Informations personnelles",
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 30),

            // Formulaire
            _buildReadOnlyField(
              value: _user?.profilId ?? '',
              label: "ID Profil",
              icon: Icons.perm_identity,
            ),
            SizedBox(height: 20),

            _buildTextField(
              controller: _nameController,
              label: "Nom complet",
              icon: Icons.person_outline,
            ),
            SizedBox(height: 20),

            _buildTextField(
              controller: _emailController,
              label: "Adresse email",
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
            ),
            SizedBox(height: 20),

            _buildTextField(
              controller: _bioController,
              label: "Biographie",
              icon: Icons.edit_outlined,
              maxLines: 3,
            ),
            SizedBox(height: 20),

            _buildTextField(
              controller: _socialLinksController,
              label: "Liens sociaux",
              icon: Icons.link,
            ),
            SizedBox(height: 20),

            _buildTextField(
              controller: _walletAddressController,
              label: "Adresse portefeuille",
              icon: Icons.account_balance_wallet,
            ),
            SizedBox(height: 20),

            _buildTextField(
              controller: _phoneController,
              label: "Numéro de téléphone",
              icon: Icons.phone_android_outlined,
              keyboardType: TextInputType.phone,
            ),
            SizedBox(height: 20),

            DropdownButtonFormField<String>(
              value: _selectedGender,
              dropdownColor: AppColors.cardBackground,
              style: GoogleFonts.poppins(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: "Genre",
                labelStyle: GoogleFonts.poppins(color: isDark ? AppColors.textHint : Colors.black54),
                prefixIcon: Icon(Icons.person_outline, color: AppColors.primary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: isDark ? AppColors.textHint : Colors.grey),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: isDark ? AppColors.textHint : Colors.grey),
                ),
                filled: true,
                fillColor: AppColors.cardBackground,
              ),
              items: _genders.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (newValue) {
                setState(() {
                  _selectedGender = newValue;
                });
              },
            ),
            SizedBox(height: 20),

            DropdownButtonFormField<String>(
              value: _selectedAgeRange,
              dropdownColor: AppColors.cardBackground,
              style: GoogleFonts.poppins(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: "Tranche d'âge",
                labelStyle: GoogleFonts.poppins(color: isDark ? AppColors.textHint : Colors.black54),
                prefixIcon: Icon(Icons.cake_outlined, color: AppColors.primary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: isDark ? AppColors.textHint : Colors.grey),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: isDark ? AppColors.textHint : Colors.grey),
                ),
                filled: true,
                fillColor: AppColors.cardBackground,
              ),
              items: _ageRanges.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (newValue) {
                setState(() {
                  _selectedAgeRange = newValue;
                });
              },
            ),
            SizedBox(height: 20),

            // Statistiques
            _buildStatsSection(),
            SizedBox(height: 30),

            // Boutons d'action
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      _saveProfile();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      "Sauvegarder",
                      style: GoogleFonts.poppins(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      _cancelChanges();
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: isDark ? AppColors.textHint : AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      "Annuler",
                      style: GoogleFonts.poppins(
                        color: isDark ? AppColors.textSecondary : AppColors.primary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOnboardingWizard() {
    final stepsCount = 4;
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 10),
                  // En-tête de l'étape
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Étape ${_currentStep + 1} sur $stepsCount",
                        style: GoogleFonts.poppins(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  // Barre de progression
                  Stack(
                    children: [
                      Container(
                        width: double.infinity,
                        height: 6,
                        decoration: BoxDecoration(
                          color: AppColors.textHint,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: MediaQuery.of(context).size.width *
                            ((_currentStep + 1) / stepsCount) - 48,
                        height: 6,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(3),
                          
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 36),

                  // Contenu dynamique basé sur l'étape courante
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildStepContent(),
                        ],
                      ),
                    ),
                  ),

                  // Actions de navigation (Suivant / Précédent)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (_currentStep > 0)
                        Expanded(
                          child: Container(
                            height: 52,
                            margin: const EdgeInsets.only(right: 16),
                            child: OutlinedButton(
                              onPressed: () {
                                setState(() {
                                  _currentStep--;
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: AppColors.textPrimary.withOpacity(0.15),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Text(
                                "Retour",
                                style: GoogleFonts.poppins(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        )
                      else
                        SizedBox(),
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: () {
                              _handleStepNext(stepsCount);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              _currentStep == stepsCount - 1
                                  ? "Terminer"
                                  : "Suivant",
                              style: GoogleFonts.poppins(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    String role = '';
    if (_user != null && _profilesCache.isNotEmpty) {
      final userProfile = _profilesCache.firstWhere(
        (p) => p.id.trim().toLowerCase() == _user!.profilId.trim().toLowerCase(),
        orElse: () => ProfilModel(id: '', libelle: ''),
      );
      role = userProfile.libelle.toLowerCase();
    }
    final isLecteur = role.contains("lecteur");

    switch (_currentStep) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Commençons par votre nom",
              style: GoogleFonts.poppins(
                color: AppColors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              "Veuillez confirmer votre nom complet pour l'affichage de vos contributions.",
              style: GoogleFonts.poppins(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            SizedBox(height: 36),
            _buildOnboardingTextField(
              controller: _nameController,
              label: "Nom complet",
              icon: Icons.person_rounded,
            ),
          ],
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Quelques informations sur vous",
              style: GoogleFonts.poppins(
                color: AppColors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              "Ces informations nous aident à mieux vous connaître et à personnaliser vos recommandations.",
              style: GoogleFonts.poppins(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            SizedBox(height: 36),
            
            _buildOnboardingTextField(
              controller: _phoneController,
              label: "Numéro de téléphone",
              icon: Icons.phone_rounded,
              keyboardType: TextInputType.phone,
            ),
            SizedBox(height: 24),
            
            Text(
              "Genre",
              style: GoogleFonts.poppins(
                color: AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.textPrimary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.textPrimary.withOpacity(0.1)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedGender,
                  hint: Text(
                    "Sélectionnez votre genre",
                    style: GoogleFonts.poppins(color: AppColors.textHint, fontSize: 14),
                  ),
                  dropdownColor: AppColors.scaffoldBackground,
                  icon: Icon(Icons.arrow_drop_down, color: AppColors.primary),
                  isExpanded: true,
                  style: GoogleFonts.poppins(color: AppColors.textPrimary, fontSize: 16),
                  items: _genders.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    setState(() {
                      _selectedGender = newValue;
                    });
                  },
                ),
              ),
            ),
            SizedBox(height: 24),
            
            Text(
              "Tranche d'âge",
              style: GoogleFonts.poppins(
                color: AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.textPrimary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.textPrimary.withOpacity(0.1)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedAgeRange,
                  hint: Text(
                    "Sélectionnez votre tranche d'âge",
                    style: GoogleFonts.poppins(color: AppColors.textHint, fontSize: 14),
                  ),
                  dropdownColor: AppColors.scaffoldBackground,
                  icon: Icon(Icons.arrow_drop_down, color: AppColors.primary),
                  isExpanded: true,
                  style: GoogleFonts.poppins(color: AppColors.textPrimary, fontSize: 16),
                  items: _ageRanges.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    setState(() {
                      _selectedAgeRange = newValue;
                    });
                  },
                ),
              ),
            ),
          ],
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isLecteur ? "Racontez-nous votre histoire (Optionnel)" : "Racontez-nous votre histoire",
              style: GoogleFonts.poppins(
                color: AppColors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              isLecteur 
                  ? "Décrivez brièvement qui vous êtes (facultatif pour les lecteurs). Vous pouvez passer à l'étape suivante."
                  : "Décrivez qui vous êtes. Vos lecteurs pourront en apprendre plus sur vous à travers cette biographie d'auteur.",
              style: GoogleFonts.poppins(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            SizedBox(height: 36),
            _buildOnboardingTextField(
              controller: _bioController,
              label: isLecteur ? "Biographie (Optionnel)" : "Biographie",
              icon: Icons.article_rounded,
              maxLines: 4,
            ),
          ],
        );
      case 3:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isLecteur ? "Vos réseaux sociaux (Optionnel)" : "Vos réseaux sociaux",
              style: GoogleFonts.poppins(
                color: AppColors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              isLecteur
                  ? "Renseignez un lien vers vos profils sociaux si vous le souhaitez (LinkedIn, Twitter, Github, etc.)."
                  : "Renseignez votre site web ou lien vers vos profils sociaux pour que vos lecteurs puissent vous suivre.",
              style: GoogleFonts.poppins(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            SizedBox(height: 36),
            _buildOnboardingTextField(
              controller: _socialLinksController,
              label: isLecteur ? "Liens sociaux (Optionnel)" : "Liens sociaux (URL)",
              icon: Icons.link_rounded,
              keyboardType: TextInputType.url,
            ),
          ],
        );
      default:
        return SizedBox();
    }
  }

  Widget _buildOnboardingTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: GoogleFonts.poppins(color: AppColors.textPrimary, fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(color: AppColors.textHint, fontSize: 14),
        prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
        filled: true,
        fillColor: AppColors.textHint,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.textPrimary.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.primary, width: 1.8),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  void _handleStepNext(int stepsCount) {
    String role = '';
    if (_user != null && _profilesCache.isNotEmpty) {
      final userProfile = _profilesCache.firstWhere(
        (p) => p.id.trim().toLowerCase() == _user!.profilId.trim().toLowerCase(),
        orElse: () => ProfilModel(id: '', libelle: ''),
      );
      role = userProfile.libelle.toLowerCase();
    }
    final isLecteur = role.contains("lecteur");

    if (_currentStep == 0) {
      if (_nameController.text.trim().isEmpty) {
        AppNotifications.showSnackBar(
          context,
          message: "Veuillez saisir votre nom complet.",
          isError: true,
        );
        return;
      }
    } else if (_currentStep == 1) {
      if (_phoneController.text.trim().isEmpty || _selectedGender == null || _selectedAgeRange == null) {
        AppNotifications.showSnackBar(
          context,
          message: "Veuillez renseigner toutes vos informations personnelles (Téléphone, Genre, Tranche d'âge).",
          isError: true,
        );
        return;
      }
    } else if (_currentStep == 2) {
      // Pour les lecteurs, la biographie est facultative
      if (!isLecteur && _bioController.text.trim().isEmpty) {
        AppNotifications.showSnackBar(
          context,
          message: "Veuillez écrire une courte biographie.",
          isError: true,
        );
        return;
      }
    } else if (_currentStep == 3) {
      // Pour les lecteurs, le lien social est facultatif
      if (!isLecteur && _socialLinksController.text.trim().isEmpty) {
        AppNotifications.showSnackBar(
          context,
          message: "Veuillez renseigner un lien social.",
          isError: true,
        );
        return;
      }
      _saveProfile();
      return;
    }

    setState(() {
      _currentStep++;
    });
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: GoogleFonts.poppins(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(color: isDark ? AppColors.textHint : Colors.black54),
        prefixIcon: Icon(icon, color: AppColors.primary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? AppColors.textHint : Colors.grey),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? AppColors.textHint : Colors.grey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        filled: true,
        fillColor: AppColors.cardBackground,
      ),
    );
  }

  Widget _buildReadOnlyField({
    required String value,
    required String label,
    required IconData icon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextFormField(
      initialValue: value,
      readOnly: true,
      style: GoogleFonts.poppins(color: isDark ? AppColors.textHint : Colors.black54),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(color: isDark ? AppColors.textHint : Colors.black38),
        prefixIcon: Icon(icon, color: AppColors.primary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? AppColors.textHint : AppColors.textSecondary),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? AppColors.textHint : AppColors.textSecondary),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? AppColors.textHint : AppColors.textSecondary),
        ),
        filled: true,
        fillColor: isDark ? AppColors.cardBackground.withOpacity(0.5) : Colors.grey[100],
      ),
    );
  }

  Widget _buildStatsSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Statistiques de lecture",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem("Livres lus", "$_libraryCount"),
              _buildStatItem("En cours", "$_inProgressCount"),
              _buildStatItem(
                "Favoris",
                "$_favoritesCount",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const FavoritesPage(),
                    ),
                  ).then(
                    (_) => _loadUserProfile(),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, {VoidCallback? onTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: isDark ? AppColors.textHint : Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _pickProfilePhoto() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (image == null) return;

      setState(() {
        _isLoading = true;
      });

      String? photoUrl;
      try {
        final bytes = await image.readAsBytes();
        final fileName = '${_user?.id ?? DateTime.now().millisecondsSinceEpoch}.jpg';
        
        await Supabase.instance.client.storage
            .from('avatars')
            .uploadBinary(
              fileName,
              bytes,
              fileOptions: const FileOptions(
                contentType: 'image/jpeg',
                upsert: true,
              ),
            );
            
        photoUrl = Supabase.instance.client.storage
            .from('avatars')
            .getPublicUrl(fileName);
      } catch (storageError) {
        try {
          final bytes = await image.readAsBytes();
          final base64String = base64Encode(bytes);
          final extension = image.path.split('.').last;
          photoUrl = 'data:image/$extension;base64,$base64String';
        } catch (_) {
          AppNotifications.showSnackBar(context, message: "Erreur lors du traitement de l'image.", isError: true);
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }

      if (photoUrl != null) {
        final token = await TokenStorage.getToken();
        if (token != null) {
          final authService = AuthService();
          final updatedUser = await authService.updateProfileDetails(
            userId: _user!.id,
            profilePhoto: photoUrl,
          );
          if (updatedUser != null) {
            AppNotifications.showSnackBar(context, message: "Photo de profil mise à jour !", isSuccess: true);
            await _loadUserProfile();
          } else {
            AppNotifications.showSnackBar(context, message: "Impossible de mettre à jour le profil sur le serveur.", isError: true);
          }
        }
      }
    } catch (e) {
      AppNotifications.showSnackBar(context, message: "Une erreur est survenue.", isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _saveProfile() async {
    final name = _nameController.text.trim();
    final bio = _bioController.text.trim();
    final social = _socialLinksController.text.trim();
    final wallet = _walletAddressController.text.trim();
    final phone = _phoneController.text.trim();
    final gender = _selectedGender;
    final ageRange = _selectedAgeRange;

    if (name.isEmpty) {
      AppNotifications.showSnackBar(
        context,
        message: "Le nom complet est obligatoire.",
        isError: true,
      );
      return;
    }

    if (phone.isEmpty || gender == null || ageRange == null) {
      AppNotifications.showSnackBar(
        context,
        message: "Veuillez renseigner toutes vos informations personnelles (Téléphone, Genre, Tranche d'âge).",
        isError: true,
      );
      return;
    }

    if (widget.forceComplete) {
      String role = '';
      if (_profilesCache.isNotEmpty && _user != null) {
        final userProfile = _profilesCache.firstWhere(
          (p) => p.id.trim().toLowerCase() == _user!.profilId.trim().toLowerCase(),
          orElse: () => ProfilModel(id: '', libelle: ''),
        );
        role = userProfile.libelle.toLowerCase();
      }
      final isLecteur = role.contains("lecteur");

      if (!isLecteur) {
        if (bio.isEmpty || social.isEmpty) {
          AppNotifications.showSnackBar(
            context,
            message: "Veuillez renseigner toutes vos informations (Biographie et Réseaux sociaux).",
            isError: true,
          );
          return;
        }
      }
    }

    String? dobString;
    if (ageRange != null) {
      int age = 20;
      if (ageRange == "Moins de 18 ans") {
        age = 15;
      } else if (ageRange == "18 à 25 ans") {
        age = 21;
      } else if (ageRange == "26 à 35 ans") {
        age = 30;
      } else if (ageRange == "36 à 50 ans") {
        age = 43;
      } else if (ageRange == "Plus de 50 ans") {
        age = 60;
      }
      final dob = DateTime(DateTime.now().year - age, 1, 1);
      dobString = dob.toUtc().toIso8601String();
    }

    if (_user == null) return;
    setState(() => _isLoading = true);

    try {
      final authService = AuthService();
      final updatedUser = await authService.updateProfileDetails(
        userId: _user!.id,
        nomComplet: name,
        biography: bio,
        socialLinks: social,
        walletAddress: wallet,
        telephone: phone,
        sexe: gender,
        dateNaissance: dobString,
      );

      if (!mounted) return;

      AppNotifications.showSnackBar(
        context,
        message: 'Profil mis à jour avec succès !',
        isSuccess: true,
      );

      setState(() {
        _user = updatedUser;
        _isLoading = false;
      });

      if (widget.forceComplete) {
        final profilId = updatedUser.profilId;
        final allProfiles = await _profileService.getProfils();
        final userProfile = allProfiles.firstWhere(
          (p) => p.id.trim().toLowerCase() == profilId.trim().toLowerCase(),
          orElse: () => ProfilModel(id: '', libelle: ''),
        );

        Widget destination;
        final role = userProfile.libelle.toLowerCase();
        await ProfileStorage.saveSelectedProfileRole(role);
        if (role.contains("lecteur")) {
          destination = lecteurHome.HomePageLecteur(
            profileId: profilId,
            userName: updatedUser.nomComplet,
          );
        } else if (role.contains("auteur") ||
            role.contains("administrateur") ||
            role.contains("éditeur")) {
          destination = ecrivainHome.HomePageAuteur(
            key: ecrivainHome.HomePageAuteur.navKey,
            profileId: profilId,
            userName: updatedUser.nomComplet,
          );
        } else {
          destination = const ProfilePage();
        }

        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => destination),
            (route) => false,
          );
        }
      } else {
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        AppNotifications.showSnackBar(
          context,
          message: "Erreur: ${e.toString().replaceAll("Exception: ", "")}",
          isError: true,
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      final token = await TokenStorage.getToken();
      if (token != null) {
        final authService = AuthService();
        final user = await authService.getUser(token);
        final favs = await _favoriteService.getFavorites(token);
        final libraryService = LibraryService();
        List<LibraryModel> libBooks = [];
        try {
          libBooks = await libraryService.getUserLibrary(token);
        } catch (_) {}
        
        // Charger les profils en cache
        List<ProfilModel> profils = [];
        try {
          profils = await _profileService.getProfils();
        } catch (_) {}

        if (user != null && mounted) {
          setState(() {
            _user = user;
            _profilesCache = profils;
            _nameController.text = user.nomComplet;
            _emailController.text = user.email;
            _bioController.text = user.biography ?? '';
            _socialLinksController.text = user.socialLinks ?? '';
            _walletAddressController.text = user.walletAddress ?? '';
            _phoneController.text = user.telephone ?? '';
            _selectedGender = user.sexe;
            
            if (user.dateNaissance != null) {
              final age = DateTime.now().year - user.dateNaissance!.year;
              if (age < 18) {
                _selectedAgeRange = "Moins de 18 ans";
              } else if (age >= 18 && age <= 25) {
                _selectedAgeRange = "18 à 25 ans";
              } else if (age >= 26 && age <= 35) {
                _selectedAgeRange = "26 à 35 ans";
              } else if (age >= 36 && age <= 50) {
                _selectedAgeRange = "36 à 50 ans";
              } else {
                _selectedAgeRange = "Plus de 50 ans";
              }
            } else {
              _selectedAgeRange = null;
            }
            
            _favoritesCount = favs.length;
            _libraryCount = libBooks.length;
            
            int inProgress = libBooks.where((b) {
              final progressions = b.livre?.progressions;
              if (progressions != null && progressions.isNotEmpty) {
                final percentage = progressions.first.pourcentage;
                return percentage > 0 && percentage < 100;
              }
              return false;
            }).length;
            if (_libraryCount > 0 && inProgress == 0) {
              inProgress = 1;
            }
            _inProgressCount = inProgress;
            
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _cancelChanges() {
    if (_user != null) {
      _nameController.text = _user!.nomComplet;
      _emailController.text = _user!.email;
      _bioController.text = _user!.biography ?? '';
      _socialLinksController.text = _user!.socialLinks ?? '';
      _walletAddressController.text = _user!.walletAddress ?? '';
      _phoneController.text = _user!.telephone ?? '';
      _selectedGender = _user!.sexe;
      
      if (_user!.dateNaissance != null) {
        final age = DateTime.now().year - _user!.dateNaissance!.year;
        if (age < 18) {
          _selectedAgeRange = "Moins de 18 ans";
        } else if (age >= 18 && age <= 25) {
          _selectedAgeRange = "18 à 25 ans";
        } else if (age >= 26 && age <= 35) {
          _selectedAgeRange = "26 à 35 ans";
        } else if (age >= 36 && age <= 50) {
          _selectedAgeRange = "36 à 50 ans";
        } else {
          _selectedAgeRange = "Plus de 50 ans";
        }
      } else {
        _selectedAgeRange = null;
      }
    }
    AppNotifications.showSnackBar(context, message: "Modifications annulées.");
    Navigator.of(context).pop();
  }
}