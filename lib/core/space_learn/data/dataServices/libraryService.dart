import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../utils/api_routes.dart';
import '../model/libraryModel.dart';

class LibraryService {
  final http.Client client;

  LibraryService({http.Client? client}) : client = client ?? http.Client();

  Future<LibraryModel> addToLibrary(
    String livreId,
    String acquisVia,
    String authToken,
  ) async {
    final response = await client.post(
      Uri.parse(ApiRoutes.addToLibrary),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $authToken',
      },
      body: jsonEncode({'livre_id': livreId, 'acquis_via': acquisVia}),
    );

    if (response.statusCode == 201) {
      return LibraryModel.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to add to library');
    }
  }

  Future<List<LibraryModel>> getUserLibrary(String authToken) async {
    final response = await client.get(
      Uri.parse(ApiRoutes.getLibrary),
      headers: {'Authorization': 'Bearer $authToken'},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
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
