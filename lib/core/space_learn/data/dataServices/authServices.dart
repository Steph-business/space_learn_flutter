import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:space_learn_flutter/core/space_learn/data/model/tokenUser.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/user_model.dart';
import 'package:space_learn_flutter/core/utils/api_routes.dart';
import 'package:space_learn_flutter/core/utils/token_storage.dart';
import 'package:space_learn_flutter/core/services/session_service.dart';

class AuthService {
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
    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: body,
    );
    if (response.statusCode == 201) {
      return true;
    } else {
      String errorMessage = "Erreur d'inscription inconnue.";
      try {
        final errorData = jsonDecode(response.body);
        errorMessage =
            errorData['error'] ?? "Erreur d'inscription : ${response.body}";
      } catch (_) {
        errorMessage = "Erreur d'inscription : Statut ${response.statusCode}";
      }
      throw Exception(errorMessage);
    }
  }

  /// ✅ Connexion
  Future<TokenUser> login(String email, String password) async {
    final url = Uri.parse(ApiRoutes.login);
    final body = jsonEncode({"email": email, "password": password});
    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: body,
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      final tokenUser = TokenUser.fromJson(jsonDecode(response.body));
      // ✅ On sauvegarde le token après la connexion
      await TokenStorage.saveToken(tokenUser.token);
      await TokenStorage.saveUserName(tokenUser.user.nomComplet);
      return tokenUser;
    } else {
      String errorMessage = "Erreur de connexion inconnue.";
      try {
        final errorData = jsonDecode(response.body);
        errorMessage =
            errorData['error'] ?? "Erreur de connexion : ${response.body}";
      } catch (_) {
        errorMessage = "Erreur de connexion : Statut ${response.statusCode}";
      }
      throw Exception(errorMessage);
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
    final response = await http.post(
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
      await TokenStorage.saveUserName(tokenUser.user.nomComplet);
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
    if (token != null) {
      try {
        final url = Uri.parse(ApiRoutes.logout);
        final response = await http.post(
          url,
          headers: {
            "Content-Type": "application/json",
            "Authorization": "Bearer $token",
          },
        );
      } catch (e) {
        // Gérer l'erreur de déconnexion côté serveur, mais continuer la déconnexion locale
      }
    }
    // La session locale est effacee dans tous les cas, y compris si l'appel
    // serveur a echoue : jeton, profil et livres telecharges.
    await SessionService.terminer();
  }

  /// ✅ Envoyer OTP (ex: email/sms)
  Future<bool> sendOtp(String email) async {
    final url = Uri.parse(ApiRoutes.sendOtp);
    final body = jsonEncode({"email": email});
    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: body,
    );
    return response.statusCode == 200;
  }

  /// ✅ Vérifier OTP
  Future<bool> verifyOtp(String email, String otp) async {
    final url = Uri.parse(ApiRoutes.verifyOtp);
    final body = jsonEncode({"email": email, "otp": otp});
    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: body,
    );
    return response.statusCode == 200;
  }

  /// ✅ Vérifier la validation d'inscription
  Future<TokenUser?> verifyRegistration(String email, String otp) async {
    final url = Uri.parse(ApiRoutes.verifyRegistration);
    final body = jsonEncode({"email": email, "otp": otp});
    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: body,
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      final tokenUser = TokenUser.fromJson(jsonDecode(response.body));
      await TokenStorage.saveToken(tokenUser.token);
      await TokenStorage.saveUserName(tokenUser.user.nomComplet);
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

  /// ✅ Mot de passe oublié (envoi email/OTP)
  Future<bool> forgotPassword(String email) async {
    final url = Uri.parse(ApiRoutes.forgotPassword);
    final body = jsonEncode({"email": email});
    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: body,
    );
    return response.statusCode == 200;
  }

  /// ✅ Réinitialiser mot de passe
  Future<bool> resetPassword(
    String email,
    String otp,
    String newPassword,
  ) async {
    final url = Uri.parse(ApiRoutes.resetPassword);
    final body = jsonEncode({
      "email": email,
      "otp": otp,
      "new_password": newPassword,
    });
    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: body,
    );
    return response.statusCode == 200;
  }

  /// ✅ Obtenir le profil utilisateur
  Future<UserModel?> getUser(String token) async {
    final url = Uri.parse(ApiRoutes.getUser);
    final response = await http.get(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );
    if (response.statusCode == 200) {
      return UserModel.fromJson(jsonDecode(response.body));
    } else {
      throw Exception("Erreur de récupération du profil : ${response.body}");
    }
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
    final response = await http.post(
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

    final response = await http.put(
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
}
