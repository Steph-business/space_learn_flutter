import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../services/api_client.dart';
import '../../../utils/api_routes.dart';
import '../../../utils/token_storage.dart';

/// Statistiques et revenus de l'auteur connecté.
///
/// Ces deux routes exposent le chiffre d'affaires : elles exigent désormais un
/// jeton et n'acceptent que l'auteur lui-même. Le jeton est lu ici par défaut
/// pour que les écrans appelants n'aient pas à le transmettre.
class AuthorStatsService {
  final http.Client client;

  AuthorStatsService({http.Client? client})
      : client = client ?? ApiClient.instance;

  Future<Map<String, dynamic>> getAuthorStats(
    String authorId,
    String period, {
    String? authToken,
  }) {
    return _get(
      ApiRoutes.authorStats.replaceFirst(':authorId', authorId),
      period,
      authToken,
      'statistiques auteur',
    );
  }

  Future<Map<String, dynamic>> getAuthorRevenue(
    String authorId,
    String period, {
    String? authToken,
  }) {
    return _get(
      ApiRoutes.authorRevenue.replaceFirst(':authorId', authorId),
      period,
      authToken,
      'revenus auteur',
    );
  }

  Future<Map<String, dynamic>> _get(
    String url,
    String period,
    String? authToken,
    String libelle,
  ) async {
    final token = authToken ?? await TokenStorage.getToken();

    final uri = Uri.parse(url).replace(
      queryParameters: period.isEmpty ? null : {'period': period},
    );

    try {
      final response = await client.get(
        uri,
        headers: {
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return (data['data'] as Map<String, dynamic>?) ?? {};
      }

      // Un échec renvoyait auparavant un objet vide sans le moindre signal :
      // le tableau de bord affichait 0 sans qu'on puisse distinguer « aucune
      // vente » de « appel refusé ».
      debugPrint(
        'AuthorStatsService: échec du chargement des $libelle '
        '(${response.statusCode}) — ${response.body}',
      );
    } catch (e) {
      debugPrint('AuthorStatsService: erreur réseau sur les $libelle — $e');
    }

    return {};
  }
}
