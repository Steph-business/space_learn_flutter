import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:space_learn_flutter/core/space_learn/data/model/profilModel.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/tokenUser.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/userModel.dart';
import 'package:space_learn_flutter/core/utils/api_routes.dart';
import 'package:space_learn_flutter/core/utils/profileStorage.dart';
import 'package:space_learn_flutter/core/utils/tokenStorage.dart';

class AuthService {
  /// ✅ Inscription
  Future<TokenUser?> register({
    required String nomComplet,
    required String email,
    required String password,
    required String profilId,
  }) async {
    final url = Uri.parse(ApiRoutes.register);
    final body = jsonEncode({
      "nom_complet": nomComplet,
      "email": email,
      "password": password,
      "profil_id": profilId,
    });

    print("▶️ REGISTER: POST $url");
    print("   Body: $body");

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: body,
    );

    print("◀️ REGISTER: Response ${response.statusCode}");
    print("   Body: ${response.body}");

    if (response.statusCode == 201) {
      final tokenUser = TokenUser.fromJson(jsonDecode(response.body));
      // ✅ On sauvegarde le token après l'inscription
      await TokenStorage.saveToken(tokenUser.token);
      return tokenUser;
    } else {
      String errorMessage = "Erreur d'inscription inconnue.";
      try {
        final errorData = jsonDecode(response.body);
        errorMessage =
            errorData['error'] ?? "Erreur d'inscription : ${response.body}";
      } catch (_) {
        errorMessage = "Erreur d'inscription : Statut ${response.statusCode}";
      }
      print("   Error: $errorMessage");
      throw Exception(errorMessage);
    }
  }

  /// ✅ Connexion
  Future<TokenUser> login(String email, String password) async {
    final url = Uri.parse(ApiRoutes.login);
    final body = jsonEncode({"email": email, "password": password});

    // print("▶️ LOGIN: POST $url");
    // print("   Body: $body");

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: body,
    );

    // print("◀️ LOGIN: Response ${response.statusCode}");
    // print("   Body: ${response.body}");

    if (response.statusCode == 200 || response.statusCode == 201) {
      final tokenUser = TokenUser.fromJson(jsonDecode(response.body));
      // ✅ On sauvegarde le token après la connexion
      await TokenStorage.saveToken(tokenUser.token);
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
      print("   Error: $errorMessage");
      throw Exception(errorMessage);
    }
  }

  /// ✅ Déconnexion
  Future<void> logout() async {
    final token = await TokenStorage.getToken();
    if (token != null) {
      try {
        final url = Uri.parse(ApiRoutes.logout);
        print("▶️ LOGOUT: POST $url");
        final response = await http.post(
          url,
          headers: {
            "Content-Type": "application/json",
            "Authorization": "Bearer $token",
          },
        );
        print("◀️ LOGOUT: Response ${response.statusCode}");
        print("   Body: ${response.body}");
      } catch (e) {
        // Gérer l'erreur de déconnexion côté serveur, mais continuer la déconnexion locale
        print("   Error on LOGOUT: $e");
      }
    }
    // ✅ On supprime le token localement dans tous les cas
    await TokenStorage.clearToken();
  }

  /// ✅ Envoyer OTP (ex: email/sms)
  Future<bool> sendOtp(String email) async {
    final url = Uri.parse(ApiRoutes.sendOtp);
    final body = jsonEncode({"email": email});
    print("▶️ SEND OTP: POST $url");
    print("   Body: $body");
    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: body,
    );
    print("◀️ SEND OTP: Response ${response.statusCode}");
    print("   Body: ${response.body}");
    return response.statusCode == 200;
  }

  /// ✅ Vérifier OTP
  Future<bool> verifyOtp(String email, String otp) async {
    final url = Uri.parse(ApiRoutes.verifyOtp);
    final body = jsonEncode({"email": email, "otp": otp});
    print("▶️ VERIFY OTP: POST $url");
    print("   Body: $body");
    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: body,
    );
    print("◀️ VERIFY OTP: Response ${response.statusCode}");
    print("   Body: ${response.body}");
    return response.statusCode == 200;
  }

  /// ✅ Mot de passe oublié (envoi email/OTP)
  Future<bool> forgotPassword(String email) async {
    final url = Uri.parse(ApiRoutes.forgotPassword);
    final body = jsonEncode({"email": email});
    print("▶️ FORGOT PASSWORD: POST $url");
    print("   Body: $body");
    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: body,
    );
    print("◀️ FORGOT PASSWORD: Response ${response.statusCode}");
    print("   Body: ${response.body}");
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
    print("▶️ RESET PASSWORD: POST $url");
    print("   Body: $body");
    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: body,
    );
    print("◀️ RESET PASSWORD: Response ${response.statusCode}");
    print("   Body: ${response.body}");
    return response.statusCode == 200;
  }

  /// ✅ Obtenir le profil utilisateur
  Future<UserModel?> getUser(String token) async {
    final url = Uri.parse(ApiRoutes.getUser);
    print("▶️ GET USER: GET $url");
    final response = await http.get(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    print("◀️ GET USER: Response ${response.statusCode}");
    print("   Body: ${response.body}");

    if (response.statusCode == 200) {
      return UserModel.fromJson(jsonDecode(response.body));
    } else {
      print("   Error: Erreur de récupération du profil : ${response.body}");
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

    print("▶️ UPDATE PROFILE: PUT $url");
    print("   Body: $body");

    final response = await http.post(
      // ou http.patch, selon ce que le backend attend
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $currentToken",
      },
      body: body,
    );

    print("◀️ UPDATE PROFILE: Response ${response.statusCode}");
    print("   Body: ${response.body}");

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
}
