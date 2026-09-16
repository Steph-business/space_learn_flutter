import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:space_learn_flutter/core/space_learn/data/model/tokenUser.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/user_model.dart';
import 'package:space_learn_flutter/core/utils/api_routes.dart';
import 'package:space_learn_flutter/core/utils/token_storage.dart';
import 'package:space_learn_flutter/core/services/api_client.dart';
import 'package:space_learn_flutter/core/services/google_auth_service.dart';
import 'package:space_learn_flutter/core/services/rappels_lecture.dart';
import 'package:space_learn_flutter/core/services/session_service.dart';
import 'package:space_learn_flutter/core/utils/message_erreur.dart';

/// Ce que le serveur a répondu à une demande de fermeture de compte.
///
/// LA RÉPONSE PEUT PORTER UNE DETTE, et c'est le seul cas où l'écran doit
/// afficher la phrase du serveur plutôt que la sienne. Quand la personne est
/// encore créditrice, `DeleteAccount` (space_learn_auth, controllers/user.go)
/// rend `reste_du` et `devise`, et son `message` ne promet AUCUNE date
/// d'effacement : la purge est RETENUE tant que la somme n'est pas versée —
/// l'effacer emporterait la seule destination de virement enregistrée. Rejouer
/// « vos informations seront effacées dans trente jours » serait alors
/// promettre ce que le serveur ne fera pas.
class SuppressionDemandee {
  const SuppressionDemandee({
    required this.message,
    required this.resteDu,
    required this.devise,
    required this.effacementRetenu,
  });

  /// La phrase du serveur, telle quelle. Vide s'il n'en a pas écrit.
  final String message;

  /// Ce qui reste dû à la personne. Zéro dans le cas ordinaire.
  final double resteDu;

  /// La devise de [resteDu] — « XOF » aujourd'hui.
  final String devise;

  /// Le serveur retient-il l'effacement ? Il le dit lui-même, et c'est la
  /// seule source qui couvre les DEUX cas : une somme due, mais aussi un
  /// portefeuille ILLISIBLE — où [resteDu] vaut zéro alors que la purge
  /// retiendra le compte tous les jours. Se fier à [resteDu] seul faisait
  /// donc promettre trente jours à qui ne les aurait jamais vus.
  final bool effacementRetenu;

  /// Y a-t-il quelque chose qui retient l'effacement ?
  ///
  /// Le repli sur [resteDu] sert un serveur qui ne rend pas encore le
  /// drapeau : il couvre alors le seul cas qu'il savait dire.
  bool get uneDetteRetientLEffacement => effacementRetenu || resteDu > 0;
}

/// Le compte existe, mais son adresse n'a jamais été validée.
///
/// Ce n'est pas un échec de connexion : c'est une étape qui manque, et elle a
/// son écran. La distinguer par un type plutôt que par une sous-chaîne de
/// message évite qu'une reformulation côté serveur ne coupe la redirection en
/// silence.
///
/// `codeEnvoye` vaut false quand le serveur n'a pas pu envoyer le courriel :
/// l'écran doit alors proposer de réessayer, et surtout ne pas annoncer un
/// code que personne n'a reçu.
class CompteNonVerifieException implements Exception {
  const CompteNonVerifieException({
    required this.email,
    required this.codeEnvoye,
    required this.message,
    this.suppressionAnnulee = false,
  });

  final String email;
  final bool codeEnvoye;
  final String message;

  /// La connexion vient de rouvrir un compte fermé, MAIS il lui manque encore
  /// son code.
  ///
  /// Le serveur pose `suppression_annulee` sur ce 403 aussi (login.go) : un
  /// compte fermé par son titulaire et jamais validé passe par là. Sans ce
  /// champ, la seule personne à qui la réouverture n'est jamais annoncée
  /// serait précisément celle qui a le plus de raisons d'en douter.
  final bool suppressionAnnulee;

  @override
  String toString() => message;
}

class AuthService {
  /// Le client partagé, comme tous les autres services.
  ///
  /// AuthService était le dernier à appeler `http.post` et `http.get` au niveau
  /// package — treize fois. Ces appels-là ne traversent pas [ApiClient], donc
  /// pas l'intercepteur qui, sur un 401, purge la session et ramène à l'écran
  /// de connexion.
  ///
  /// La conséquence se voyait à l'écran : le jeton expirait, `getUser` recevait
  /// un 401, personne ne l'interprétait, et l'application affichait
  /// « Exception: ... {"error":"Token invalide ou expiré"} » sous un bouton
  /// « Réessayer » qui ne pouvait par construction jamais aboutir — le jeton
  /// restait mort à chaque tentative.
  ///
  /// Les routes `/auth/` restent épargnées par l'intercepteur : un 401 y
  /// signifie « mauvais mot de passe », pas « session finie », et déconnecter
  /// quelqu'un qui essaie justement de se connecter n'aurait aucun sens.
  final http.Client client;

  /// Le client injecté, QUAND c'est bien l'intercepteur — nul sinon.
  ///
  /// `changePassword` a deux besoins que seul [ApiClient] sait servir : mener
  /// le renouvellement lui-même (`renouvelerSession`) et relayer un refus de
  /// `/auth/refresh` (`constaterSessionFinie`). Elle les appelait sur
  /// `ApiClient.instance` en dur, par-dessus le client injecté — de sorte
  /// qu'un test muni d'un MockClient touchait quand même le singleton réel,
  /// donc le vrai réseau et la vraie déconnexion globale. Pire : l'en-tête
  /// [ApiClient.enTete401Metier] est une convention INTERNE, retirée par
  /// `ApiClient.send` avant l'envoi ; posée sur un client qui n'est pas
  /// l'intercepteur, elle partirait sur le réseau — exactement ce que le
  /// commentaire d'api_client.dart promet de ne jamais faire.
  ///
  /// Un seul champ tranche les trois : on ne pose l'en-tête et on ne demande
  /// le renouvellement que s'il y a un intercepteur pour les honorer.
  final ApiClient? _intercepteur;

  AuthService({http.Client? client}) : this._(client ?? ApiClient.instance);

  AuthService._(this.client)
    : _intercepteur = client is ApiClient ? client : null;

  /// Ouvre la session sur cet appareil.
  ///
  /// Les trois chemins d'entrée — mot de passe, Google, validation
  /// d'inscription — recopiaient les mêmes quatre enregistrements. Les réunir
  /// évite qu'un cinquième chemin, demain, en oublie un.
  ///
  /// C'est aussi le pendant de SessionService.terminer : ce que la
  /// déconnexion efface, l'ouverture de session doit le remettre en place.
  ///
  /// [reprendreLesRappels] vaut false pour la validation d'inscription, qui
  /// ouvre une session que l'écran referme aussitôt — voir l'appel plus bas.
  Future<void> _ouvrirSession(
    TokenUser tokenUser, {
    bool reprendreLesRappels = true,
  }) async {
    await TokenStorage.saveToken(tokenUser.token);
    await TokenStorage.saveRefreshToken(tokenUser.refreshToken);
    await TokenStorage.saveUserName(tokenUser.user.nomComplet);
    // Le temps de lecture, la série de jours et les badges sont rangés par
    // compte : sans cet identifiant ils se mélangeaient entre les personnes
    // qui se connectent sur un même téléphone.
    await TokenStorage.saveUserId(tokenUser.user.id);

    // Les rappels de lecture reviennent avec le compte.
    //
    // La déconnexion les purge maintenant de l'appareil, notifications
    // système comprises (voir RappelsLecture.purgerEtAnnuler) : sans cette
    // remise en place, le lecteur qui se reconnecte n'aurait plus AUCUN
    // rappel tant qu'il n'ouvre pas l'écran « Temps de lecture ». Non
    // attendu : la connexion ne doit pas patienter sur une notification, et
    // un serveur muet ne doit pas la faire échouer.
    //
    // MAIS PAS QUAND LA SESSION EST OUVERTE POUR ÊTRE REFERMÉE. Sur le chemin
    // de la validation d'inscription, otp.dart enchaîne une résolution de
    // profils par le réseau puis SessionService.terminer(), qui exécute
    // RappelsLecture.purgerEtAnnuler(). Les deux sont des allers-retours
    // réseau, et rien n'ordonne l'un par rapport à l'autre : une
    // synchronisation revenue APRÈS la purge réécrivait la liste des créneaux
    // et reprogrammait chez le système des notifications hebdomadaires pour un
    // compte qu'on vient délibérément de déconnecter — sous la clé
    // « rappels_lecture_invite » si l'identifiant était déjà effacé. C'est
    // exactement ce que l'étape « rappels de lecture » de terminer() ferme,
    // réintroduit par la porte d'à côté.
    if (!reprendreLesRappels) return;
    unawaited(
      RappelsLecture.synchroniser().catchError((Object e) {
        debugPrint('Rappels de lecture non reprogrammés : $e');
        return const <CreneauLecture>[];
      }),
    );
  }

  /// ✅ Inscription
  Future<bool> register({
    required String nomComplet,
    required String pseudo,
    required String email,
    required String password,
    required String profilId,
  }) async {
    final url = Uri.parse(ApiRoutes.register);
    final body = jsonEncode({
      "nom_complet": nomComplet,
      "pseudo": pseudo,
      "email": email,
      "password_hash": password,
      "profil_id": profilId,
    });
    final response = await client.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: body,
    );
    if (response.statusCode == 201) {
      return true;
    } else {
      // Le message du serveur est utile (« cet email est déjà utilisé ») ;
      // son corps brut ne l'est pas. messageDeLaReponse fait le tri.
      debugPrint('\n╔══ DIAGNOSTIC INSCRIPTION ══════════════════');
      debugPrint('║ Status : ${response.statusCode}');
      debugPrint('║ Corps  : ${response.body}');
      debugPrint('╚════════════════════════════════════════════\n');
      throw Exception(
        messageDeLaReponse(response, repli: "Inscription impossible."),
      );
    }
  }

  /// ✅ Connexion
  Future<TokenUser> login(String email, String password) async {
    final url = Uri.parse(ApiRoutes.login);
    final body = jsonEncode({"email": email, "password": password});
    final response = await client.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: body,
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      final tokenUser = TokenUser.fromJson(jsonDecode(response.body));
      // ── DIAGNOSTIC ──
      //
      // AUCUN JETON N'EST IMPRIMÉ, ni en entier ni en partie. `debugPrint`
      // n'est pas retiré des versions de production : il écrit dans logcat en
      // release comme en debug, et un journal se relève avec un câble et adb,
      // un rapport de bogue Android ou un outil de diagnostic constructeur.
      // Le jeton de rafraîchissement vaut trente jours de session : le voir
      // passer dans le journal à chaque connexion revenait à l'y déposer. La
      // présence du jeton suffit au diagnostic (« le serveur l'a-t-il
      // renvoyé ? ») ; sa valeur n'a jamais servi à personne.
      debugPrint('\n╔══ DIAGNOSTIC LOGIN ═══════════════════════');
      debugPrint('║ Token reçu : ${tokenUser.token.isNotEmpty}');
      debugPrint('║ Refresh vide ? ${tokenUser.refreshToken.isEmpty}');
      debugPrint('║ Clés JSON : ${jsonDecode(response.body).keys.toList()}');
      debugPrint('╚════════════════════════════════════════════\n');
      // ✅ On sauvegarde le token après la connexion
      await _ouvrirSession(tokenUser);
      return tokenUser;
    }

    // Un compte non vérifié se reconnaît au STATUT, plus à sa phrase.
    //
    // L'écran décidait de rediriger vers la saisie du code en cherchant
    // « n'est pas encore vérifié » dans le message. Reformuler cette phrase
    // côté serveur cassait donc la redirection, sans qu'aucune compilation ne
    // s'en aperçoive. Le 403 et le champ `verified` sont là pour ça.
    //
    // `code_envoye` distingue « le code est parti » de « l'envoi a échoué » :
    // sans lui, l'écran annonçait un courriel que personne n'avait reçu.
    if (response.statusCode == 403) {
      final corps = _corpsJson(response.body);
      if (corps != null && corps["verified"] == false) {
        throw CompteNonVerifieException(
          email: (corps["email"] as String?) ?? email,
          codeEnvoye: corps["code_envoye"] != false,
          message: messageDeLaReponse(response, repli: "Compte non vérifié."),
          suppressionAnnulee: corps["suppression_annulee"] == true,
        );
      }

      // LES AUTRES 403 SONT DES REFUS DE DROIT, ET ILS SE DISENT COMME TELS.
      //
      // Compte fermé et délai écoulé, compte archivé par l'administration,
      // compte inactif : trois refus que réessayer ne peut pas lever. Le
      // serveur y écrit maintenant la cause, la date et L'ADRESSE du support —
      // parce que ces refus-là sortent sur l'écran de CONNEXION, où la
      // personne n'a ni session, ni réglages, ni « Aide & FAQ », donc aucun
      // autre endroit où lire cette adresse.
      //
      // Le type le dit une fois pour toutes : l'écran ne peut pas deviner, en
      // lisant la phrase, qu'elle nomme une porte fermée plutôt qu'une panne.
      // Il en fait un dialogue qu'on ferme soi-même, et non un message furtif
      // de quatre secondes — on ne recopie pas une adresse électronique dans
      // ce délai-là.
      throw AccesRefuse(
        messageDeLaReponse(response, repli: "Connexion refusée."),
      );
    }

    throw Exception(
      messageDeLaReponse(response, repli: "Connexion impossible."),
    );
  }

  /// Le corps d'une réponse, s'il est bien un objet JSON.
  ///
  /// Un serveur en panne peut répondre du HTML sous un code d'erreur : le
  /// décodage doit échouer sans bruit plutôt que faire tomber la connexion.
  Map<String, dynamic>? _corpsJson(String corps) {
    try {
      final decode = jsonDecode(corps);
      return decode is Map<String, dynamic> ? decode : null;
    } catch (_) {
      return null;
    }
  }

  /// Connexion par jeton d'identité Google.
  ///
  /// Le jeton n'est pas décodé ici : l'application se contente de le
  /// transmettre. C'est le serveur qui vérifie sa signature, son émetteur et
  /// son destinataire — un contrôle fait dans l'application ne prouverait
  /// rien, puisqu'une application peut être modifiée.
  ///
  /// [profil] n'a d'effet qu'à la toute première connexion, quand le compte
  /// est créé. On ne change pas le profil de quelqu'un parce qu'il revient.
  ///
  /// CETTE ROUTE ROUVRE MAINTENANT UN COMPTE FERMÉ, comme /auth/login : elle
  /// rend `suppression_annulee` et le même `message` (space_learn_auth,
  /// oauth_google.go — ConnexionGoogle appelle `AnnulerLaSuppression`).
  /// C'est nouveau, et c'est ce qui manquait à la moitié des gens : un compte
  /// né de Google porte un mot de passe aléatoire que personne ne connaît, si
  /// bien que « reconnectez-vous avec votre mot de passe » leur promettait une
  /// sortie fermée. [TokenUser] porte les deux champs, l'écran les affiche.
  Future<TokenUser> connexionGoogle(String idToken, {String? profil}) async {
    final response = await client.post(
      Uri.parse(ApiRoutes.google),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "id_token": idToken,
        if (profil != null && profil.isNotEmpty) "profil": profil,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final tokenUser = TokenUser.fromJson(jsonDecode(response.body));
      await _ouvrirSession(tokenUser);
      return tokenUser;
    }

    // GOOGLE N'EST PAS BRANCHÉ SUR CE SERVEUR : ON LE DIT, ET ON CESSE DE
    // L'OFFRIR.
    //
    // Le serveur répond 501 tant que les clés ne sont pas posées, avec sa
    // propre phrase — « La connexion avec Google n'est pas disponible sur ce
    // serveur. Créez un compte ou connectez-vous avec votre adresse e-mail et
    // un mot de passe. » (space_learn_auth, controllers/oauth_google.go) — et
    // un drapeau `google_indisponible` dans le corps. On affichait à la place
    // une phrase à nous, qui ne disait pas quoi faire, et le bouton restait
    // offert : la personne rappuyait sur une porte qui n'existe pas.
    //
    // Le drapeau éteint le bouton POUR LE RESTE DE LA SESSION
    // (GoogleAuthService), et le refus est un refus de DROIT : `ErreurGoogle`
    // le fait sortir en message furtif sans « Réessayer », comme les autres
    // refus de ce parcours.
    if (response.statusCode == 501) {
      if (_corpsJson(response.body)?['google_indisponible'] == true) {
        GoogleAuthService.leServeurNeLaPasBranchee();
      }
      throw ErreurGoogle(
        messageDeLaReponse(
          response,
          repli:
              "La connexion avec Google n'est pas disponible sur ce serveur. "
              "Créez un compte ou connectez-vous avec votre adresse e-mail et "
              "un mot de passe.",
        ),
      );
    }

    // Mêmes refus de droit que /auth/login, et ils sortent au même endroit :
    // ConnexionGoogle rend les mêmes phrases, adresse du support comprise
    // (space_learn_auth, oauth_google.go). Le type les distingue d'une panne
    // pour que l'écran ne propose pas de réessayer.
    if (response.statusCode == 403) {
      throw AccesRefuse(
        messageDeLaReponse(response, repli: "Connexion refusée."),
      );
    }

    String message = "La connexion Google a échoué.";
    try {
      final data = jsonDecode(response.body);
      message = data['error'] ?? message;
    } catch (_) {}
    throw Exception(message);
  }

  /// ✅ Déconnexion
  Future<void> logout() async {
    final token = await TokenStorage.getToken();
    // Le jeton de rafraîchissement part avec la requête : c'est LUI que le
    // serveur révoque. Sans lui, la déconnexion n'effaçait la session que du
    // téléphone et le compte restait accessible à qui détenait une copie des
    // jetons — le serveur ne savait tout simplement pas lequel fermer.
    final refresh = await TokenStorage.getRefreshToken();

    if (token != null) {
      try {
        final url = Uri.parse(ApiRoutes.logout);
        await client.post(
          url,
          headers: {
            "Content-Type": "application/json",
            "Authorization": "Bearer $token",
          },
          body: jsonEncode({'refresh_token': refresh ?? ''}),
        );
      } catch (e) {
        // Gérer l'erreur de déconnexion côté serveur, mais continuer la déconnexion locale
      }
    }
    // La session locale est effacee dans tous les cas, y compris si l'appel
    // serveur a echoue : jeton, profil et livres telecharges.
    await SessionService.terminer();
  }

  /// Envoyer un code par e-mail.
  ///
  /// Les quatre routes d'OTP rendaient un simple booléen, et le message du
  /// serveur partait à la poubelle. « Code invalide ou expiré », « Trop de
  /// requêtes » et « Ce compte n'est plus actif » arrivaient donc à l'écran
  /// sous une seule phrase générique, qui ne disait jamais quoi faire.
  ///
  /// Elles lèvent maintenant, comme `login` et `register` : les écrans ont déjà
  /// le `catch` qui affiche `messageLisible`.
  ///
  /// ELLE REND LA PHRASE DU SERVEUR, ET PLUS UN BOOLÉEN. C'est la seule chose
  /// vraie qu'on puisse dire ici : la réponse est volontairement identique que
  /// le compte existe ou non, et elle est identique aussi quand la cadence
  /// retient l'envoi — sans quoi deux phrases différentes suffiraient à trier
  /// une liste d'adresses entre inscrits et inconnus. Elle vaut aujourd'hui
  /// « Si un compte est associé à cet e-mail, un code de vérification a été
  /// envoyé. Si vous ne le recevez pas, redemandez-en un dans une minute. »
  /// (space_learn_auth, controllers/otp.go:209-210) — la seconde partie est
  /// nouvelle : depuis que la cadence ne regarde plus si le code déjà envoyé
  /// est encore VIVANT, il existe un cas où la personne n'a rien d'utilisable
  /// en main et doit attendre la fin de la minute. Un écran qui recopierait
  /// cette phrase en dur la laisserait attendre sans savoir quoi faire.
  ///
  /// Sur une panne de base, la route rend maintenant 503 « L'envoi du code est
  /// momentanément impossible. Réessayez dans un instant. » là où elle rendait
  /// 200 « un code a été envoyé » sans que rien ne parte (otp.go:144, :219).
  /// L'exception porte cette phrase-là ; l'écran l'affiche et laisse la saisie.
  Future<String> sendOtp(String email) async {
    final response = await client.post(
      Uri.parse(ApiRoutes.sendOtp),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email}),
    );
    if (response.statusCode == 200) {
      return _phraseDEnvoi(
        response,
        repli:
            "Si un compte est associé à cette adresse, un code de vérification "
            "a été envoyé. Si vous ne le recevez pas, redemandez-en un dans "
            "une minute.",
      );
    }
    throw Exception(
      messageDeLaReponse(response, repli: "L'envoi du code a échoué."),
    );
  }

  /// La phrase que le serveur a écrite pour un envoi de code, ou [repli].
  ///
  /// Le repli n'est pas une invention : c'est la recopie de la phrase du
  /// serveur, pour le seul cas où elle n'arriverait pas — un serveur plus
  /// ancien, un corps illisible. Elle dit la même chose, à savoir le
  /// conditionnel et le délai d'une minute.
  String _phraseDEnvoi(http.Response response, {required String repli}) {
    final corps = _corpsJson(response.body);
    final message = corps?["message"];
    if (message is String && message.trim().isNotEmpty) return message.trim();
    return repli;
  }

  /// Vérifier un code reçu par e-mail — `/auth/verify-otp`.
  ///
  /// Voir [_leverSurLesRoutesDeCode] pour le 503 de panne, seul refus de cette
  /// route où réessayer puisse aboutir.
  Future<bool> verifyOtp(String email, String otp) async {
    final response = await client.post(
      Uri.parse(ApiRoutes.verifyOtp),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email, "otp": otp}),
    );
    if (response.statusCode == 200) return true;
    _leverSurLesRoutesDeCode(response, "Ce code n'a pas pu être vérifié.");
  }

  /// L'échec d'une des TROIS ROUTES DE CODE, avec sa nature.
  ///
  /// `/auth/verify-otp`, `/auth/verification` et `/auth/reset-password`
  /// répondent 503 quand la base n'a pas pu être lue (space_learn_auth,
  /// controllers/otp.go, `reponsePanneCode`). C'est une PANNE, et elle ne
  /// ressemble à aucun autre refus de ces routes : le serveur n'a RIEN écrit,
  /// aucun essai n'a été compté contre la personne, son code est intact.
  /// Auparavant le même hoquet sortait en « Code OTP invalide ou expiré » et
  /// comptait un essai fautif — un refus fabriqué par une panne.
  ///
  /// L'écran ne peut pas deviner la différence en lisant la phrase : le type la
  /// porte. Voir [PanneServeur], et `otp.dart` qui en fait le seul
  /// « Réessayer » de ce parcours.
  ///
  /// SEUL LE 503, ET PLUS « TOUT 5xx ». La ligne testait `>= 500` sous un
  /// commentaire qui disait « ils disent la même chose — le serveur n'a rien pu
  /// faire ». C'était FAUX exactement sur `/auth/verification` : ce 500-là
  /// tombait APRÈS que le serveur avait consommé le code ET validé le compte,
  /// si bien que l'écran affichait « votre code n'a pas été utilisé, réessayez »
  /// sur un code mort et un compte déjà valide — trois affirmations fausses
  /// d'un coup. Le serveur a corrigé la cause en ouvrant la session AVANT toute
  /// écriture irréversible, et ce qui reste sur ces routes est un VRAI 503
  /// (verification.go:200-216, otp.go:425-437) : notre phrase y devient vraie
  /// mot pour mot. Un 5xx qui n'est PAS 503 — passerelle, relais, 500 d'un
  /// serveur plus ancien — redevient une erreur ordinaire : elle s'affiche sans
  /// rien affirmer sur le sort du code. C'est l'état d'avant, et il ne mentait
  /// pas. Le site tient la même règle (`estUnePanne`, src/lib/erreur.ts).
  Never _leverSurLesRoutesDeCode(http.Response response, String repli) {
    final message = messageDeLaReponse(response, repli: repli);
    if (response.statusCode == 503) throw PanneServeur(message);
    throw Exception(message);
  }

  /// ✅ Vérifier la validation d'inscription
  Future<TokenUser?> verifyRegistration(String email, String otp) async {
    final url = Uri.parse(ApiRoutes.verifyRegistration);
    final body = jsonEncode({"email": email, "otp": otp});
    final response = await client.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: body,
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      final tokenUser = TokenUser.fromJson(jsonDecode(response.body));
      // La session ouverte ici est refermée quelques instants plus tard par
      // otp.dart (SessionService.terminer) : reprogrammer des rappels serait
      // courir contre cette purge. Cf. [_ouvrirSession].
      await _ouvrirSession(tokenUser, reprendreLesRappels: false);
      return tokenUser;
    }

    // LE COMPTE EST DÉJÀ VALIDÉ : C'EST UNE SORTIE, PAS UN ÉCHEC DE PLUS.
    //
    // Le serveur pose `deja_verifie: true` sur ce 400 (space_learn_auth,
    // controllers/verification.go:133-139 et :153-158), par ses DEUX portes :
    // code encore vivant, et code réel mais mort. C'est la porte de sortie des
    // gens que la version en production a enfermés — compte validé, code
    // consommé, 500 rendu par-dessus. Sans ce type, la phrase du serveur
    // arrivait à l'écran comme un refus quelconque et l'écran laissait la
    // personne devant ses six cases, à ressaisir un code qui ne servira plus
    // jamais. Voir [CompteDejaValide] : c'est un refus de DROIT — aucun
    // « Réessayer » — dont l'écran fait une navigation vers la connexion.
    if (response.statusCode == 400) {
      final corps = _corpsJson(response.body);
      if (corps != null && corps["deja_verifie"] == true) {
        throw CompteDejaValide(
          messageDeLaReponse(
            response,
            repli:
                "Votre compte est déjà validé : connectez-vous pour continuer.",
          ),
        );
      }
    }

    // Le corps était lu à la main — `errorData['error']` sans filtre, sans le
    // cas du 401, et sans distinguer la panne du refus : une trace technique ou
    // du HTML de passerelle arrivaient tels quels sur l'écran de saisie du
    // code. `messageDeLaReponse` fait le tri, et
    // [_leverSurLesRoutesDeCode] donne au 503 la nature qui lui vaut un
    // « Réessayer ».
    _leverSurLesRoutesDeCode(
      response,
      "La validation de l'inscription n'a pas abouti.",
    );
  }

  /// Demander un code de réinitialisation.
  ///
  /// Même contrat que [sendOtp], et pour les mêmes raisons : la phrase du
  /// serveur est rendue telle quelle, parce qu'elle est la seule chose vraie
  /// qu'on puisse dire sans révéler à un inconnu si cette adresse a un compte.
  /// Elle vaut « Si un compte est associé à cet e-mail, un code de
  /// réinitialisation a été envoyé. Si vous ne le recevez pas, redemandez-en un
  /// dans une minute. » (space_learn_auth, controllers/otp.go:484-485).
  ///
  /// C'est ICI que la panne coûte le plus cher — la personne qui a perdu son
  /// mot de passe n'a pas d'autre porte —, et c'est ici que le serveur rendait
  /// 200 « un code a été envoyé » sur une base injoignable. Il rend maintenant
  /// 503 avec sa phrase de panne (otp.go:507).
  Future<String> forgotPassword(String email) async {
    final response = await client.post(
      Uri.parse(ApiRoutes.forgotPassword),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email}),
    );
    if (response.statusCode == 200) {
      return _phraseDEnvoi(
        response,
        repli:
            "Si un compte est associé à cette adresse, un code de "
            "réinitialisation a été envoyé. Si vous ne le recevez pas, "
            "redemandez-en un dans une minute.",
      );
    }
    throw Exception(
      messageDeLaReponse(response, repli: "L'envoi du code a échoué."),
    );
  }

  /// Choisir un nouveau mot de passe.
  ///
  /// Le serveur refuse notamment un mot de passe trop faible, et le disait :
  /// l'écran affichait pourtant « Impossible de réinitialiser le mot de passe »,
  /// sans jamais indiquer ce qui manquait.
  Future<bool> resetPassword(
    String email,
    String otp,
    String newPassword,
  ) async {
    final response = await client.post(
      Uri.parse(ApiRoutes.resetPassword),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "email": email,
        "otp": otp,
        "new_password": newPassword,
      }),
    );
    if (response.statusCode == 200) return true;
    // Troisième route de code : même 503 de panne, même traitement. Voir
    // [_leverSurLesRoutesDeCode].
    _leverSurLesRoutesDeCode(response, "La réinitialisation n'a pas abouti.");
  }

  /// ✅ Obtenir le profil utilisateur
  Future<UserModel?> getUser(String token) async {
    final url = Uri.parse(ApiRoutes.getUser);
    final response = await client.get(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );
    if (response.statusCode == 200) {
      return UserModel.fromJson(jsonDecode(response.body));
    }

    // Le corps de la réponse ne remonte plus tel quel.
    //
    // `"Erreur de récupération du profil : ${response.body}"` a produit, à
    // l'écran d'accueil, la phrase « Erreur de récupération du profil :
    // {"error":"Token invalide ou expiré"} ». Le JSON du serveur y était
    // recopié mot pour mot, accolades comprises.
    throw Exception(
      messageDeLaReponse(
        response,
        repli: "Impossible de charger votre profil.",
      ),
    );
  }

  /// ✅ Met à jour le profil pour l'utilisateur connecté et retourne le token mis à jour.
  Future<TokenUser> updateProfileForUser(String profileId) async {
    final currentToken = await TokenStorage.getToken();
    if (currentToken == null) {
      throw Exception(
        "Utilisateur non authentifié. Impossible de mettre à jour le profil.",
      );
    }

    final url = Uri.parse(ApiRoutes.selectProfile);
    final body = jsonEncode({"profil_id": profileId});
    final response = await client.post(
      // ou http.patch, selon ce que le backend attend
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $currentToken",
      },
      body: body,
    );
    if (response.statusCode == 200) {
      final tokenUser = TokenUser.fromJson(jsonDecode(response.body));
      await TokenStorage.saveToken(tokenUser.token);
      await TokenStorage.saveRefreshToken(tokenUser.refreshToken);
      return tokenUser;
    } else {
      String errorMessage = "Erreur lors de la mise à jour du profil.";
      try {
        final errorData = jsonDecode(response.body);
        errorMessage =
            errorData['error'] ?? "Erreur lors de la mise à jour du profil.";
      } catch (_) {
        errorMessage = "Erreur de mise à jour : Statut ${response.statusCode}";
      }
      throw Exception(errorMessage);
    }
  }

  /// ✅ Met à jour les détails additionnels (nom_complet, biographie, liens, wallet, telephone, sexe, date_naissance)
  Future<UserModel> updateProfileDetails({
    required String userId,
    String? nomComplet,
    String? biography,
    String? profilePhoto,
    String? socialLinks,
    String? walletAddress,
    String? telephone,
    String? sexe,
    String? dateNaissance,
  }) async {
    final currentToken = await TokenStorage.getToken();
    if (currentToken == null) {
      throw Exception("Non authentifié.");
    }

    // Le backend attend un PUT sur /utilisateurs/:id
    final url = Uri.parse("${ApiRoutes.baseUrl}/utilisateurs/$userId");
    final body = jsonEncode({
      if (nomComplet != null) "nom_complet": nomComplet,
      if (biography != null) "biography": biography,
      if (profilePhoto != null) "profile_photo": profilePhoto,
      if (socialLinks != null) "social_links": socialLinks,
      if (walletAddress != null) "wallet_address": walletAddress,
      if (telephone != null) "telephone": telephone,
      if (sexe != null) "sexe": sexe,
      if (dateNaissance != null) "date_naissance": dateNaissance,
    });

    final response = await client.put(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $currentToken",
      },
      body: body,
    );

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      // Le backend retourne {"message": "...", "user": {...}}
      return UserModel.fromJson(responseData['user']);
    } else {
      String errorMessage = "Erreur lors de l'enregistrement des détails.";
      try {
        final errorData = jsonDecode(response.body);
        errorMessage = errorData['error'] ?? errorMessage;
      } catch (_) {}
      throw Exception(errorMessage);
    }
  }

  /// Demande la suppression du compte au serveur — DELETE /utilisateurs/:id.
  ///
  /// CE QUE LE SERVEUR FAIT VRAIMENT (space_learn_auth, controllers/user.go
  /// DeleteAccount) : il FERME le compte sur-le-champ — statut « supprime »,
  /// nom affiché remplacé par « Utilisateur Anonymisé », date de suppression —
  /// et révoque toutes les sessions ; `PeutOuvrirSession` (models/user.go)
  /// referme la porte. Les autres informations restent en base le temps du
  /// délai de grâce, puis `service.PurgerComptesSupprimes` — la tâche
  /// périodique montée dans routes/routes.go — efface l'adresse, le pseudo,
  /// le téléphone, la date de naissance, le sexe, la photo, la biographie, les
  /// liens sociaux et le portefeuille.
  ///
  /// CE PARAGRAPHE A DÉJÀ MENTI UNE FOIS, et il faut savoir pourquoi. Il
  /// décrivait un serveur qui ne faisait que les trois affectations, sans
  /// aucune purge — c'était exact à l'époque, et c'est resté écrit ici après
  /// que le serveur eut changé. Un commentaire qui décrit l'ancien serveur
  /// fera reposer le défaut par le prochain lecteur : celui qui lit « aucun
  /// travail périodique ne lit deleted_at » corrigera l'écran pour qu'il cesse
  /// de promettre trente jours — alors que le serveur les tient.
  ///
  /// Rien n'est fait tant que le serveur n'a pas répondu 200 : l'écran
  /// affichait auparavant « demande transmise » après un simple nettoyage
  /// local, sans qu'aucune requête ne parte — le compte restait pleinement
  /// actif en base.
  ///
  /// NE REND PAS LE MESSAGE DU SERVEUR, et c'est délibéré — mais la
  /// justification n'est plus la même, et ce paragraphe l'a déjà eue fausse.
  ///
  /// LA PHRASE DU SERVEUR, AUJOURD'HUI, MOT POUR MOT (controllers/user.go,
  /// DeleteAccount) : « Votre compte a été fermé et vos appareils déconnectés.
  /// Votre nom n'est plus affiché. Vos données personnelles seront effacées le
  /// JJ/MM/AAAA ; d'ici là, reconnectez-vous — par mot de passe ou avec
  /// Google — pour annuler la suppression. Votre adresse e-mail reste réservée
  /// jusqu'à cette date : elle ne peut pas servir à un nouveau compte avant. »
  ///
  /// Ce paragraphe la citait encore sous la forme « d'ici là, écrivez au
  /// support pour annuler » : le serveur ne dit PLUS cela, et l'unique raison
  /// invoquée pour ne pas l'afficher — « elle dit d'écrire au support sans
  /// donner d'adresse » — avait donc cessé d'exister. La vraie raison, la
  /// seule qui tienne, est que l'écran dit tout ce que dit cette phrase ET
  /// l'adresse où écrire quand la reconnexion est refusée. Si un jour l'écran
  /// cesse de le faire, c'est le message du serveur qu'il faut afficher, pas
  /// une phrase à nous.
  ///
  /// LES DEUX DIALOGUES DISENT BIEN LES MÊMES FAITS, et c'est cette
  /// vérification-là qui autorise le silence : fermeture immédiate, nom
  /// retiré, effacement à trente jours, RECONNEXION (par mot de passe ou avec
  /// Google) comme geste d'annulation, adresse réservée jusqu'à la purge, et
  /// `adresseContact` en second recours. Voir
  /// `settings/suppression_compte.dart`.
  ///
  /// SAUF DANS UN CAS, ET IL EST NEUF : quand la personne est encore
  /// CRÉDITEUSE. Le serveur écrit alors une AUTRE phrase — elle nomme la somme
  /// due, et surtout elle NE PROMET PLUS de date d'effacement, parce que la
  /// purge est retenue tant que l'argent n'est pas versé (la purge effacerait
  /// la seule destination de virement enregistrée). Le texte fixe des deux
  /// dialogues, lui, continue de dire « effacées dans trente jours » : c'est
  /// exactement le genre de promesse que le serveur ne tiendrait pas. Dans ce
  /// cas-là, et dans celui-là seulement, [SuppressionDemandee.message] est
  /// affiché TEL QUEL à la place. Voir `settings/suppression_compte.dart`.
  Future<SuppressionDemandee> deleteAccount() async {
    final token = await TokenStorage.getToken();
    if (token == null || token.isEmpty) {
      throw Exception("Vous devez être connecté pour supprimer votre compte.");
    }

    // La route porte l'identifiant du compte, et le serveur vérifie qu'il est
    // bien celui du jeton présenté.
    final userId = await TokenStorage.getUserId();
    if (userId == null || userId.isEmpty) {
      throw Exception("Session incomplète. Reconnectez-vous puis réessayez.");
    }

    final response = await client.delete(
      Uri.parse("${ApiRoutes.baseUrl}/utilisateurs/$userId"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode == 200) {
      final corps = _corpsJson(response.body);
      final message = corps?['message'];
      // Le message du serveur reste utile au diagnostic même quand l'écran ne
      // l'affiche pas : c'est ici qu'on verra, dans les journaux, le jour où sa
      // phrase changera sans que les deux dialogues aient suivi.
      if (message is String && message.trim().isNotEmpty) {
        debugPrint('Suppression du compte : réponse du serveur — $message');
      }
      final brut = corps?['reste_du'];
      final resteDu = brut is num
          ? brut.toDouble()
          : double.tryParse('$brut') ?? 0.0;
      return SuppressionDemandee(
        message: message is String ? message.trim() : '',
        resteDu: resteDu,
        devise: corps?['devise']?.toString() ?? 'XOF',
        effacementRetenu: corps?['effacement_retenu'] == true,
      );
    }

    throw Exception(
      messageDeLaReponse(
        response,
        repli: "La suppression du compte n'a pas abouti.",
      ),
    );
  }

  /// Modifier le mot de passe d'un utilisateur connecté.
  ///
  /// La route porte l'identifiant du compte et se demande en POST. Elle était
  /// appelée en PUT sur `/utilisateurs/change-password` : comme `PUT /:id`
  /// existe, la requête tombait sur la modification de profil avec
  /// « change-password » pour identifiant, et le serveur répondait
  /// « Identifiant utilisateur invalide ». Le changement de mot de passe
  /// n'avait jamais pu aboutir.
  ///
  /// Les deux champs sont ceux du serveur, et eux seuls. Les envoyer sous six
  /// noms différents en espérant qu'un tombe juste multipliait les copies du
  /// mot de passe en clair dans la requête, dans les journaux du proxy et dans
  /// ceux du serveur, sans jamais dire lequel était le bon.
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final currentToken = await TokenStorage.getToken();
    if (currentToken == null) {
      throw Exception(
        "Vous devez être connecté pour modifier votre mot de passe.",
      );
    }

    final userId = await TokenStorage.getUserId();
    if (userId == null || userId.isEmpty) {
      throw Exception("Session incomplète. Reconnectez-vous puis réessayez.");
    }

    final url = Uri.parse(ApiRoutes.changePassword(userId));
    final corps = jsonEncode({
      "current_password": currentPassword,
      "new_password": newPassword,
    });

    // L'envoi est extrait parce qu'il peut avoir lieu deux fois — et parce que
    // le marqueur doit accompagner les DEUX envois : chacun peut se heurter au
    // refus métier.
    //
    // Le marqueur n'est posé QUE si le client est l'intercepteur : lui seul le
    // retire avant l'envoi (cf. [_intercepteur]). Sur un autre client, il
    // partirait sur le réseau sans rien garder en échange.
    final intercepteur = _intercepteur;
    Future<http.Response> envoyer(String jeton) => client.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $jeton",
        if (intercepteur != null) ApiClient.enTete401Metier: '1',
      },
      body: corps,
    );

    var response = await envoyer(currentToken);

    // Un 401 ici ne dit pas une seule chose, et c'est tout le problème.
    //
    // Le serveur en produit deux sur cette route : « Ancien mot de passe
    // incorrect » (controllers/user.go, ChangePassword) et « Token invalide ou
    // expiré » (middleware/auth.go). Le premier est MÉTIER — aucun jeton neuf
    // ne le répare, et le rejeu automatique d'ApiClient ne faisait que renvoyer
    // le même mot de passe faux, en clair, une seconde fois. Le second est bien
    // une session à renouveler. Seul le corps les sépare : c'est donc ici, et
    // pas dans la couche transport, que la décision se prend.
    // Sans intercepteur (client injecté par un test), il n'y a ni
    // renouvellement ni déconnexion à mener : le 401 remonte tel quel à
    // l'appelant, avec le message du serveur. C'est le comportement honnête —
    // et non un détour par le singleton, qui aurait touché le vrai réseau.
    if (intercepteur != null &&
        response.statusCode == 401 &&
        !_ancienMotDePasseRefuse(response.body)) {
      final verdict = await intercepteur.renouvelerSession();

      if (verdict == Renouvellement.reussi) {
        final neuf = await TokenStorage.getToken();
        // `neuf != currentToken` : sans jeton réellement différent, réessayer
        // ne ferait que promener le mot de passe une fois de plus pour le même
        // refus.
        if (neuf != null && neuf.isNotEmpty && neuf != currentToken) {
          response = await envoyer(neuf);
        }
      } else if (ApiClient.sessionTerminee(verdict)) {
        // Le refus de `/auth/refresh` est le SEUL verdict qui finit une
        // session, et jusqu'ici c'était `send` qui en tirait la conséquence.
        // Le marqueur l'ayant mis hors circuit, le relais se fait ici : sinon
        // la personne restait sur l'écran des réglages, avec la phrase brute du
        // serveur et une session morte. Une panne de réseau (`indisponible`),
        // elle, ne déconnecte personne : on laisse remonter le message du
        // serveur et l'écran propose de recommencer.
        intercepteur.constaterSessionFinie();
        throw Exception(
          "Votre session a expiré. Reconnectez-vous, puis réessayez.",
        );
      }
    }

    if (response.statusCode == 200 || response.statusCode == 204) {
      return true;
    } else {
      String errorMessage = "Impossible de modifier le mot de passe.";
      try {
        final errorData = jsonDecode(response.body);
        if (errorData is Map) {
          errorMessage =
              errorData['error'] ?? errorData['message'] ?? errorMessage;
        }
      } catch (_) {}
      throw Exception(errorMessage);
    }
  }

  /// Ce 401-là est-il le refus MÉTIER de l'ancien mot de passe ?
  ///
  /// Le doute se tranche volontairement DU CÔTÉ DE LA SESSION : un corps
  /// illisible, ou un message que le serveur aurait reformulé, rend `false` et
  /// donc le comportement d'avant — renouveler, réessayer. Une reformulation
  /// coûtera un aller-retour de trop ; elle ne cassera jamais le changement de
  /// mot de passe de quelqu'un dont le jeton venait d'expirer. L'inverse — se
  /// tromper du côté métier — laisserait cette personne devant un « Token
  /// invalide ou expiré » qu'un simple renouvellement aurait levé.
  bool _ancienMotDePasseRefuse(String corps) {
    final json = _corpsJson(corps);
    if (json == null) return false;
    final message = '${json['error'] ?? json['message'] ?? ''}'.toLowerCase();
    return message.contains('ancien mot de passe');
  }
}
