import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../utils/api_routes.dart';
import '../model/bookStatsModel.dart';

class BookStatsService {
  final http.Client client;

  BookStatsService({http.Client? client}) : client = client ?? http.Client();

  Future<BookStatsModel> createStatistics({
    required String livreId,
    required int vues,
    required int telechargements,
    required double noteMoyenne,
    required double revenus,
    required String periode,
  }) async {
    final response = await client.post(
      Uri.parse(ApiRoutes.createBookStats),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'livre_id': livreId,
        'vues': vues,
        'telechargements': telechargements,
        'note_moyenne': noteMoyenne,
        'revenus': revenus,
        'periode': periode,
      }),
    );

    if (response.statusCode == 201) {
      return BookStatsModel.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to create book statistics');
    }
  }

  Future<List<BookStatsModel>> getStatisticsByBook(String livreId) async {
    final url = ApiRoutes.bookStatsByBook.replaceFirst(':livre_id', livreId);
    final response = await client.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => BookStatsModel.fromJson(json)).toList();
    } else {
      throw Exception('Failed to fetch book statistics for book');
    }
  }

  Future<BookStatsModel> updateStatistics({
    required String id,
    int? vues,
    int? telechargements,
    double? noteMoyenne,
    double? revenus,
    String? periode,
  }) async {
    final url = ApiRoutes.updateBookStats.replaceFirst(':id', id);
    final body = <String, dynamic>{};
    if (vues != null) body['vues'] = vues;
    if (telechargements != null) body['telechargements'] = telechargements;
    if (noteMoyenne != null) body['note_moyenne'] = noteMoyenne;
    if (revenus != null) body['revenus'] = revenus;
    if (periode != null) body['periode'] = periode;

    final response = await client.put(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      return BookStatsModel.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to update book statistics');
    }
  }
}
