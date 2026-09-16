import 'dart:async';

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

  /// UN CODE UTILISABLE EST-IL RÉELLEMENT DANS LA BOÎTE DE LA PERSONNE ?
  ///
  /// Vrai dans le cas ordinaire : on arrive ici juste après un envoi. Faux dans
  /// le cas que la cadence du serveur a ouvert en se fermant — `/auth/login`
  /// rend alors 403 avec `code_envoye: false` et la phrase « Les codes de ce
  /// compte viennent d'être annulés après trop d'essais. Demandez-en un nouveau
  /// dans une minute. » (space_learn_auth, controllers/login.go:268) : un
  /// courriel est bien parti il y a moins d'une minute, mais ses codes ont été
  /// brûlés par une inondation d'essais faux, et il n'en reste AUCUN
  /// d'utilisable.
  ///
  /// CE QUE CELA CHANGE ICI, ET POURQUOI : l'accroche dirait « Entrez le code
  /// envoyé à … » d'un code qui n'existe plus, et le compte à rebours de
  /// « Renvoyer » s'armerait comme si un courriel venait de partir POUR ELLE.
  /// On ne l'arme donc pas : elle peut redemander tout de suite, et c'est le
  /// serveur qui tranche s'il est trop tôt, avec sa phrase.
  ///
  /// Le texte sous le bouton, lui, ne dépend plus de ce drapeau : il ne parle
  /// plus de la validité d'un code — que cet écran ne connaît pas — mais de la
  /// cadence du bouton, qui est vraie dans tous les cas.
  final bool codeDejaEnvoye;

  const OtpPage({
    super.key,
    required this.email,
    this.password,
    this.isFromRegistration = false,
    this.codeDejaEnvoye = true,
  });

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  final TextEditingController _pinController = TextEditingController();
  bool _isLoading = false;
  final _authService = AuthService();
  final _profileService = ProfileService();

  /// UN COURRIEL PAR COMPTE ET PAR MINUTE — c'est le serveur qui en décide.
  ///
  /// `service.DelaiEntreDeuxCodes` (space_learn_auth, service/otp_emission.go)
  /// vaut une minute. LA CADENCE COMPTE LES ENVOIS, PLUS LES CODES VIVANTS, et
  /// la nuance n'est pas de forme : `UnEnvoiVientDePartir` a remplacé
  /// `UnCodeVivantVientDePartir` parce que la clause « et le code est encore
  /// valable » se contournait en vingt-six requêtes — vingt-cinq essais faux
  /// brûlaient les codes, la cadence ne voyait plus rien de vivant, et un
  /// courriel repartait sur-le-champ. Un code ADRESSÉ il y a moins d'une minute
  /// retient donc l'émission suivante, qu'il soit encore utilisable ou non.
  ///
  /// La réponse rendue ne change pas d'un caractère selon que l'envoi a lieu ou
  /// est retenu — elle ne peut pas changer, sous peine de redevenir l'oracle
  /// d'énumération que le serveur ferme par ailleurs.
  ///
  /// CONSÉQUENCE À L'ÉCRAN, ET C'EST TOUTE LA RAISON DE CE COMPTE À REBOURS :
  /// sans lui, la personne appuie sur « Renvoyer », lit « un nouveau code vient
  /// d'être envoyé », et attend devant sa boîte un courriel qui ne partira pas
  /// — celui d'il y a trente secondes est le bon. Un délai visible dit la
  /// vérité : quelque chose est déjà parti, il faut le chercher avant d'en
  /// redemander.
  ///
  /// CE QUE CE CHOIX COÛTE, ET LE SERVEUR L'ÉCRIT PLUTÔT QUE DE LE SUBIR :
  /// après un brûlage, la personne n'a plus rien d'utilisable en main et attend
  /// tout de même jusqu'à une minute. C'est le cas que porte
  /// [OtpPage.codeDejaEnvoye], et c'est pour lui que le décompte ne s'arme pas
  /// toujours à l'ouverture.
  static const int _secondesEntreDeuxCodes = 60;

  /// Combien de secondes avant que « Renvoyer » puisse faire partir un code.
  int _avantRenvoi = _secondesEntreDeuxCodes;
  Timer? _decompte;

  /// La phrase du serveur quand la vérification a échoué SUR UNE PANNE, et nul
  /// dans tous les autres cas.
  ///
  /// C'est le seul refus de ces routes où « Réessayer » peut aboutir : le
  /// serveur répond 503 sans rien écrire, sans compter d'essai, et le code
  /// saisi reste valable (space_learn_auth, controllers/otp.go,
  /// `reponsePanneCode`). Un message furtif de quatre secondes ne suffit pas à
  /// le dire : la personne ne saurait pas qu'elle peut simplement recommencer,
  /// et croirait son code refusé.
  ///
  /// SEUL LE 503 ARRIVE ICI — voir `AuthService._leverSurLesRoutesDeCode`. Un
  /// 5xx qui n'est pas 503 ne dit RIEN du sort du code, et ce panneau ne doit
  /// pas affirmer qu'il est intact ; un refus de droit non plus, et le compte
  /// déjà validé encore moins : celui-là mène à la connexion.
  String? _panne;

  @override
  void initState() {
    super.initState();
    // Le décompte part À L'OUVERTURE, et non au premier renvoi : on arrive
    // presque toujours ici juste après un envoi — inscription, connexion d'un
    // compte non vérifié, mot de passe oublié. La minute du serveur court déjà.
    //
    // SAUF QUAND AUCUN CODE UTILISABLE N'EST PARTI : voir
    // [OtpPage.codeDejaEnvoye]. Armer le décompte y ferait attendre une minute
    // devant une boîte vide, sous une phrase qui promet un code valable.
    if (widget.codeDejaEnvoye) {
      _armerLeDecompte();
    } else {
      _avantRenvoi = 0;
    }
  }

  @override
  void dispose() {
    _decompte?.cancel();
    _pinController.dispose();
    super.dispose();
  }

  void _armerLeDecompte() {
    _decompte?.cancel();
    setState(() => _avantRenvoi = _secondesEntreDeuxCodes);
    _decompte = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _avantRenvoi--;
        if (_avantRenvoi <= 0) t.cancel();
      });
    });
  }

  void _handleVerifyCode() async {
    if (_isLoading) return;
    final otp = _pinController.text.trim();
    if (otp.length < 6) return;

    setState(() {
      _isLoading = true;
      _panne = null;
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
        final message = messageLisible(
          e,
          repli: "Vérification impossible pour le moment.",
        );

        // LE COMPTE EST DÉJÀ VALIDÉ : ON NE REFUSE PAS, ON OUVRE LA PORTE.
        //
        // C'est le cul-de-sac que le commentaire de la branche de succès décrit
        // depuis deux tours — « recevait L'email est déjà vérifié, sans jamais
        // être routée vers la connexion ». Le serveur a fermé la cause (l'ordre
        // des écritures de /auth/verification) et donné la sortie à ceux qui y
        // sont déjà : 400 `deja_verifie` (voir [CompteDejaValide]).
        //
        // NI « RÉESSAYER », NI LE PANNEAU DE PANNE : c'est un refus de DROIT,
        // rejouer la vérification ne peut par construction pas aboutir — le
        // code est mort et l'adresse est validée. Le dialogue porte la phrase
        // du serveur, qui nomme les deux portes de connexion, et son seul geste
        // y mène. Il remplace l'écran de saisie plutôt que de s'y superposer :
        // il n'y a plus rien à saisir ici.
        if (e is CompteDejaValide) {
          setState(() => _panne = null);
          AppNotifications.showPremiumDialog(
            context,
            title: "Compte déjà validé",
            message: message,
            confirmText: "Se connecter",
            isSuccess: true,
            onConfirm: () {
              if (!mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (_) => LoginPage(
                    initialEmail: widget.email,
                    initialPassword: widget.password,
                  ),
                ),
                (route) => false,
              );
            },
          );
          return;
        }

        // UNE PANNE N'EST PAS UN REFUS, ET C'EST LA SEULE QUI SE RÉESSAIE.
        //
        // Les trois routes de code répondent maintenant 503 quand la base n'a
        // pas pu être lue : le serveur n'a RIEN écrit, aucun essai n'a été
        // compté, et le code saisi est toujours bon. Tout le reste — code
        // faux, code périmé, compte exclu — est un refus que réessayer ne peut
        // pas lever. Voir [PanneServeur].
        //
        // Les cases NE SONT PAS VIDÉES, ni ici ni ailleurs : rien n'appelle
        // `_pinController.clear()` dans cet écran, et il ne faut pas
        // l'ajouter. Sur une panne, la personne rappuie sur « Réessayer » avec
        // son code encore à l'écran.
        setState(() => _panne = e is PanneServeur ? message : null);
        AppNotifications.showSnackBar(
          context,
          message: message,
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
    if (_isLoading || _avantRenvoi > 0) return;
    setState(() => _isLoading = true);

    try {
      // LA ROUTE SUIT LE PARCOURS, ET ELLE NE LE SUIVAIT PAS. Cet écran sert
      // deux parcours : la validation d'une inscription, et le mot de passe
      // oublié. Le renvoi passait dans les DEUX cas par
      // `/auth/forgot-password`, dont la phrase parle d'un « code de
      // réinitialisation » — annoncé à quelqu'un qui valide son inscription.
      // Les deux routes écrivent le même code dans la même table ; c'est le
      // texte, et lui seul, qui différait. Maintenant que ce texte est celui du
      // serveur, il faut demander la bonne route.
      final duServeur = widget.isFromRegistration
          ? await _authService.sendOtp(widget.email)
          : await _authService.forgotPassword(widget.email);
      if (mounted) {
        // La minute repart : le serveur vient soit d'émettre, soit de retenir
        // parce qu'un envoi a eu lieu il y a moins d'une minute. Dans les deux
        // cas, insister avant la fin ne fera rien partir.
        _armerLeDecompte();
        AppNotifications.showSnackBar(
          context,
          // LA PHRASE EST CELLE DU SERVEUR, TELLE QUELLE.
          //
          // Elle était recopiée en dur ici, et elle a cessé d'être vraie : la
          // cadence ne regarde plus si le code déjà envoyé est encore VIVANT
          // (`service.UnEnvoiVientDePartir`), si bien qu'il existe désormais un
          // cas — codes annulés par une inondation d'essais faux — où « celui
          // que vous avez reçu reste valable » est faux et laisserait la
          // personne recopier un code mort. Le serveur dit maintenant « Si vous
          // ne le recevez pas, redemandez-en un dans une minute. » ; c'est la
          // seule chose vraie qu'il puisse dire sans révéler à un inconnu
          // l'état d'un compte, et c'est donc elle qu'on affiche. Voir
          // `AuthService.sendOtp`.
          message: duServeur,
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
                  // ON N'ANNONCE PAS UN CODE QUI N'EST PAS PARTI. « Entrez le
                  // code envoyé à … » est faux quand les codes du compte
                  // viennent d'être annulés : voir [OtpPage.codeDejaEnvoye].
                  accroche: widget.codeDejaEnvoye
                      ? 'Entrez le code envoyé à ${widget.email}'
                      : 'Aucun code utilisable pour ${widget.email} : '
                            'demandez-en un nouveau ci-dessous.',
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

                // LA PANNE, SA PHRASE, ET LE SEUL « RÉESSAYER » DE CET ÉCRAN.
                //
                // Le message du serveur est affiché TEL QUEL — « La
                // vérification du code est momentanément impossible. Réessayez
                // dans un instant. » — et le bouton rejoue la MÊME
                // vérification, avec le code toujours dans les cases. Voir
                // [_panne] : il ne s'affiche que sur un 503, jamais sur un
                // refus.
                if (_panne != null) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusInner,
                      ),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _panne!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          onPressed: _isLoading ? null : _handleVerifyCode,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: Text(
                            'Réessayer',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.onAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                SizedBox(height: 20),

                TextButton(
                  onPressed: (_isLoading || _avantRenvoi > 0)
                      ? null
                      : _handleResendCode,
                  child: Text(
                    _avantRenvoi > 0
                        ? 'Renvoyer le code dans ${_avantRenvoi}s'
                        : 'Renvoyer le code',
                    style: AppTextStyles.linkBold,
                  ),
                ),

                // La raison du délai, écrite. Un bouton grisé sans explication
                // se lit comme une panne ; celui-ci dit ce qui est vrai.
                //
                // ET IL NE DIT QUE CELA. Cette ligne affirmait « celui qui
                // vient d'être envoyé est encore valable » — ce que nous ne
                // savons pas. Le décompte est armé après TOUT appui abouti sur
                // « Renvoyer » ; or le serveur retient l'émission dès qu'un
                // code a été ADRESSÉ il y a moins d'une minute, qu'il soit
                // encore valable ou non. Après vingt-cinq essais faux, les
                // codes sont brûlés et l'émission reste pourtant retenue : la
                // phrase promettait alors un code valable qui n'existe plus, à
                // trois lignes de celle du serveur qui disait le contraire.
                // Ce qui est vrai dans tous les cas, c'est la cadence.
                if (_avantRenvoi > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      "Un code par minute : le bouton se rouvre à la fin du décompte.",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
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
