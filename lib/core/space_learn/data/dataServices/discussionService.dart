import 'dart:convert';
import 'package:http/http.dart' as http;
import '../model/discussionModel.dart';
import '../../../utils/api_routes.dart';

class DiscussionService {
  final http.Client client;

  DiscussionService({http.Client? client}) : client = client ?? http.Client();

  Future<Discussion> createDiscussion(
    String livreId,
    String titre,
    String token,
  ) async {
    final response = await client.post(
      Uri.parse(ApiRoutes.createDiscussion),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({'livre_id': livreId, 'titre': titre}),
    );

    if (response.statusCode == 201) {
      return Discussion.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to create discussion');
    }
  }

  Future<List<Discussion>> getDiscussionsByUser(String token) async {
    final response = await client.get(
      Uri.parse(ApiRoutes.discussionsByUser),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      Iterable list = json.decode(response.body);
      return list.map((json) => Discussion.fromJson(json)).toList();
    } else {
      throw Exception('Failed to fetch discussions');
    }
  }

  Future<Discussion> getDiscussionById(String id) async {
    final url = ApiRoutes.discussionById.replaceFirst(':id', id);
    final response = await client.get(Uri.parse(url));

    if (response.statusCode == 200) {
      return Discussion.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to get discussion');
    }
  }

  Future<Discussion> updateDiscussion(
    String id,
    String titre,
    String token,
  ) async {
    final url = ApiRoutes.updateDiscussion.replaceFirst(':id', id);
    final response = await client.put(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({'titre': titre}),
    );

    if (response.statusCode == 200) {
      return Discussion.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to update discussion');
    }
  }

  Future<void> deleteDiscussion(String id, String token) async {
    final url = ApiRoutes.deleteDiscussion.replaceFirst(':id', id);
    final response = await client.delete(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete discussion');
    }
  }
}
