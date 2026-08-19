import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../services/api_client.dart';
import '../../../utils/api_routes.dart';
import '../model/activite_model.dart';
import 'package:space_learn_flutter/core/utils/message_erreur.dart';

class Lectureservice {
  final http.Client client;

  Lectureservice({http.Client? client}) : client = client ?? ApiClient.instance;

  Future<ReviewModel> createReview({
    required String livreId,
    required int note,
    required String commentaire,
    required String authToken,
  }) async {
    final response = await client.post(
      Uri.parse(ApiRoutes.reviews),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $authToken',
      },
      body: jsonEncode({
        'livre_id': livreId,
        'note': note,
        'commentaire': commentaire,
      }),
    );

    if (response.statusCode == 201) {
      final Map<String, dynamic> responseData = jsonDecode(response.body);
      return ReviewModel.fromJson(responseData['data'] ?? responseData);
    } else {
      throw Exception(
        messageDeLaReponse(
          response,
          repli: "Votre avis n'a pas pu être publié.",
        ),
      );
    }
  }

  Future<List<ReviewModel>> getReviewsByBook(String livreId) async {
    final url = ApiRoutes.reviewsByBook.replaceFirst(':livre_id', livreId);
    final response = await client.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = jsonDecode(response.body);
      final List<dynamic> data = responseData['data'] ?? [];
      return data.map((json) => ReviewModel.fromJson(json)).toList();
    } else {
      throw Exception(
        messageDeLaReponse(
          response,
          repli: "Impossible de charger les avis sur ce livre.",
        ),
      );
    }
  }

  Future<List<ReviewModel>> getReviewsByUser(String authToken) async {
    final response = await client.get(
      Uri.parse(ApiRoutes.reviewsByUser),
      headers: {'Authorization': 'Bearer $authToken'},
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = jsonDecode(response.body);
      final List<dynamic> data = responseData['data'] ?? [];
      return data.map((json) => ReviewModel.fromJson(json)).toList();
    } else {
      throw Exception(
        messageDeLaReponse(response, repli: "Impossible de charger vos avis."),
      );
    }
  }

  Future<List<ReviewModel>> getAllReviews([String? authToken]) async {
    final Map<String, String> headers = {};
    if (authToken != null) {
      headers['Authorization'] = 'Bearer $authToken';
    }

    final response = await client.get(
      Uri.parse(ApiRoutes.reviews),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = jsonDecode(response.body);
      final List<dynamic> data = responseData['data'] ?? [];
      return data.map((json) => ReviewModel.fromJson(json)).toList();
    } else if (response.statusCode == 404) {
      // If the endpoint is not found or no reviews exist globally, return empty list gracefully
      return [];
    } else {
      throw Exception(
        messageDeLaReponse(response, repli: "Impossible de charger les avis."),
      );
    }
  }

  Future<ReviewModel> updateReview({
    required String id,
    required String livreId,
    required int note,
    required String commentaire,
    required String authToken,
  }) async {
    final url = ApiRoutes.reviewById.replaceFirst(':id', id);
    final response = await client.put(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $authToken',
      },
      body: jsonEncode({
        'livre_id': livreId,
        'note': note,
        'commentaire': commentaire,
      }),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = jsonDecode(response.body);
      return ReviewModel.fromJson(responseData['data'] ?? responseData);
    } else {
      throw Exception(
        messageDeLaReponse(
          response,
          repli: "Votre avis n'a pas pu être modifié.",
        ),
      );
    }
  }

  Future<void> deleteReview(String id, String authToken) async {
    final url = ApiRoutes.reviewById.replaceFirst(':id', id);
    final response = await client.delete(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $authToken'},
    );

    if (response.statusCode != 200) {
      throw Exception(
        messageDeLaReponse(
          response,
          repli: "Votre avis n'a pas pu être supprimé.",
        ),
      );
    }
  }
}
