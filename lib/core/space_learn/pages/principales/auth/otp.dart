import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/themes/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:space_learn_flutter/core/themes/app_dimensions.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/auth/widgets/en_tete_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pinput/pinput.dart';
import 'package:space_learn_flutter/core/utils/app_notifications.dart';

import 'package:space_learn_flutter/core/space_learn/data/dataServices/authServices.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/auth/profil.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/auth/reset_password.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/auth/login.dart';
import 'package:space_learn_flutter/core/services/session_service.dart';
import 'package:space_learn_flutter/core/utils/profile_storage.dart';

import 'package:space_learn_flutter/core/space_learn/data/dataServices/profileService.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/profilModel.dart';
import 'package:space_learn_flutter/core/utils/message_erreur.dart';

class OtpPage extends StatefulWidget {
  final String email;
  final String? password;
  final bool isFromRegistration;
  const OtpPage({
    super.key,
    required this.email,
    this.password,
    this.isFromRegistration = false,
  });

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  final TextEditingController _pinController = TextEditingController();
  bool _isLoading = false;
  final _authService = AuthService();
  final _profileService = ProfileService();

  void _handleVerifyCode() async {
    if (_isLoading) return;
    final otp = _pinController.text.trim();
    if (otp.length < 6) return;

    setState(() {
      _isLoading = true;
    });

    try {
      if (widget.isFromRegistration) {
        final tokenUser = await _authService.verifyRegistration(
          widget.email,
          otp,
        );
        if (tokenUser != null) {
          // LA VÉRIFICATION A RÉUSSI : le serveur a marqué l'e-mail vérifié
          // et CONSOMMÉ le code. Plus rien de ce qui suit ne doit la faire
          // passer pour un échec. L'ancien code enchaînait getProfils() dans
          // le même try : si ce second appel réseau tombait, le catch
          // affichait « Vérification impossible », la personne ressaisissait
          // un code déjà brûlé et recevait « L'email est déjà vérifié » —
          // sans jamais être routée vers la connexion. Pire : la fin de
          // session n'était jamais atteinte, et l'application rouvrait
          // CONNECTÉE au prochain lancement, alors qu'elle croyait son
          // inscription ratée.
          final profilId = tokenUser.user.profilId;
          String role = '';
          try {
            // La résolution du rôle a besoin du jeton : elle passe donc AVANT
            // la fin de session, plus bas.
            final allProfiles = await _profileService.getProfils();
            final userProfile = allProfiles.firstWhere(
              (p) => p.id.trim().toLowerCase() == profilId.trim().toLowerCase(),
              orElse: () => ProfilModel(id: '', libelle: ''),
            );
            role = userProfile.libelle.toLowerCase();
          } catch (e) {
            // Le rôle sera résolu à la connexion ; l'inscription, elle, est
            // bel et bien validée.
            debugPrint('OTP : profil non résolu après vérification — $e');
          }

          // La session ouverte par verifyRegistration est fermée dans TOUS les
          // cas : on force la connexion manuelle.
          //
          // C'était `TokenStorage.clearToken()` — une SECONDE définition de la
          // fin de session, à côté de SessionService.terminer(). Elle laissait
          // en place tout ce que terminer() sait nettoyer et qui peut venir
          // d'un compte précédent sur le même appareil : badges, marqueurs de
          // discussion, adresse mémorisée, rappels de rendez-vous, purges
          // mémoire. Un seul point de nettoyage, ici comme ailleurs.
          try {
            await SessionService.terminer();
          } catch (e) {
            debugPrint('OTP : fin de session incomplète — $e');
          }

          // Réécrits APRÈS le nettoyage — qui les emporte, et c'est voulu :
          // l'écran de connexion s'en sert pour router sans attendre le
          // réseau, et ils appartiennent bien au compte qui vient de naître.
          try {
            if (profilId.isNotEmpty) {
              await _profileService.saveSelectedProfile(profilId);
            }
            if (role.isNotEmpty) {
              await ProfileStorage.saveSelectedProfileRole(role);
            }
          } catch (e) {
            debugPrint(
              'OTP : préférences d\'inscription non enregistrées — $e',
            );
          }

          if (mounted) {
            AppNotifications.showSnackBar(
              context,
              message:
                  "Inscription validée avec succès ! Connectez-vous pour compléter votre profil.",
              isSuccess: true,
            );
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (_) => LoginPage(
                  initialEmail: widget.email,
                  initialPassword: widget.password,
                  isFirstTimeRegistration: true,
                ),
              ),
              (route) => false,
            );
          }
        } else {
          // BRANCHE MUETTE, désormais bruyante.
          //
          // `verifyRegistration` est typée `Future<TokenUser?>` : le jour où
          // elle rendra null au lieu de lever — un 200 au corps inattendu
          // suffit, TokenUser.fromJson n'est pas défensif — l'écran arrêtait
          // le chargeur et ne disait plus rien : ni succès, ni erreur, ni
          // navigation, alors que le code OTP venait d'être consommé. On lève
          // pour que le catch ci-dessous prenne le relais.
          throw Exception("Réponse inattendue du serveur.");
        }
      } else {
        // MOT DE PASSE OUBLIÉ : ON NE VÉRIFIE PLUS LE CODE ICI.
        //
        // Cette branche appelait `/auth/verify-otp`, qui retrouve le code NON
        // CONSOMMÉ puis le marque utilisé (otp.go:117-125). L'écran suivant
        // appelle `/auth/reset-password`, qui exige à son tour un code NON
        // CONSOMMÉ (otp.go:282) — il ne pouvait donc trouver que celui que
        // cet écran venait de brûler.
        //
        // Le parcours était mort de bout en bout : on lisait « code vérifié »,
        // on choisissait son mot de passe, et l'on recevait « code expiré ».
        // Un nouveau code invalidait les précédents, et l'on recommençait
        // sans fin. Personne ne pouvait réinitialiser depuis l'application —
        // le site avait exactement le même défaut, corrigé de la même façon.
        //
        // On transmet donc le code intact : `/auth/reset-password` est seul à
        // le consommer, et un code faux y sera refusé avec la raison du
        // serveur — en une fois, au lieu d'une vérification qui condamnait la
        // suivante. (`/auth/verify-otp` reste en place côté serveur ; ici,
        // l'inscription passe par `verifyRegistration`, qui a sa propre
        // route.)
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) =>
                  ResetPasswordPage(email: widget.email, otp: otp),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        AppNotifications.showSnackBar(
          context,
          message: messageLisible(
            e,
            repli: "Vérification impossible pour le moment.",
          ),
          isError: true,
        );
      }
    } finally {
      // Le bouton retour reste actif pendant le chargement : quand la
      // réponse arrivait après que l'écran avait été quitté, setState
      // frappait un State disposé (« setState() called after dispose() »).
      // Même garde que dans _handleResendCode, qui l'avait déjà.
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _handleResendCode() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      await _authService.forgotPassword(widget.email);
      if (mounted) {
        AppNotifications.showSnackBar(
          context,
          // Le serveur répond volontairement dans le vague (anti-énumération)
          // : il rend 200 même quand aucun compte n'existe et qu'aucun
          // courriel n'est parti. On relaie sa formulation conditionnelle au
          // lieu d'affirmer un envoi qu'on ne peut pas garantir.
          message:
              'Si un compte correspond à cette adresse, un nouveau code vient d\'être envoyé.',
          isSuccess: true,
        );
      }
    } catch (e) {
      if (mounted) {
        AppNotifications.showSnackBar(
          context,
          message: messageLisible(e, repli: "Le code n'a pas pu être renvoyé."),
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
    final defaultPinTheme = PinTheme(
      width: 48,
      height: 52,
      textStyle: GoogleFonts.poppins(
        fontSize: 20,
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: Border.all(color: AppColors.textPrimary.withOpacity(0.1)),
        borderRadius: BorderRadius.circular(AppDimensions.radiusInner),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: AppColors.accentInk, width: 2),
      borderRadius: BorderRadius.circular(AppDimensions.radiusInner),
    );

    final submittedPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: AppColors.accentInk.withOpacity(0.5)),
      borderRadius: BorderRadius.circular(AppDimensions.radiusInner),
    );

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

                // Close button
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

                SizedBox(height: 32),

                EnTeteAuth(
                  titre: 'Vérification',
                  accroche: 'Entrez le code envoyé à ${widget.email}',
                ),

                const SizedBox(height: AppDimensions.spaceXl),

                // Pinput (OTP field)
                Pinput(
                  controller: _pinController,
                  length: 6,
                  defaultPinTheme: defaultPinTheme,
                  focusedPinTheme: focusedPinTheme,
                  submittedPinTheme: submittedPinTheme,
                  pinputAutovalidateMode: PinputAutovalidateMode.onSubmit,
                  showCursor: true,
                  cursor: Container(
                    width: 2,
                    height: 24,
                    color: AppColors.primary,
                  ),
                  onCompleted: (pin) => _handleVerifyCode(),
                ),

                SizedBox(height: 36),

                // Verify Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleVerifyCode,
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
                            'Vérifier',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),

                SizedBox(height: 20),

                TextButton(
                  onPressed: _isLoading ? null : _handleResendCode,
                  child: Text(
                    'Renvoyer le code',
                    style: AppTextStyles.linkBold,
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
}
