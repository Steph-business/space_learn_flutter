import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../utils/api_routes.dart';
import '../model/bookmark_model.dart';

class BookmarkService {
  final http.Client client;

  BookmarkService({http.Client? client}) : client = client ?? http.Client();

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
      throw Exception('Failed to create bookmark: ${response.body}');
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
      throw Exception('Failed to fetch bookmarks');
    }
  }

  Future<void> deleteBookmark(String id, String authToken) async {
    final url = ApiRoutes.bookmarkDetail.replaceFirst(':id', id);

    final response = await client.delete(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $authToken'},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete bookmark');
    }
  }

  Future<void> clearAllBookmarks(String livreId, String authToken) async {
    final url = ApiRoutes.bookmarksClearAll.replaceFirst(':livre_id', livreId);

    final response = await client.delete(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $authToken'},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to clear bookmarks');
    }
  }
}