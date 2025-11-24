/// api_routes.dart
class ApiRoutes {
  // Base URL (dev ou prod)
  static const String baseUrl = "http://192.168.1.18:8083";

  // Auth routes
  static const String profils  =    "$baseUrl/auth/profils";
  static const String register =   "$baseUrl/auth/register";
  static const String login    =      "$baseUrl/auth/login";
  static const String logout   =     "$baseUrl/auth/logout";
  static const String sendOtp  =    "$baseUrl/auth/send-otp";
  static const String verifyOtp =  "$baseUrl/auth/verify-otp";
  static const String forgotPassword = "$baseUrl/auth/forgot-password";
  static const String resetPassword = "$baseUrl/auth/reset-password";

  // Exemple pour User (si tu as un contrôleur user)
  static const String getUser =    "$baseUrl/utilisateurs/me";
  static const String updateUser = "$baseUrl/utilisateurs/update";
  static const String selectProfile =
      "$baseUrl/utilisateurs/me/profil"; // Ajout de la route

  // Autres routes (cours, vidéos, etc.) peuvent être ajoutées ici
}
