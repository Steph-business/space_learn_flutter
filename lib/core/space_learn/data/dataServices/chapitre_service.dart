import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../utils/api_routes.dart';
import '../model/chapitre_model.dart';

class ChapitreService {
  final http.Client client;

  ChapitreService({http.Client? client}) : client = client ?? http.Client();

  /// Récupère les chapitres d'un livre depuis le backend.
  Future<List<ChapitreModel>> getChapitres(String livreId) async {
    try {
      final response = await client.get(
        Uri.parse('${ApiRoutes.baseUrlsGin}/api/books/$livreId/chapters'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final data = responseData['data'];
        if (data != null && data is List) {
          return data.map((ch) => ChapitreModel.fromJson(ch)).toList();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Crée ou remplace tous les chapitres d'un livre (bulk).
  Future<List<ChapitreModel>> createChapitres(
    String livreId,
    List<Map<String, dynamic>> chapitres,
    String authToken,
  ) async {
    try {
      final response = await client.post(
        Uri.parse('${ApiRoutes.baseUrlsGin}/api/books/$livreId/chapters'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({'chapitres': chapitres}),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final data = responseData['data'];
        if (data != null && data is List) {
          return data.map((ch) => ChapitreModel.fromJson(ch)).toList();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}
