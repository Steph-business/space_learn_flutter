import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../utils/api_routes.dart';
import '../model/relationModel.dart';

class RelationService {
  final http.Client client;

  RelationService({http.Client? client}) : client = client ?? http.Client();

  Future<RelationModel> followUser(String suitId, String authToken) async {
    final url = ApiRoutes.followUser.replaceFirst(':suit_id', suitId);
    final response = await client.post(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $authToken'},
    );

    if (response.statusCode == 201) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      return RelationModel.fromJson(data['data'] ?? data);
    } else {
      throw Exception('Failed to follow user');
    }
  }

  Future<void> unfollowUser(String suitId, String authToken) async {
    final url = ApiRoutes.unfollowUser.replaceFirst(':suit_id', suitId);
    final response = await client.delete(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $authToken'},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to unfollow user');
    }
  }

  Future<List<RelationModel>> getFollowers(String utilisateurId) async {
    final url = ApiRoutes.getFollowers.replaceFirst(
      ':utilisateur_id',
      utilisateurId,
    );
    final response = await client.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = jsonDecode(response.body);
      final List<dynamic> data = responseData['data'] ?? [];
      return data.map((json) => RelationModel.fromJson(json)).toList();
    } else {
      throw Exception('Failed to fetch followers');
    }
  }

  Future<List<RelationModel>> getFollowing(String utilisateurId) async {
    final url = ApiRoutes.getFollowing.replaceFirst(
      ':utilisateur_id',
      utilisateurId,
    );
    final response = await client.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = jsonDecode(response.body);
      final List<dynamic> data = responseData['data'] ?? [];
      return data.map((json) => RelationModel.fromJson(json)).toList();
    } else {
      throw Exception('Failed to fetch following users');
    }
  }

  Future<List<dynamic>> getCommunityEvents(String authToken) async {
    final response = await client.get(
      Uri.parse(ApiRoutes.communityEvents),
      headers: {'Authorization': 'Bearer $authToken'},
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = jsonDecode(response.body);
      return responseData['data'] ?? responseData;
    } else {
      throw Exception('Failed to fetch community events');
    }
  }
}
