import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stockage de la session.
///
/// Le JWT est conservé dans le coffre chiffré de la plateforme (Keystore sur
/// Android, Keychain sur iOS) et non dans SharedPreferences, qui est lisible en
/// clair sur un appareil rooté ou jailbreaké.
///
/// Les données non sensibles (nom affiché, dates de dernière consultation)
/// restent dans SharedPreferences : le coffre est nettement plus lent et n'a
/// aucun intérêt pour elles.
class TokenStorage {
  static const String _tokenKey = "auth_token";
  static const String _userNameKey = "user_name";

  /// Identifiant du compte connecté.
  ///
  /// Les statistiques de lecture sont rangées par utilisateur, et chaque écran
  /// les rangeait sous une clé différente : la page de lecture sous une chaîne
  /// vide, la page d'accueil sous l'identifiant du compte, les badges sous
  /// celui du *profil* — c'est-à-dire la même valeur pour tous les lecteurs de
  /// l'application. Ce qu'on écrivait, personne ne le relisait.
  ///
  /// Une seule source, ici, à côté du jeton dont il est issu.
  static const String _userIdKey = "user_id";

  // Chiffrement par défaut de la plateforme : Keystore sur Android,
  // Keychain sur iOS.
  static const FlutterSecureStorage _secure = FlutterSecureStorage();

  /// Sauvegarder le token
  static Future<void> saveToken(String token) async {
    await _secure.write(key: _tokenKey, value: token);
  }

  /// Récupérer le token
  ///
  /// Migre de façon transparente un token laissé par une version précédente
  /// dans SharedPreferences, puis l'y supprime.
  static Future<String?> getToken() async {
    final token = await _secure.read(key: _tokenKey);
    if (token != null && token.isNotEmpty) return token;

    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString(_tokenKey);
    if (legacy != null && legacy.isNotEmpty) {
      await _secure.write(key: _tokenKey, value: legacy);
      await prefs.remove(_tokenKey);
      return legacy;
    }
    return null;
  }

  /// Supprimer le token (logout)
  static Future<void> clearToken() async {
    await _secure.delete(key: _tokenKey);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey); // résidu d'une version antérieure
    await prefs.remove(_userNameKey);
    // Sans cela, le lecteur suivant sur le même téléphone héritait du temps de
    // lecture, de la série de jours et des titres lus par le précédent.
    await prefs.remove(_userIdKey);
  }

  /// Sauvegarder l'identifiant du compte connecté.
  static Future<void> saveUserId(String id) async {
    if (id.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userIdKey, id.trim());
  }

  /// Récupérer l'identifiant du compte connecté.
  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_userIdKey);
    if (id == null || id.trim().isEmpty) return null;
    return id.trim();
  }

  /// Vérifier si connecté
  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// Sauvegarder le nom de l'utilisateur
  static Future<void> saveUserName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userNameKey, name);
  }

  /// Récupérer le nom de l'utilisateur
  static Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userNameKey);
  }

  /// Sauvegarder la date de dernière vue d'une discussion
  static Future<void> saveDiscussionLastViewed(String discussionId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      "discussion_viewed_$discussionId",
      DateTime.now().toIso8601String(),
    );
  }

  /// Récupérer la date de dernière vue d'une discussion
  static Future<DateTime?> getDiscussionLastViewed(String discussionId) async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getString("discussion_viewed_$discussionId");
    if (val != null) return DateTime.tryParse(val);
    return null;
  }
}
