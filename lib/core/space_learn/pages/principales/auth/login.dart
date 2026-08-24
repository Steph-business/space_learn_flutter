import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/themes/app_text_styles.dart';
import 'package:space_learn_flutter/core/utils/app_notifications.dart';
import 'package:space_learn_flutter/core/services/google_auth_service.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/tokenUser.dart';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:space_learn_flutter/core/themes/app_dimensions.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/auth/widgets/en_tete_auth.dart';

import 'package:google_fonts/google_fonts.dart';

import 'package:space_learn_flutter/core/space_learn/data/dataServices/authServices.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/profileService.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/profilModel.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/auth/forgot_password.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/auth/otp.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/auth/profil.dart';
import 'package:space_learn_flutter/core/utils/profile_storage.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/profilePage.dart';

import 'package:space_learn_flutter/core/space_learn/pages/principales/lecteur/accueil_lecteur_page.dart'
    as lecteurHome;
import 'package:space_learn_flutter/core/space_learn/pages/principales/ecrivain/accueil_auteur_page.dart'
    as ecrivainHome;
import 'package:space_learn_flutter/core/utils/message_erreur.dart';

class LoginPage extends StatefulWidget {
  final String? initialEmail;
  final String? initialPassword;
  final bool isFirstTimeRegistration;
  const LoginPage({
    super.key,
    this.initialEmail,
    this.initialPassword,
    this.isFirstTimeRegistration = false,
  });

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
    _loadSavedEmail();
  }

  Future<void> _loadSavedEmail() async {
    if (widget.initialEmail != null) {
      _emailController.text = widget.initialEmail!;
    } else {
      final savedEmail = await ProfileStorage.getSavedEmail();
      if (savedEmail != null && mounted) {
        setState(() {
          _emailController.text = savedEmail;
        });
      }
    }
    if (widget.initialPassword != null) {
      _passwordController.text = widget.initialPassword!;
    }
  }

  Future<void> _acheminerApresConnexion(
    TokenUser tokenUser, {
    String? emailAMemoriser,
  }) async {
    final profilId = tokenUser.user.profilId;
    if (profilId.isEmpty) {
      throw Exception("Profil ID non reçu du backend.");
    }

    await _profileService.saveSelectedProfile(profilId);
    final allProfiles = await _profileService.getProfils();

    final userProfile = allProfiles.firstWhere(
      (p) => p.id.trim().toLowerCase() == profilId.trim().toLowerCase(),
      orElse: () => ProfilModel(id: '', libelle: ''),
    );

    if (!mounted) return;

    if (userProfile.id.isEmpty) {
      AppNotifications.showSnackBar(
        context,
        message: "Aucun profil correspondant trouvé pour l'ID : $profilId",
        isError: true,
      );
      setState(() => _isLoading = false);
      return;
    }

    final role = userProfile.libelle.toLowerCase();
    await ProfileStorage.saveSelectedProfileRole(role);
    await ProfileStorage.saveIsRegisteredUser(true);
    if (emailAMemoriser != null && emailAMemoriser.isNotEmpty) {
      await ProfileStorage.saveSavedEmail(emailAMemoriser);
    }

    if (!mounted) return;

    if (widget.isFirstTimeRegistration && !tokenUser.user.isProfileComplete) {
      AppNotifications.showSnackBar(
        context,
        message:
            "Bienvenue sur SpaceLearn ! Veuillez compléter votre profil pour accéder à l'application.",
        isSuccess: true,
      );
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const ProfilePage(forceComplete: true),
        ),
        (route) => false,
      );
      return;
    }

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
        key: ecrivainHome.HomePageAuteur.navKey,
        profileId: profilId,
        userName: tokenUser.user.nomComplet,
      );
    } else {
      destination = const ProfilPage();
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => destination),
      (route) => false,
    );
  }

  /// Connexion par compte Google.
  ///
  /// Remplace un appel à Supabase.signInWithOAuth, qui ne pouvait pas aboutir
  /// ici : il authentifiait auprès de Supabase, alors que les sessions de
  /// l'application sont émises par space_learn_auth. Une session Supabase ne
  /// donne aucun jeton utilisable sur nos routes métier — et le schéma de
  /// retour io.supabase.spacelearn:// n'était même pas déclaré au manifeste,
  /// donc le navigateur ne revenait jamais à l'application.
  Future<void> _connexionGoogle() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      // Le compte précédent est oublié avant d'ouvrir le sélecteur : sinon
      // Google reconnecte silencieusement le même, et on ne peut plus en
      // changer sur un appareil partagé.
      await GoogleAuthService.oublierLeCompte();
      final jeton = await GoogleAuthService.obtenirJetonIdentite();
      final tokenUser = await _authService.connexionGoogle(jeton);
      await _acheminerApresConnexion(tokenUser);
    } on ErreurGoogle catch (e) {
      // Fermer le sélecteur n'est pas un échec : rien à signaler.
      if (!e.annulee && mounted) {
        AppNotifications.showSnackBar(
          context,
          message: e.message,
          isError: true,
        );
      }
    } catch (e) {
      developer.log('Connexion Google : $e');
      if (mounted) {
        AppNotifications.showSnackBar(
          context,
          message: messageLisible(e, repli: "Connexion Google impossible."),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      AppNotifications.showSnackBar(
        context,
        message: "Veuillez remplir tous les champs.",
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      developer.log('Tentative de connexion avec $email');
      final tokenUser = await _authService.login(email, password);

      await _acheminerApresConnexion(tokenUser, emailAMemoriser: email);
    } catch (e) {
      developer.log("Erreur lors de la connexion : $e");
      if (!mounted) return;
      final errorStr = e.toString();
      // Le type d'abord, la sous-chaîne ensuite.
      //
      // Le test portait sur le texte du message : reformuler la phrase côté
      // serveur coupait la redirection sans qu'aucune compilation ne bronche.
      // Le repli textuel reste, pour les serveurs qui ne renvoient pas encore
      // `verified` — le téléphone se met à jour avant le serveur, pas après.
      final nonVerifie = e is CompteNonVerifieException;
      // `contains("403")` ne peut rien attraper : messageDeLaReponse ne laisse
      // jamais le nombre dans la chaîne. On garde le seul repli qui marche.
      if (nonVerifie || errorStr.contains("n'est pas encore vérifié")) {
        // Ne rien annoncer qui ne se soit pas produit : quand l'envoi a
        // échoué, l'écran promettait un courriel qui n'était jamais parti, et
        // la personne attendait devant sa boîte.
        final codeEnvoye = !nonVerifie || e.codeEnvoye;
        AppNotifications.showPremiumDialog(
          context,
          title: "Vérification requise",
          message: codeEnvoye
              ? "Votre adresse e-mail n'a pas encore été validée. Un nouveau code OTP de validation vous a été envoyé."
              : "Votre adresse e-mail n'a pas encore été validée. Le code n'a pas pu être envoyé : demandez-en un nouveau depuis l'écran de vérification.",
          confirmText: "Vérifier maintenant",
          isSuccess: false,
          onConfirm: () {
            if (mounted) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) =>
                      OtpPage(email: email, isFromRegistration: true),
                ),
              );
            }
          },
        );
      } else {
        AppNotifications.showSnackBar(
          context,
          message: messageLisible(
            e,
            repli: "Connexion impossible pour le moment.",
          ),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    AppColors.suivreLeTheme(context);
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
            child: LayoutBuilder(
              builder: (context, contraintes) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(28, 12, 28, 12),
                  // Le contenu était collé en haut de l'écran, avec le vide
                  // en dessous. Les deux Spacer le recentrent quand la place
                  // le permet, et s'effacent quand il faut défiler.
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: (contraintes.maxHeight - 24).clamp(
                        0,
                        double.infinity,
                      ),
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        children: [
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
                                  color: AppColors.textPrimary.withOpacity(
                                    0.15,
                                  ),
                                  border: Border.all(
                                    color: AppColors.textPrimary.withOpacity(
                                      0.3,
                                    ),
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

                          const Spacer(flex: 2),

                          const EnTeteAuth(
                            accroche:
                                'Votre bibliothèque numérique intelligente',
                          ),

                          const SizedBox(height: AppDimensions.spaceXl),

                          // Même disposition qu'à l'inscription : libellé au-dessus,
                          // champ sur toute la largeur. La colonne de libellé fixe de
                          // 110 px ne laissait pas la place d'afficher une invite
                          // complète.
                          Container(
                            padding: const EdgeInsets.all(
                              AppDimensions.cardPadding,
                            ),
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
                                Text(
                                  'E-mail',
                                  style: AppTextStyles.cardTitleSmallSemiBold,
                                ),
                                const SizedBox(height: AppDimensions.spaceSm),
                                TextField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  style: AppTextStyles.bodySecondary,
                                  decoration: InputDecoration(
                                    hintText: 'exemple@email.com',
                                    hintStyle: GoogleFonts.poppins(
                                      color: AppColors.textHint,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),

                                const SizedBox(height: AppDimensions.spaceLg),

                                Text(
                                  'Mot de passe',
                                  style: AppTextStyles.cardTitleSmallSemiBold,
                                ),
                                const SizedBox(height: AppDimensions.spaceSm),
                                TextField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  style: AppTextStyles.bodySecondary,
                                  decoration: InputDecoration(
                                    hintText: 'votre mot de passe',
                                    hintStyle: GoogleFonts.poppins(
                                      color: AppColors.textHint,
                                      fontSize: 13,
                                    ),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                        color: AppColors.textHint,
                                        size: 18,
                                      ),
                                      onPressed: () => setState(
                                        () => _obscurePassword =
                                            !_obscurePassword,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          SizedBox(height: 14),

                          // Subtitle under form
                          Text(
                            'Accédez à vos livres et contenus favoris',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppColors.textPrimary.withOpacity(0.55),
                              height: 1.5,
                            ),
                          ),

                          SizedBox(height: 24),

                          // Login button (golden)
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _login,
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
                                      'Se connecter',
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ),

                          SizedBox(height: 18),

                          // "ou" separator
                          Text(
                            'ou',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: AppColors.textPrimary.withOpacity(0.5),
                            ),
                          ),

                          SizedBox(height: 18),

                          // Bouton Google, seulement si ce build est configuré
                          // pour Google : afficher une promesse que
                          // l'application ne peut pas tenir est pire que ne
                          // rien proposer.
                          if (GoogleAuthService.estDisponible) ...[
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: OutlinedButton(
                                onPressed: _isLoading ? null : _connexionGoogle,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.textPrimary,
                                  backgroundColor: AppColors.cardBackground,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppDimensions.radiusInner,
                                    ),
                                  ),
                                  side: BorderSide(
                                    color: AppColors.textPrimary.withOpacity(
                                      0.1,
                                    ),
                                  ),
                                  elevation: 2,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                      // Pas const : la palette suit le theme.
                                      child: Text(
                                        'G',
                                        style: TextStyle(
                                          color: AppColors.accentInk,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    // Flexible, sinon le libellé impose sa largeur
                                    // naturelle au bouton et déborde sur les écrans
                                    // étroits — 16 px de trop sur un 390.
                                    Flexible(
                                      child: Text(
                                        'Continuer avec Google',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.poppins(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],

                          SizedBox(height: 24),

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
                                color: AppColors.textPrimary.withOpacity(0.7),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),

                          const Spacer(flex: 3),

                          // Même formulation et même destination que sur la page de
                          // bienvenue : l'inscription commence par le choix du profil,
                          // pas par le formulaire.
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ProfilPage(),
                              ),
                            ),
                            child: Text.rich(
                              TextSpan(
                                text: "Vous n'avez pas de compte ? ",
                                style: GoogleFonts.poppins(
                                  color: AppColors.textHint,
                                  fontSize: 13,
                                ),
                                children: [
                                  TextSpan(
                                    text: 'Inscrivez-vous',
                                    style: GoogleFonts.poppins(
                                      color: AppColors.accentInk,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: AppDimensions.spaceLg),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
