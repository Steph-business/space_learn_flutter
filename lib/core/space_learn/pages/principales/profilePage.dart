import 'package:flutter/material.dart';

import '../../../themes/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:space_learn_flutter/core/utils/app_notifications.dart';
import '../../data/model/user_model.dart';
import '../../data/dataServices/authServices.dart';
import '../../../utils/token_storage.dart';
import '../../data/dataServices/favoriteService.dart';
import 'lecteur/favorites_page.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/profileService.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/profilModel.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/lecteur/accueil_lecteur_page.dart' as lecteurHome;
import 'package:space_learn_flutter/core/space_learn/pages/principales/ecrivain/accueil_auteur_page.dart' as ecrivainHome;
import 'package:space_learn_flutter/core/space_learn/pages/principales/auth/profil.dart';

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
  final FavoriteService _favoriteService = FavoriteService();
  final ProfileService _profileService = ProfileService();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _socialLinksController = TextEditingController();
  final TextEditingController _walletAddressController =
      TextEditingController();

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
    super.dispose();
  }

  // Contrôle de l'onboarding par étapes (Wizard)
  int _currentStep = 0;

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
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
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 250, 249, 246),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          "Informations personnelles",
          style: GoogleFonts.poppins(
            color: AppColors.primary,
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
            Stack(
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
                  child: const Icon(
                    Icons.person,
                    size: 60,
                    color: AppColors.primary,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Titre
            Text(
              "Informations personnelles",
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 30),

            // Formulaire
            _buildReadOnlyField(
              value: _user?.profilId ?? '',
              label: "ID Profil",
              icon: Icons.perm_identity,
            ),
            const SizedBox(height: 20),

            _buildTextField(
              controller: _nameController,
              label: "Nom complet",
              icon: Icons.person_outline,
            ),
            const SizedBox(height: 20),

            _buildTextField(
              controller: _emailController,
              label: "Adresse email",
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 20),

            _buildTextField(
              controller: _bioController,
              label: "Biographie",
              icon: Icons.edit_outlined,
              maxLines: 3,
            ),
            const SizedBox(height: 20),

            _buildTextField(
              controller: _socialLinksController,
              label: "Liens sociaux",
              icon: Icons.link,
            ),
            const SizedBox(height: 20),

            _buildTextField(
              controller: _walletAddressController,
              label: "Adresse portefeuille",
              icon: Icons.account_balance_wallet,
            ),
            const SizedBox(height: 20),

            // Statistiques
            _buildStatsSection(),
            const SizedBox(height: 30),

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
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      _cancelChanges();
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      "Annuler",
                      style: GoogleFonts.poppins(
                        color: AppColors.primary,
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
    final stepsCount = 3;
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: Stack(
        children: [
          // Arrière-plan dégradé
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.4,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.primary.withOpacity(0.15),
                    AppColors.scaffoldBackground,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
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
                  const SizedBox(height: 12),
                  // Barre de progression
                  Stack(
                    children: [
                      Container(
                        width: double.infinity,
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.white12,
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
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.4),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 36),

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
                                  color: Colors.white.withOpacity(0.15),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Text(
                                "Retour",
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        )
                      else
                        const SizedBox(),
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
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Liste cache pour les profils afin d'éviter les appels API constants
  List<ProfilModel> _profilesCache = [];

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
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Veuillez confirmer votre nom complet pour l'affichage de vos contributions.",
              style: GoogleFonts.poppins(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 36),
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
              isLecteur ? "Racontez-nous votre histoire (Optionnel)" : "Racontez-nous votre histoire",
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isLecteur 
                  ? "Décrivez brièvement qui vous êtes (facultatif pour les lecteurs). Vous pouvez passer à l'étape suivante."
                  : "Décrivez qui vous êtes. Vos lecteurs pourront en apprendre plus sur vous à travers cette biographie d'auteur.",
              style: GoogleFonts.poppins(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 36),
            _buildOnboardingTextField(
              controller: _bioController,
              label: isLecteur ? "Biographie (Optionnel)" : "Biographie",
              icon: Icons.article_rounded,
              maxLines: 4,
            ),
          ],
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isLecteur ? "Vos réseaux sociaux (Optionnel)" : "Vos réseaux sociaux",
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isLecteur
                  ? "Renseignez un lien vers vos profils sociaux si vous le souhaitez (LinkedIn, Twitter, Github, etc.)."
                  : "Renseignez votre site web ou lien vers vos profils sociaux pour que vos lecteurs puissent vous suivre.",
              style: GoogleFonts.poppins(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 36),
            _buildOnboardingTextField(
              controller: _socialLinksController,
              label: isLecteur ? "Liens sociaux (Optionnel)" : "Liens sociaux (URL)",
              icon: Icons.link_rounded,
              keyboardType: TextInputType.url,
            ),
          ],
        );
      default:
        return const SizedBox();
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
      style: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(color: Colors.white60, fontSize: 14),
        prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
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
      // Pour les lecteurs, la biographie est facultative
      if (!isLecteur && _bioController.text.trim().isEmpty) {
        AppNotifications.showSnackBar(
          context,
          message: "Veuillez écrire une courte biographie.",
          isError: true,
        );
        return;
      }
    } else if (_currentStep == 2) {
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
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.grey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _buildReadOnlyField({
    required String value,
    required String label,
    required IconData icon,
  }) {
    return TextFormField(
      initialValue: value,
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.grey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[100],
      ),
    );
  }

  Widget _buildStatsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Statistiques de lecture",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem("Livres lus", "24"),
              _buildStatItem("En cours", "3"),
              _buildStatItem(
                "Favorie",
                "$_favoritesCount",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const FavoritesPage(),
                    ),
                  ).then(
                    (_) => _loadUserProfile(),
                  ); // Refresh count when coming back
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _saveProfile() async {
    final name = _nameController.text.trim();
    final bio = _bioController.text.trim();
    final social = _socialLinksController.text.trim();
    final wallet = _walletAddressController.text.trim();

    if (name.isEmpty) {
      AppNotifications.showSnackBar(
        context,
        message: "Le nom complet est obligatoire.",
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
        if (role.contains("lecteur")) {
          destination = lecteurHome.HomePageLecteur(
            profileId: profilId,
            userName: updatedUser.nomComplet,
          );
        } else if (role.contains("auteur") ||
            role.contains("administrateur") ||
            role.contains("éditeur")) {
          destination = ecrivainHome.HomePageAuteur(
            profileId: profilId,
            userName: updatedUser.nomComplet,
          );
        } else {
          destination = const ProfilPage();
        }

        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => destination),
            (route) => false,
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
            _favoritesCount = favs.length;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _cancelChanges() {
    if (_user != null) {
      _nameController.text = _user!.nomComplet;
      _emailController.text = _user!.email;
      _bioController.text = _user!.biography ?? '';
      _socialLinksController.text = _user!.socialLinks ?? '';
      _walletAddressController.text = _user!.walletAddress ?? '';
    }
  }
}
