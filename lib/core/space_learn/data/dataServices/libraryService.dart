import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../utils/api_routes.dart';
import '../model/libraryModel.dart';

class LibraryService {
  final http.Client client;

  LibraryService({http.Client? client}) : client = client ?? http.Client();

  Future<LibraryModel> addToLibrary(
    String livreId,
    String utilisateurId,
    String acquisVia,
    String authToken,
  ) async {
    print(
      "📚 [LibraryService] Adding book to library: $livreId, User: $utilisateurId, Method: $acquisVia",
    );
    final uri = Uri.parse(ApiRoutes.library);
    print("📡 [LibraryService] POST URL: $uri");

    try {
      final response = await client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $authToken',
            },
            body: jsonEncode({
              'livre_id': livreId,
              'utilisateur_id': utilisateurId,
              'acquis_via': acquisVia,
            }),
          )
          .timeout(const Duration(seconds: 15)); // Add timeout

      print("📥 [LibraryService] Response Status: ${response.statusCode}");
      print("📥 [LibraryService] Response Body: ${response.body}");

      if (response.statusCode == 201) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        return LibraryModel.fromJson(responseData['data'] ?? responseData);
      } else {
        print(
          "❌ [LibraryService] Failed to add: ${response.statusCode} - ${response.body}",
        );
        throw Exception('Failed to add to library: ${response.statusCode}');
      }
    } catch (e) {
      print("❌ [LibraryService] Exception adding to library: $e");
      rethrow;
    }
  }

  Future<List<LibraryModel>> getUserLibrary(String authToken) async {
    final response = await client.get(
      Uri.parse(ApiRoutes.library),
      headers: {'Authorization': 'Bearer $authToken'},
    );

    if (response.statusCode == 200) {
      print("📥 RAW LIBRARY RESPONSE: ${response.body}");
      final dynamic decoded = jsonDecode(response.body);
      List<dynamic> data;
      if (decoded is List) {
        data = decoded;
      } else if (decoded is Map && decoded.containsKey('data')) {
        data = decoded['data'];
      } else {
        data = [];
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
