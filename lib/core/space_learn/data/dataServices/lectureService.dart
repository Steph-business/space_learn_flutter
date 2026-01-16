import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../utils/api_routes.dart';
import '../model/activiteModel.dart';

class Lectureservice {
  final http.Client client;

  Lectureservice({http.Client? client}) : client = client ?? http.Client();

  Future<ReviewModel> createReview({
    required String livreId,
    required int note,
    required String commentaire,
    required String authToken,
  }) async {
    final response = await client.post(
      Uri.parse(ApiRoutes.createReview),
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
      return ReviewModel.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to create review');
    }
  }

  Future<List<ReviewModel>> getReviewsByBook(String livreId) async {
    final url = ApiRoutes.reviewsByBook.replaceFirst(':livre_id', livreId);
    final response = await client.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => ReviewModel.fromJson(json)).toList();
    } else {
      throw Exception('Failed to fetch reviews by book');
    }
  }

  Future<List<ReviewModel>> getReviewsByUser(String authToken) async {
    final response = await client.get(
      Uri.parse(ApiRoutes.reviewsByUser),
      headers: {'Authorization': 'Bearer $authToken'},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => ReviewModel.fromJson(json)).toList();
    } else {
      throw Exception('Failed to fetch reviews by user');
    }
  }

  Future<ReviewModel> updateReview({
    required String id,
    required String livreId,
    required int note,
    required String commentaire,
    required String authToken,
  }) async {
    final url = ApiRoutes.updateReview.replaceFirst(':id', id);
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
      return ReviewModel.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to update review');
    }
  }

  Future<void> deleteReview(String id, String authToken) async {
    final url = ApiRoutes.deleteReview.replaceFirst(':id', id);
    final response = await client.delete(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $authToken'},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete review');
    }
  }
}
