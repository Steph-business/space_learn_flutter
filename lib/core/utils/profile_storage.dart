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

  // « is_registered_user » a été retirée d'ici, et ses deux écritures avec
  // elle (login.dart, otp.dart).
  //
  // Elle était posée à chaque connexion et à chaque validation de code, et
  // RELUE nulle part. Une donnée que personne ne consulte n'est pas un
  // réglage : c'est une trace laissée sur l'appareil, qui survivait de surcroît
  // à la déconnexion sans que rien ne la nettoie, et qu'un prochain lecteur du
  // code aurait prise pour un état de session digne de confiance.
  //
  // Rien à migrer sur les appareils déjà installés : la valeur qui y dort est
  // un booléen sans contenu nominatif que plus aucun code ne lit.

  static const String _savedEmailKey = "saved_email_key";

  static Future<void> saveSavedEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_savedEmailKey, email);
  }

  static Future<String?> getSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_savedEmailKey);
  }

  /// Oublie l'adresse mémorisée.
  ///
  /// Cette clé n'était effacée par AUCUN chemin de déconnexion : sur un
  /// téléphone partagé, l'écran de connexion s'ouvrait pré-rempli avec
  /// l'adresse du compte précédent — et, depuis que la reconnexion silencieuse
  /// d'après changement de mot de passe s'appuie dessus, elle pouvait faire
  /// partir le nouveau mot de passe de B sous l'adresse de A. Elle part
  /// désormais avec le reste, dans SessionService.terminer.
  static Future<void> clearSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_savedEmailKey);
  }
}
