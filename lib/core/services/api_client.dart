import 'package:http/http.dart' as http;
import 'package:space_learn_flutter/core/utils/token_storage.dart';

/// Client HTTP partagé par tous les services de l'application.
///
/// Il porte deux responsabilités, l'une et l'autre parce qu'elles n'ont de sens
/// qu'en un seul endroit.
///
/// D'abord la réaction aux réponses `401 Unauthorized` : le JWT émis par le
/// backend expire au bout de 24 h, et sans ce point unique chaque écran
/// échouait silencieusement au lieu de ramener l'utilisateur à la connexion.
///
/// Ensuite la pose du jeton. Chaque service composait ses en-têtes à la main,
/// et plusieurs lectures partaient donc sans jeton — celle du salon global
/// notamment. Tant que le serveur laissait lire sans authentification, cela ne
/// se voyait pas ; le jour où il a cessé de le faire, il aurait fallu retrouver
/// chaque appel oublié. Le poser ici le pose partout, une fois.
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
    // Les routes d'authentification renvoient légitimement 401 (mauvais mot de
    // passe, OTP invalide) : ce n'est pas une session expirée. Elles n'ont pas
    // non plus besoin qu'on leur pose un jeton.
    final isAuthRoute = request.url.path.contains('/auth/');

    // Un en-tête déjà posé par l'appelant l'emporte : certains services
    // transmettent un jeton précis, et on ne le remplace pas par celui de la
    // session courante.
    if (!isAuthRoute && !request.headers.containsKey('Authorization')) {
      final token = await TokenStorage.getToken();
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }
    }

    final response = await _inner.send(request);

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
