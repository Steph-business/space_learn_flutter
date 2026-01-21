import 'package:shared_preferences/shared_preferences.dart';

class ProfileStorage {
  static const String _selectedProfileKey = "selected_profile_id";

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
}
