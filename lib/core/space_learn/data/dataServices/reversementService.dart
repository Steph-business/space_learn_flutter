import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../services/api_client.dart';
import '../../../utils/api_routes.dart';
import '../model/reversement_model.dart';

/// Accès aux reversements de l'auteur connecté.
///
/// L'identité vient du token : aucune route ne prend d'identifiant d'auteur en
/// paramètre, un auteur ne peut donc consulter que ses propres versements.
class ReversementService {
  final http.Client client;

  ReversementService({http.Client? client})
      : client = client ?? ApiClient.instance;

  // Déclarées ici plutôt que dans ApiRoutes pour ne pas toucher un fichier en
  // cours de modification ; à déplacer dans ApiRoutes à l'occasion.
  static final String _base = '${ApiRoutes.baseUrlsGin}/api/reversements';
  static String get _mesReversements => '$_base/me';
  static String get _infosPaiement => '$_base/me/infos-paiement';

  Map<String, String> _headers(String token, {bool json = false}) => {
        if (json) 'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  /// Historique des reversements + agrégats.
  Future<(ResumeReversements, List<ReversementModel>)> getMesReversements(
    String authToken, {
    int limit = 50,
    int offset = 0,
  }) async {
    final uri = Uri.parse(_mesReversements).replace(queryParameters: {
      'limit': '$limit',
      'offset': '$offset',
    });

    final response = await client.get(uri, headers: _headers(authToken));

    if (response.statusCode != 200) {
      throw Exception('Échec du chargement des reversements : ${response.body}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = (body['data'] ?? {}) as Map<String, dynamic>;

    final resume = data['resume'] is Map<String, dynamic>
        ? ResumeReversements.fromJson(data['resume'] as Map<String, dynamic>)
        : ResumeReversements.vide;

    final liste = (data['reversements'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .map(ReversementModel.fromJson)
            .toList() ??
        <ReversementModel>[];

    return (resume, liste);
  }

  /// Coordonnées Mobile Money enregistrées.
  ///
  /// Le backend répond 200 même sans enregistrement, en proposant le téléphone
  /// du compte avec `par_defaut: true`.
  Future<InfosPaiementModel?> getInfosPaiement(String authToken) async {
    final response = await client.get(
      Uri.parse(_infosPaiement),
      headers: _headers(authToken),
    );

    if (response.statusCode != 200) return null;

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = body['data'];
    if (data is! Map<String, dynamic>) return null;

    return InfosPaiementModel.fromJson(data);
  }

  /// Enregistre le numéro vers lequel l'auteur sera payé.
  Future<InfosPaiementModel> setInfosPaiement({
    required String authToken,
    required String prefix,
    required String telephone,
    String? nomComplet,
    String? email,
  }) async {
    final response = await client.put(
      Uri.parse(_infosPaiement),
      headers: _headers(authToken, json: true),
      body: jsonEncode({
        'prefix': prefix,
        'telephone': telephone,
        if (nomComplet != null && nomComplet.isNotEmpty) 'nom_complet': nomComplet,
        if (email != null && email.isNotEmpty) 'email': email,
      }),
    );

    if (response.statusCode != 200) {
      String message = 'Échec de l\'enregistrement du numéro';
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body['message'] is String) message = body['message'] as String;
      } catch (_) {}
      throw Exception(message);
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return InfosPaiementModel.fromJson(
      (body['data'] ?? {}) as Map<String, dynamic>,
    );
  }
}
