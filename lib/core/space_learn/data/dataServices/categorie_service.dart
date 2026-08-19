import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../services/api_client.dart';
import '../../../utils/api_routes.dart';
import '../model/categorie.dart';
import 'package:space_learn_flutter/core/utils/message_erreur.dart';

class CategorieService {
  final http.Client client;

  CategorieService({http.Client? client})
    : client = client ?? ApiClient.instance;

  Future<List<Categorie>> getCategories() async {
    final response = await client.get(Uri.parse(ApiRoutes.categories));

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      final List<dynamic> categoriesJson = data['data'] ?? [];
      return categoriesJson.map((json) => Categorie.fromJson(json)).toList();
    } else {
      throw Exception(
        messageDeLaReponse(
          response,
          repli: "Impossible de charger les catégories.",
        ),
      );
    }
  }

  Future<Categorie> getCategorieById(String id) async {
    final url = ApiRoutes.categorieById.replaceFirst(':id', id);
    final response = await client.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      return Categorie.fromJson(data['data']);
    } else {
      throw Exception(
        messageDeLaReponse(response, repli: "Cette catégorie est introuvable."),
      );
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
      throw Exception(
        messageDeLaReponse(
          response,
          repli: "Cette catégorie n'a pas pu être créée.",
        ),
      );
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
      throw Exception(
        messageDeLaReponse(
          response,
          repli: "Cette catégorie n'a pas pu être modifiée.",
        ),
      );
    }
  }

  Future<void> deleteCategorie(String id, String authToken) async {
    final url = ApiRoutes.categorieById.replaceFirst(':id', id);
    final response = await client.delete(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $authToken'},
    );

    if (response.statusCode != 200) {
      throw Exception(
        messageDeLaReponse(
          response,
          repli: "Cette catégorie n'a pas pu être supprimée.",
        ),
      );
    }
  }
}
