import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../services/api_client.dart';
import '../../../utils/api_routes.dart';
import '../model/bookmark_model.dart';
import 'package:space_learn_flutter/core/utils/message_erreur.dart';

class BookmarkService {
  final http.Client client;

  BookmarkService({http.Client? client})
    : client = client ?? ApiClient.instance;

  Future<BookmarkModel> createBookmark({
    required String livreId,
    required int page,
    required int chapitre,
    String? label,
    required String authToken,
  }) async {
    final Map<String, dynamic> data = {
      'livre_id': livreId,
      'page_number': page,
      'chapitre': chapitre,
      if (label != null) 'label': label,
    };

    final response = await client.post(
      Uri.parse(ApiRoutes.bookmarks),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $authToken',
      },
      body: jsonEncode(data),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      final Map<String, dynamic> responseData = jsonDecode(response.body);
      return BookmarkModel.fromJson(responseData['data'] ?? responseData);
    } else {
      throw Exception(
        messageDeLaReponse(
          response,
          repli: "Ce signet n'a pas pu être ajouté.",
        ),
      );
    }
  }

  Future<List<BookmarkModel>> getBookmarksByLivre(
    String livreId,
    String authToken,
  ) async {
    final url = ApiRoutes.bookmarksByLivre.replaceFirst(':livre_id', livreId);

    final response = await client.get(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $authToken'},
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = jsonDecode(response.body);
      final List<dynamic> data = responseData['data'] ?? [];
      return data.map((json) => BookmarkModel.fromJson(json)).toList();
    } else {
      throw Exception(
        messageDeLaReponse(
          response,
          repli: "Impossible de charger vos signets.",
        ),
      );
    }
  }

  Future<void> deleteBookmark(String id, String authToken) async {
    final url = ApiRoutes.bookmarkDetail.replaceFirst(':id', id);

    final response = await client.delete(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $authToken'},
    );

    if (response.statusCode != 200) {
      throw Exception(
        messageDeLaReponse(
          response,
          repli: "Ce signet n'a pas pu être supprimé.",
        ),
      );
    }
  }

  Future<void> clearAllBookmarks(String livreId, String authToken) async {
    final url = ApiRoutes.bookmarksClearAll.replaceFirst(':livre_id', livreId);

    final response = await client.delete(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $authToken'},
    );

    if (response.statusCode != 200) {
      throw Exception(
        messageDeLaReponse(
          response,
          repli: "Vos signets n'ont pas pu être effacés.",
        ),
      );
    }
  }
}
