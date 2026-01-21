import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../utils/api_routes.dart';
import '../model/categorie.dart';

class CategorieService {
  final http.Client client;

  CategorieService({http.Client? client}) : client = client ?? http.Client();

  Future<List<Categorie>> getCategories() async {
    final response = await client.get(Uri.parse(ApiRoutes.categories));

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      final List<dynamic> categoriesJson = data['data'] ?? [];
      return categoriesJson.map((json) => Categorie.fromJson(json)).toList();
    } else {
      throw Exception('Failed to fetch categories');
    }
  }

  Future<Categorie> getCategorieById(String id) async {
    final url = ApiRoutes.categorieById.replaceFirst(':id', id);
    final response = await client.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      return Categorie.fromJson(data['data']);
    } else {
      throw Exception('Failed to fetch category');
    }
  }

  Future<Categorie> createCategorie(
    Map<String, dynamic> categoryData,
    String authToken,
  ) async {
    final response = await client.post(
      Uri.parse(ApiRoutes.categories),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $authToken',
      },
      body: jsonEncode(categoryData),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      return Categorie.fromJson(data['data']);
    } else {
      throw Exception('Failed to create category');
    }
  }

  Future<Categorie> updateCategorie(
    String id,
    Map<String, dynamic> updates,
    String authToken,
  ) async {
    final url = ApiRoutes.categorieById.replaceFirst(':id', id);
    final response = await client.put(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $authToken',
      },
      body: jsonEncode(updates),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      return Categorie.fromJson(data['data']);
    } else {
      throw Exception('Failed to update category');
    }
  }

  Future<void> deleteCategorie(String id, String authToken) async {
    final url = ApiRoutes.categorieById.replaceFirst(':id', id);
    final response = await client.delete(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $authToken'},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete category');
    }
  }
}
