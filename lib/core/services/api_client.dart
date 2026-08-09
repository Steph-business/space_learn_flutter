import 'package:http/http.dart' as http;

/// Client HTTP partagé par tous les services de l'application.
///
/// Son rôle est de centraliser la réaction aux réponses `401 Unauthorized` :
/// le JWT émis par le backend expire au bout de 24 h, et sans ce point unique
/// chaque écran échouait silencieusement au lieu de ramener l'utilisateur à
/// l'écran de connexion.
///
/// Usage : les services prennent `ApiClient.instance` par défaut et acceptent
/// toujours un client injecté pour les tests.
class ApiClient extends http.BaseClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();

  final http.Client _inner = http.Client();

  /// Branché une fois au démarrage (cf. `main.dart`) : purge la session locale
  /// et renvoie vers l'écran de connexion. Laissé nul, un 401 est simplement
  /// propagé au service appelant.
  static Future<void> Function()? onUnauthorized;

  /// Évite d'enchaîner plusieurs déconnexions quand un écran déclenche
  /// plusieurs requêtes en parallèle et qu'elles échouent toutes.
  bool _handlingUnauthorized = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _inner.send(request);

    // Les routes d'authentification renvoient légitimement 401 (mauvais mot de
    // passe, OTP invalide) : ce n'est pas une session expirée.
    final isAuthRoute = request.url.path.contains('/auth/');

    if (response.statusCode == 401 && !isAuthRoute) {
      _triggerUnauthorized();
    }

    return response;
  }

  void _triggerUnauthorized() {
    final handler = onUnauthorized;
    if (handler == null || _handlingUnauthorized) return;

    _handlingUnauthorized = true;
    handler().whenComplete(() => _handlingUnauthorized = false);
  }

  @override
  void close() {
    _inner.close();
  }
}
