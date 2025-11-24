import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../utils/api_routes.dart';
import '../model/chapterModel.dart';

class ChapterService {
  final http.Client client;

  ChapterService({http.Client? client}) : client = client ?? http.Client();

  Future<ChapterModel> createChapter(
    ChapterModel chapter,
    String authToken,
  ) async {
    final response = await client.post(
      Uri.parse(ApiRoutes.createChapter),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $authToken',
      },
      body: jsonEncode(chapter.toJson()),
    );

    if (response.statusCode == 201) {
      return ChapterModel.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to create chapter');
    }
  }

  Future<List<ChapterModel>> getChaptersByBook(String livreId) async {
    final url = ApiRoutes.chaptersByBook.replaceFirst(':livre_id', livreId);
    final response = await client.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => ChapterModel.fromJson(json)).toList();
    } else {
      throw Exception('Failed to fetch chapters by book');
    }
  }

  Future<ChapterModel> getChapterById(String id) async {
    final url = ApiRoutes.chapterById.replaceFirst(':id', id);
    final response = await client.get(Uri.parse(url));

    if (response.statusCode == 200) {
      return ChapterModel.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to fetch chapter');
    }
  }

  Future<ChapterModel> updateChapter(
    String id,
    Map<String, dynamic> updates,
    String authToken,
  ) async {
    final url = ApiRoutes.chapterById.replaceFirst(':id', id);
    final response = await client.put(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $authToken',
      },
      body: jsonEncode(updates),
    );

    if (response.statusCode == 200) {
      return ChapterModel.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to update chapter');
    }
  }

  Future<void> deleteChapter(String id, String authToken) async {
    final url = ApiRoutes.chapterById.replaceFirst(':id', id);
    final response = await client.delete(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $authToken'},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete chapter');
    }
  }
}
