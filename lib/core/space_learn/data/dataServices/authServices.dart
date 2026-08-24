import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:space_learn_flutter/core/space_learn/data/model/tokenUser.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/user_model.dart';
import 'package:space_learn_flutter/core/utils/api_routes.dart';
import 'package:space_learn_flutter/core/utils/token_storage.dart';
import 'package:space_learn_flutter/core/services/api_client.dart';
import 'package:space_learn_flutter/core/services/session_service.dart';
import 'package:space_learn_flutter/core/utils/message_erreur.dart';

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
  });

  final String email;
  final bool codeEnvoye;
  final String message;

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

  AuthService({http.Client? client}) : client = client ?? ApiClient.instance;

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
      debugPrint('\n╔══ DIAGNOSTIC LOGIN ═══════════════════════');
      debugPrint('║ Token reçu : ${tokenUser.token.isNotEmpty}');
      debugPrint('║ Refresh token reçu : "${tokenUser.refreshToken}"');
      debugPrint('║ Refresh vide ? ${tokenUser.refreshToken.isEmpty}');
      debugPrint('║ Clés JSON : ${jsonDecode(response.body).keys.toList()}');
      debugPrint('╚════════════════════════════════════════════\n');
      // ✅ On sauvegarde le token après la connexion
      await TokenStorage.saveToken(tokenUser.token);
      await TokenStorage.saveRefreshToken(tokenUser.refreshToken);
      await TokenStorage.saveUserName(tokenUser.user.nomComplet);
      // Le temps de lecture, la série de jours et les badges sont rangés par
      // compte : sans cet identifiant ils se mélangeaient entre les personnes
      // qui se connectent sur un même téléphone.
      await TokenStorage.saveUserId(tokenUser.user.id);
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
        );
      }
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
      await TokenStorage.saveToken(tokenUser.token);
      await TokenStorage.saveRefreshToken(tokenUser.refreshToken);
      await TokenStorage.saveUserName(tokenUser.user.nomComplet);
      // Le temps de lecture, la série de jours et les badges sont rangés par
      // compte : sans cet identifiant ils se mélangeaient entre les personnes
      // qui se connectent sur un même téléphone.
      await TokenStorage.saveUserId(tokenUser.user.id);
      return tokenUser;
    }

    if (response.statusCode == 501) {
      throw Exception("La connexion Google n'est pas activée sur le serveur.");
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
  Future<bool> sendOtp(String email) async {
    final response = await client.post(
      Uri.parse(ApiRoutes.sendOtp),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email}),
    );
    if (response.statusCode == 200) return true;
    throw Exception(
      messageDeLaReponse(response, repli: "L'envoi du code a échoué."),
    );
  }

  /// Vérifier un code reçu par e-mail.
  Future<bool> verifyOtp(String email, String otp) async {
    final response = await client.post(
      Uri.parse(ApiRoutes.verifyOtp),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email, "otp": otp}),
    );
    if (response.statusCode == 200) return true;
    throw Exception(
      messageDeLaReponse(response, repli: "Ce code n'a pas pu être vérifié."),
    );
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
      await TokenStorage.saveToken(tokenUser.token);
      await TokenStorage.saveRefreshToken(tokenUser.refreshToken);
      await TokenStorage.saveUserName(tokenUser.user.nomComplet);
      // Le temps de lecture, la série de jours et les badges sont rangés par
      // compte : sans cet identifiant ils se mélangeaient entre les personnes
      // qui se connectent sur un même téléphone.
      await TokenStorage.saveUserId(tokenUser.user.id);
      return tokenUser;
    } else {
      String errorMessage = "Erreur de validation de l'inscription.";
      try {
        final errorData = jsonDecode(response.body);
        errorMessage = errorData['error'] ?? errorMessage;
      } catch (_) {}
      throw Exception(errorMessage);
    }
  }

  /// Demander un code de réinitialisation.
  Future<bool> forgotPassword(String email) async {
    final response = await client.post(
      Uri.parse(ApiRoutes.forgotPassword),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email}),
    );
    if (response.statusCode == 200) return true;
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
    throw Exception(
      messageDeLaReponse(
        response,
        repli: "La réinitialisation n'a pas abouti.",
      ),
    );
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
    final response = await client.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $currentToken",
      },
      body: jsonEncode({
        "current_password": currentPassword,
        "new_password": newPassword,
      }),
    );

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
}
