import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Erreur de connexion Google exprimée en français, à afficher telle quelle.
class ErreurGoogle implements Exception {
  final String message;

  /// Vrai lorsque la personne a simplement fermé le sélecteur de compte.
  /// Ce n'est pas un échec : rien ne doit être affiché.
  final bool annulee;

  const ErreurGoogle(this.message, {this.annulee = false});

  @override
  String toString() => message;
}

/// Accès au sélecteur de compte Google.
///
/// Ne parle jamais au serveur : il rend le jeton d'identité, que
/// [AuthService.connexionGoogle] transmet au backend. C'est le backend, et lui
/// seul, qui décide si ce jeton vaut une session — le vérifier dans
/// l'application ne prouverait rien, puisqu'une application peut être modifiée.
class GoogleAuthService {
  GoogleAuthService._();

  /// Identifiant client **Web** de la console Google.
  ///
  /// Sur Android, c'est lui — et non l'identifiant Android — que porte le
  /// champ `aud` du jeton, à condition de le passer en `serverClientId`. Le
  /// serveur doit donc déclarer cette même valeur dans GOOGLE_CLIENT_ID, sans
  /// quoi il refusera tous les jetons.
  ///
  /// Fourni au build :
  ///   flutter build apk --dart-define=GOOGLE_SERVER_CLIENT_ID=xxx.apps.googleusercontent.com
  static const String _serverClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );

  static bool _initialise = false;

  /// Indique si la connexion Google peut être proposée.
  ///
  /// Sans identifiant client, le bouton n'a rien à faire à l'écran : il
  /// promettrait une fonctionnalité que ce build ne peut pas rendre.
  static bool get estDisponible => _serverClientId.isNotEmpty;

  static Future<void> _initialiser() async {
    if (_initialise) return;
    await GoogleSignIn.instance.initialize(serverClientId: _serverClientId);
    _initialise = true;
  }

  /// Ouvre le sélecteur de compte et rend le jeton d'identité.
  ///
  /// Lève [ErreurGoogle] ; son champ `annulee` distingue le renoncement
  /// volontaire d'une véritable panne.
  static Future<String> obtenirJetonIdentite() async {
    if (!estDisponible) {
      throw const ErreurGoogle(
        "La connexion Google n'est pas configurée dans cette version de l'application.",
      );
    }

    try {
      await _initialiser();

      // Les plateformes qui ne savent pas ouvrir de sélecteur — le Web, qui
      // impose son propre bouton — le déclarent ici.
      if (!GoogleSignIn.instance.supportsAuthenticate()) {
        throw const ErreurGoogle(
          "La connexion Google n'est pas disponible sur cet appareil.",
        );
      }

      final compte = await GoogleSignIn.instance.authenticate();
      final jeton = compte.authentication.idToken;

      if (jeton == null || jeton.isEmpty) {
        // Arrive quand serverClientId est absent ou ne correspond pas à la
        // configuration de la console Google.
        throw const ErreurGoogle(
          "Google n'a pas fourni de jeton d'identité. Vérifiez la configuration de l'application.",
        );
      }
      return jeton;
    } on GoogleSignInException catch (e) {
      debugPrint('GoogleAuthService : ${e.code} — ${e.description}');
      switch (e.code) {
        case GoogleSignInExceptionCode.canceled:
        case GoogleSignInExceptionCode.interrupted:
          throw const ErreurGoogle('Connexion annulée', annulee: true);
        case GoogleSignInExceptionCode.uiUnavailable:
          throw const ErreurGoogle(
            "Impossible d'ouvrir la fenêtre Google sur cet appareil.",
          );
        default:
          throw const ErreurGoogle(
            'La connexion Google a échoué. Réessayez dans un instant.',
          );
      }
    } on ErreurGoogle {
      rethrow;
    } catch (e) {
      debugPrint('GoogleAuthService : erreur inattendue — $e');
      throw const ErreurGoogle('La connexion Google a échoué.');
    }
  }

  /// Oublie le compte retenu par Google.
  ///
  /// Sans cet appel à la déconnexion, le sélecteur reconnecte silencieusement
  /// le même compte au coup suivant : impossible d'en changer sur un appareil
  /// partagé.
  static Future<void> oublierLeCompte() async {
    if (!_initialise) return;
    try {
      await GoogleSignIn.instance.signOut();
    } catch (e) {
      debugPrint('GoogleAuthService : déconnexion Google impossible — $e');
    }
  }
}
