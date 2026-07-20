import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../utils/api_routes.dart';
import '../model/library_model.dart';

class LibraryService {
  final http.Client client;

  LibraryService({http.Client? client}) : client = client ?? http.Client();

  Future<LibraryModel> addToLibrary(
    String livreId,
    String utilisateurId,
    String acquisVia,
    String authToken,
  ) async {

    final uri = Uri.parse(ApiRoutes.library);
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
      if (response.statusCode == 201) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        return LibraryModel.fromJson(responseData['data'] ?? responseData);
      } else {

        throw Exception('Failed to add to library: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
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