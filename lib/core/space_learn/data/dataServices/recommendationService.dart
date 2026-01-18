import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../utils/api_routes.dart';
import '../model/recommendationModel.dart';

class RecommendationService {
  final http.Client client;

  RecommendationService({http.Client? client})
    : client = client ?? http.Client();

  Future<List<RecommendationModel>> getRecommendations(String authToken) async {
    final response = await client.get(
      Uri.parse(ApiRoutes.recommendations),
      headers: {'Authorization': 'Bearer $authToken'},
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = jsonDecode(response.body);
      final List<dynamic> data = responseData['data'] ?? [];
      return data.map((json) => RecommendationModel.fromJson(json)).toList();
    } else {
      throw Exception('Failed to fetch recommendations');
    }
  }

  Future<RecommendationModel> createRecommendation({
    required String livreId,
    required String raison,
    required String authToken,
  }) async {
    final response = await client.post(
      Uri.parse(ApiRoutes.recommendations),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $authToken',
      },
      body: jsonEncode({'livre_id': livreId, 'raison': raison}),
    );

    if (response.statusCode == 201) {
      final Map<String, dynamic> responseData = jsonDecode(response.body);
      return RecommendationModel.fromJson(responseData['data'] ?? responseData);
    } else {
      throw Exception('Failed to create recommendation');
    }
  }

  Future<void> deleteRecommendation(String id, String authToken) async {
    final url = ApiRoutes.recommendationById.replaceFirst(':id', id);
    final response = await client.delete(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $authToken'},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete recommendation');
    }
  }
}
