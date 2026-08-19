import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../services/api_client.dart';
import '../../../utils/api_routes.dart';
import '../model/favoriteModel.dart';
import 'package:space_learn_flutter/core/utils/message_erreur.dart';

class FavoriteService {
  final http.Client client;

  FavoriteService({http.Client? client})
    : client = client ?? ApiClient.instance;

  Future<FavoriteModel> addFavorite(String livreId, String authToken) async {
    final response = await client.post(
      Uri.parse(ApiRoutes.favorites),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $authToken',
      },
      body: jsonEncode({'livre_id': livreId}),
    );

    if (response.statusCode == 201) {
      final Map<String, dynamic> responseData = jsonDecode(response.body);
      return FavoriteModel.fromJson(responseData['data'] ?? responseData);
    } else {
      throw Exception(
        messageDeLaReponse(
          response,
          repli: "Ce livre n'a pas pu être ajouté à vos favoris.",
        ),
      );
    }
  }

  Future<List<FavoriteModel>> getFavorites(String authToken) async {
    final response = await client.get(
      Uri.parse(ApiRoutes.favorites),
      headers: {'Authorization': 'Bearer $authToken'},
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = jsonDecode(response.body);
      final List<dynamic> data = responseData['data'] ?? [];
      return data.map((json) => FavoriteModel.fromJson(json)).toList();
    } else {
      throw Exception(
        messageDeLaReponse(
          response,
          repli: "Impossible de charger vos favoris.",
        ),
      );
    }
  }

  Future<void> removeFavorite(String livreId, String authToken) async {
    final url = ApiRoutes.removeFavorite.replaceFirst(':livre_id', livreId);
    final response = await client.delete(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $authToken'},
    );

    if (response.statusCode != 200) {
      throw Exception(
        messageDeLaReponse(
          response,
          repli: "Ce livre n'a pas pu être retiré de vos favoris.",
        ),
      );
    }
  }
}
