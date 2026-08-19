import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../services/api_client.dart';
import '../../../utils/api_routes.dart';
import '../model/relationModel.dart';
import 'package:space_learn_flutter/core/utils/message_erreur.dart';

class RelationService {
  final http.Client client;

  RelationService({http.Client? client})
    : client = client ?? ApiClient.instance;

  Future<RelationModel> followUser(String suitId, String authToken) async {
    final url = ApiRoutes.followUser.replaceFirst(':suit_id', suitId);
    final response = await client.post(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $authToken'},
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      return RelationModel.fromJson(data['data'] ?? data);
    } else {
      throw Exception(
        messageDeLaReponse(response, repli: "Impossible de suivre cet auteur."),
      );
    }
  }

  Future<void> unfollowUser(String suitId, String authToken) async {
    final url = ApiRoutes.unfollowUser.replaceFirst(':suit_id', suitId);
    final response = await client.delete(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $authToken'},
    );

    if (response.statusCode != 200) {
      throw Exception(
        messageDeLaReponse(
          response,
          repli: "Impossible de ne plus suivre cet auteur.",
        ),
      );
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
      throw Exception(
        messageDeLaReponse(
          response,
          repli: "Impossible de charger les abonnés.",
        ),
      );
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
      throw Exception(
        messageDeLaReponse(
          response,
          repli: "Impossible de charger les abonnements.",
        ),
      );
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
      throw Exception(
        messageDeLaReponse(
          response,
          repli: "Impossible de charger les événements.",
        ),
      );
    }
  }
}
