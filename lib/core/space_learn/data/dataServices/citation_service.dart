import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../services/api_client.dart';
import '../../../utils/api_routes.dart';
import '../../../utils/message_erreur.dart';
import '../model/citation_model.dart';

class CitationService {
  final http.Client client;

  CitationService({http.Client? client})
    : client = client ?? ApiClient.instance;

  /// La citation du jour, ou `null` quand il n'y en a PAS.
  ///
  /// Toute erreur rendait `null` : depuis l'accueil, « aucune citation
  /// aujourd'hui » et « le serveur n'a pas répondu » arrivaient sous la même
  /// forme, donc s'affichaient de la même façon — un vide tranquille à la
  /// place d'une panne. `null` ne signifie plus désormais qu'une chose : le
  /// serveur a répondu, et il n'a pas de citation à donner (200 sans contenu,
  /// ou 404). Le reste est levé, pour que l'écran puisse dire ce qui se passe
  /// et proposer de réessayer.
  Future<CitationModel?> getDailyCitation(String authToken) async {
    final response = await client.get(
      Uri.parse(ApiRoutes.citationsDaily),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $authToken',
      },
    );

    if (response.statusCode == 200) {
      final donnees = jsonDecode(response.body);
      final contenu = donnees is Map<String, dynamic> ? donnees['data'] : null;
      // Un 200 sans « data » est un vide légitime, pas un défaut de parsing.
      if (contenu is! Map<String, dynamic>) return null;
      return CitationModel.fromJson(contenu);
    }

    // Le seul autre « pas de citation » honnête du serveur.
    if (response.statusCode == 404) return null;

    throw Exception(
      messageDeLaReponse(
        response,
        repli: "Impossible de charger la citation du jour.",
      ),
    );
  }
}
