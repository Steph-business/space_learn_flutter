import 'package:shared_preferences/shared_preferences.dart';

class ProfileStorage {
  static const String _selectedProfileKey = "selected_profile_id";
  static const String _selectedProfileRoleKey = "selected_profile_role";

  // Sauvegarder le profil sélectionné (id)
  static Future<void> saveSelectedProfile(String profileId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedProfileKey, profileId);
  }

  // Récupérer le profil sélectionné
  static Future<String?> getSelectedProfile() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_selectedProfileKey);
  }

  // Supprimer le profil sélectionné
  static Future<void> clearSelectedProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_selectedProfileKey);
  }

  // Sauvegarder le rôle du profil sélectionné
  static Future<void> saveSelectedProfileRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedProfileRoleKey, role);
  }

  // Récupérer le rôle du profil sélectionné
  static Future<String?> getSelectedProfileRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_selectedProfileRoleKey);
  }

  // Supprimer le rôle du profil sélectionné
  static Future<void> clearSelectedProfileRole() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_selectedProfileRoleKey);
  }
}
