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
import 'package:space_learn_flutter/core/utils/parcours.dart';

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
    // Un profil manquant ne fait PLUS échouer la connexion.
    //
    // `throw Exception("Profil ID non reçu du backend.")` remontait au catch
    // de _login, qui affichait « Connexion impossible pour le moment. » alors
    // que la session venait d'être enregistrée (login() pose jeton, refresh,
    // nom et identifiant avant de rendre la main) : la personne ressaisissait
    // un mot de passe qui venait pourtant de fonctionner. On repart donc du
    // profil mémorisé sur l'appareil, et à défaut on laisse le choix du profil
    // à ProfilPage — la branche par défaut du routage ci-dessous.
    var profilId = tokenUser.user.profilId;
    if (profilId.isEmpty) {
      profilId = (await ProfileStorage.getSelectedProfile()) ?? '';
    }

    // Même raison pour l'écriture locale : un stockage qui refuse (coffre
    // verrouillé, disque plein) est un incident de l'appareil, pas un refus du
    // serveur, et ne doit pas se présenter comme un échec de connexion.
    try {
      if (profilId.isNotEmpty) {
        await _profileService.saveSelectedProfile(profilId);
      }
    } catch (e) {
      developer.log('Profil non enregistré localement : $e');
    }

    // À ce point la connexion a RÉUSSI : login() a enregistré jeton, refresh
    // et identifiant AVANT de rendre la main. Plus rien ici ne doit se solder
    // par « Connexion impossible » — c'est pourtant ce qui arrivait quand
    // getProfils() (un second appel réseau) échouait, ou quand le profil
    // manquait à la liste : l'utilisateur, connecté, restait sur l'écran de
    // connexion à ressaisir un mot de passe qui venait de fonctionner, et
    // découvrait au prochain lancement qu'il était connecté depuis le début.
    String role = '';
    try {
      final allProfiles = await _profileService.getProfils();
      final userProfile = allProfiles.firstWhere(
        (p) => p.id.trim().toLowerCase() == profilId.trim().toLowerCase(),
        orElse: () => ProfilModel(id: '', libelle: ''),
      );
      role = userProfile.libelle.toLowerCase();
    } catch (e) {
      developer.log('Profil non résolu après connexion : $e');
    }

    if (role.isEmpty) {
      // Routage par défaut : le rôle mémorisé sur l'appareil, sinon l'espace
      // lecteur — le parcours le plus courant. La prochaine résolution
      // réussie (démarrage ou connexion) remettra le vrai rôle en place.
      final memorise = (await ProfileStorage.getSelectedProfileRole()) ?? '';
      role = memorise.isNotEmpty ? memorise : 'lecteur';
    }

    try {
      await ProfileStorage.saveSelectedProfileRole(role);
      if (emailAMemoriser != null && emailAMemoriser.trim().isNotEmpty) {
        await ProfileStorage.saveSavedEmail(emailAMemoriser.trim());
      }
    } catch (e) {
      developer.log('Préférences de connexion non enregistrées : $e');
    }

    if (!mounted) return;

    // LA RÉOUVERTURE SE DIT AVANT D'ENTRER, ET ELLE SE LIT.
    //
    // Les deux routes de connexion — /auth/login et /auth/google — annulent
    // désormais la suppression d'un compte fermé par son titulaire dès que la
    // preuve est faite (mot de passe vérifié, ou jeton Google attesté). Le
    // serveur le dit dans `suppression_annulee` et écrit la phrase à montrer
    // dans `message` ; le mobile ne lisait ni l'un ni l'autre. La personne
    // entrait dans un compte nommé « Utilisateur Anonymisé » — c'est
    // DeleteAccount qui remplace le nom affiché — sans savoir ni pourquoi, ni
    // que son effacement venait d'être annulé, ni qu'elle devait ressaisir son
    // nom dans son profil.
    //
    // UN DIALOGUE, PAS UN SNACKBAR : la ligne d'après remplace toute la pile
    // de navigation, et un message furtif posé sur l'écran de connexion
    // disparaîtrait avec lui. C'est le dernier instant où cette phrase peut
    // être lue.
    //
    // La phrase vient du serveur, telle quelle : deux textes concurrents pour
    // un même fait divergent au premier changement, et c'est exactement ce que
    // cette campagne répare partout ailleurs.
    if (tokenUser.suppressionAnnulee) {
      await AppNotifications.showPremiumDialog(
        context,
        title: "Suppression annulée",
        message: tokenUser.message.trim().isNotEmpty
            ? tokenUser.message
            : "La suppression de votre compte est annulée : vos données ne seront pas effacées. Votre nom affiché avait été remplacé à la fermeture, vous pouvez le ressaisir dans votre profil.",
        confirmText: "Continuer",
        isSuccess: true,
      );
      if (!mounted) return;
    }

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
    if (profilId.isEmpty) {
      // Sans identifiant de profil, les deux accueils n'ont rien à interroger
      // (ils le passent à chacun de leurs appels) : le choix du profil est la
      // seule destination honnête.
      destination = const ProfilPage();
    } else if (role.contains("lecteur")) {
      destination = lecteurHome.HomePageLecteur(
        profileId: profilId,
        userName: tokenUser.user.nomComplet,
      );
    } else if (estParcoursAuteur(role)) {
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
      // L'adresse est mémorisée ICI AUSSI, à partir de celle que le serveur
      // renvoie. Ce chemin ne l'écrivait pas : la clé gardait alors l'adresse
      // du compte précédent, que l'écran de connexion pré-remplissait et sur
      // laquelle s'appuie la reconnexion silencieuse d'après changement de mot
      // de passe — un mot de passe tout neuf envoyé sous l'adresse d'un tiers.
      await _acheminerApresConnexion(
        tokenUser,
        emailAMemoriser: tokenUser.user.email,
      );
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
        _direLEchecDeConnexion(e, repli: "Connexion Google impossible.");
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Dit l'échec, et lui donne la forme que sa nature commande.
  ///
  /// UN REFUS DE DROIT N'EST PAS UNE PANNE, ET IL NE TIENT PAS DANS QUATRE
  /// SECONDES. Le serveur refuse maintenant un compte fermé, archivé ou
  /// inactif avec sa cause, sa date et L'ADRESSE du support — et ces refus-là
  /// sortent ICI, sur l'écran de connexion, où la personne n'a ni session, ni
  /// réglages, ni « Aide & FAQ » : c'est le seul endroit de l'application où
  /// elle lira cette adresse. Un message furtif de quatre secondes qu'aucun
  /// geste ne rappelle est une consigne impossible à suivre — on ne recopie
  /// pas une adresse électronique dans ce délai.
  ///
  /// Le dialogue ne propose PAS de réessayer : réessayer un refus de droit ne
  /// peut par construction jamais aboutir. Il ne propose que de fermer.
  ///
  /// Tout le reste — mot de passe faux, réseau coupé, serveur en panne — reste
  /// un message furtif : c'est un état passager, et le geste évident est de
  /// recommencer là où l'on est.
  void _direLEchecDeConnexion(Object e, {required String repli}) {
    if (!mounted) return;
    final message = messageLisible(e, repli: repli);

    if (e is AccesRefuse) {
      AppNotifications.showPremiumDialog(
        context,
        title: "Connexion refusée",
        message: message,
        confirmText: "Fermer",
        isError: true,
      );
      return;
    }

    AppNotifications.showSnackBar(context, message: message, isError: true);
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

        // LA PHRASE DU SERVEUR PASSE DEVANT LA NÔTRE, ET IL Y A DEUX CAS DE
        // PLUS QU'AVANT. Le serveur n'émet plus qu'un courriel par compte et
        // par minute (service.DelaiEntreDeuxCodes) : quand un code UTILISABLE
        // est déjà parti, il répond « un code vous a déjà été adressé il y a
        // moins d'une minute : utilisez celui-là ». Notre phrase en dur — « un
        // nouveau code vous a été envoyé » — annonçait alors un courriel qui ne
        // partirait pas, et la personne attendait devant sa boîte le code
        // qu'elle avait déjà.
        //
        // LE QUATRIÈME CAS EST LE PLUS RÉCENT, ET IL DIT L'INVERSE : un envoi a
        // bien eu lieu il y a moins d'une minute, mais les codes du compte
        // viennent d'être annulés après trop d'essais — il n'en reste AUCUN
        // d'utilisable, et le serveur écrit « Demandez-en un nouveau dans une
        // minute. » avec `code_envoye = false` (controllers/login.go:268).
        // Répéter « utilisez celui-là » enverrait recopier un code mort.
        // Quatre cas côté serveur, une phrase par cas : on relaie.
        final duServeur = nonVerifie ? e.message.trim() : '';
        final explication = duServeur.isNotEmpty
            ? duServeur
            : codeEnvoye
            ? "Votre adresse e-mail n'a pas encore été validée. Un nouveau code OTP de validation vous a été envoyé."
            : "Votre adresse e-mail n'a pas encore été validée. Le code n'a pas pu être envoyé : demandez-en un nouveau depuis l'écran de vérification.";

        // Un compte fermé par son titulaire ET jamais validé passe par ce 403 :
        // la réouverture a bien eu lieu, il ne lui manque que son code. Sans
        // cette ligne, la seule personne à qui la réouverture ne serait jamais
        // annoncée est celle qui a le plus de raisons d'en douter.
        final reouverture = nonVerifie && e.suppressionAnnulee
            ? "\n\nLa suppression de votre compte est annulée : vos données ne seront pas effacées."
            : "";

        AppNotifications.showPremiumDialog(
          context,
          title: "Vérification requise",
          message: "$explication$reouverture",
          confirmText: "Vérifier maintenant",
          isSuccess: false,
          onConfirm: () {
            if (mounted) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  // `code_envoye` VOYAGE JUSQU'À L'ÉCRAN DU CODE.
                  //
                  // Il était lu ici pour choisir une phrase, puis perdu :
                  // l'écran suivant annonçait « Entrez le code envoyé à … » et
                  // armait sa minute d'attente comme si un courriel venait de
                  // partir. Le serveur rend maintenant un quatrième cas où il
                  // vaut FAUX — les codes du compte viennent d'être annulés
                  // après trop d'essais (controllers/login.go:268) — et rien
                  // d'utilisable n'est alors dans la boîte de la personne. Voir
                  // [OtpPage.codeDejaEnvoye].
                  builder: (context) => OtpPage(
                    email: email,
                    isFromRegistration: true,
                    codeDejaEnvoye: codeEnvoye,
                  ),
                ),
              );
            }
          },
        );
      } else {
        _direLEchecDeConnexion(e, repli: "Connexion impossible pour le moment.");
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

                          // Le séparateur « ou » ENTRE dans la condition avec
                          // le bouton qu'il annonce : seul, il promettait une
                          // seconde façon d'entrer qui n'était nulle part.
                          //
                          // Bouton Google, seulement si ce build est configuré
                          // pour Google ET si le serveur l'accepte : afficher
                          // une promesse que l'application ne peut pas tenir
                          // est pire que ne rien proposer. Le serveur répond
                          // 501 tant que ses clés ne sont pas posées, et
                          // `GoogleAuthService` le retient pour la session —
                          // voir `leServeurNeLaPasBranchee`.
                          if (GoogleAuthService.estDisponible) ...[
                            SizedBox(height: 18),
                            Text(
                              'ou',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: AppColors.textPrimary.withOpacity(0.5),
                              ),
                            ),
                            SizedBox(height: 18),
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
