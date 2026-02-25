import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../utils/api_routes.dart';
import '../model/review_model.dart';

class ReviewService {
  final http.Client client;

  ReviewService({http.Client? client}) : client = client ?? http.Client();

  Future<ReviewModel> addReview({
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

    if (response.statusCode == 201 || response.statusCode == 200) {
      final Map<String, dynamic> responseData = jsonDecode(response.body);
      return ReviewModel.fromJson(responseData['data'] ?? responseData);
    } else {
      throw Exception('Failed to add review: ${response.body}');
    }
  }

  Future<List<ReviewModel>> getBookReviews(String livreId) async {
    final url = ApiRoutes.reviewsByBook.replaceFirst(':livre_id', livreId);
    final response = await client.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = jsonDecode(response.body);
      final List<dynamic> data = responseData['data'] ?? [];
      return data.map((json) => ReviewModel.fromJson(json)).toList();
    } else {
      throw Exception('Failed to fetch book reviews');
    }
  }

  Future<List<ReviewModel>> getUserReviews(String authToken) async {
    final response = await client.get(
      Uri.parse(ApiRoutes.reviewsByUser),
      headers: {'Authorization': 'Bearer $authToken'},
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = jsonDecode(response.body);
      final List<dynamic> data = responseData['data'] ?? [];
      return data.map((json) => ReviewModel.fromJson(json)).toList();
    } else {
      throw Exception('Failed to fetch user reviews');
    }
  }
}
