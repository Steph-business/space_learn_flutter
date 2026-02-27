import 'package:shared_preferences/shared_preferences.dart';

class TokenStorage {
  static const String _tokenKey = "auth_token";
  static const String _userNameKey = "user_name";

  /// Sauvegarder le token
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
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

  /// Récupérer le token
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  /// Supprimer le token (logout)
  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userNameKey);
  }

  /// Vérifier si connecté
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_tokenKey);
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
