import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../services/api_client.dart';
import '../../../utils/api_routes.dart';
import '../model/library_model.dart';

class LibraryService {
  final http.Client client;

  LibraryService({http.Client? client}) : client = client ?? ApiClient.instance;

  /// Met un livre gratuit dans la bibliotheque du lecteur.
  ///
  /// Le client ne dit plus comment il l'acquiert : il envoyait « GRATUIT »,
  /// valeur que le serveur rejetait — la lecture d'un livre gratuit ne
  /// fonctionnait donc pas du tout. Et le champ etait libre, si bien qu'un
  /// « achat » declare suffisait a s'offrir n'importe quel ouvrage payant.
  /// C'est le serveur qui verifie le prix et decide.
  ///
  /// Les livres payants entrent par la confirmation d'un paiement, jamais ici.
  Future<LibraryModel> acquerirGratuitement(
    String livreId,
    String authToken,
  ) async {
    final response = await client
        .post(
          Uri.parse(ApiRoutes.library),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $authToken',
          },
          body: jsonEncode({'livre_id': livreId}),
        )
        .timeout(const Duration(seconds: 15));

    // 409 : le livre y est deja. C'est le resultat voulu, pas un echec — le
    // lecteur a pu appuyer deux fois, ou revenir sur la fiche.
    if (response.statusCode == 201 ||
        response.statusCode == 200 ||
        response.statusCode == 409) {
      final Map<String, dynamic> corps = jsonDecode(response.body);
      return LibraryModel.fromJson(corps['data'] ?? corps);
    }
    if (response.statusCode == 402) {
      throw Exception('Ce livre est payant.');
    }
    throw Exception(
      'Ajout à la bibliothèque impossible (${response.statusCode})',
    );
  }

  Future<List<LibraryModel>> getUserLibrary(String authToken) async {
    final response = await client.get(
      Uri.parse(ApiRoutes.library),
      headers: {'Authorization': 'Bearer $authToken'},
    );

    if (response.statusCode == 200) {
      final dynamic decoded = jsonDecode(response.body);

      // Defensive parsing: some backends may return { data: null } when the
      // library is empty. Treat null as empty list to avoid runtime type errors.
      List<dynamic> data = [];
      if (decoded is List) {
        data = decoded;
      } else if (decoded is Map) {
        final d = decoded['data'];
        if (d is List) {
          data = d;
        } else {
          data = []; // handles null or other unexpected shapes
        }
      }

      return data.map((json) => LibraryModel.fromJson(json)).toList();
    } else {
      throw Exception('Failed to fetch user library');
    }
  }

  Future<void> removeFromLibrary(String livreId, String authToken) async {
    final url = ApiRoutes.removeFromLibrary.replaceFirst(':livre_id', livreId);
    final response = await client.delete(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $authToken'},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to remove from library');
    }
  }
}
