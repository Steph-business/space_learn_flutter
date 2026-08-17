import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../services/api_client.dart';
import '../../../utils/api_routes.dart';
import '../../../utils/token_storage.dart';
import '../model/readerStatsModel.dart';
import '../model/bookReaderStatsModel.dart';

class ReaderStatsService {
  final http.Client client;

  ReaderStatsService({http.Client? client})
    : client = client ?? ApiClient.instance;

  Future<ReaderStatsModel> getReaderStats(String userId) async {
    // ... existing global stats code ...
    try {
      final token = await TokenStorage.getToken();
      final headers = <String, String>{'Content-Type': 'application/json'};
      if (token != null) headers['Authorization'] = 'Bearer $token';

      final uri = Uri.parse('${ApiRoutes.analytics}/reader/$userId');
      final response = await client.get(uri, headers: headers);
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final dynamic data = responseData['data'] ?? responseData;
        return ReaderStatsModel.fromJson(data);
      }
      return _getMockStats();
    } catch (e) {
      return _getMockStats();
    }
  }

  Future<BookReaderStatsModel?> getBookReaderStats(String livreId) async {
    try {
      final token = await TokenStorage.getToken();
      final headers = <String, String>{'Content-Type': 'application/json'};
      if (token != null) headers['Authorization'] = 'Bearer $token';

      final uri = Uri.parse('${ApiRoutes.analytics}/reader/$livreId');
      final response = await client.get(uri, headers: headers);
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final dynamic data = responseData['data'] ?? responseData;
        return BookReaderStatsModel.fromJson(data);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Déclare [minutes] minutes de lecture sur un livre.
  ///
  /// Le nombre de minutes est un paramètre, et non plus la constante 1 : la
  /// page de lecture appelait cette méthode toutes les quinze secondes en
  /// annonçant chaque fois une minute, ce qui quadruplait le temps de lecture
  /// affiché à l'auteur.
  Future<bool> recordReadingTime(String livreId, {int minutes = 1}) async {
    if (minutes <= 0) return false;
    try {
      final token = await TokenStorage.getToken();
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      // Detailed stats endpoint typically handles per-book reading time increments
      final uri = Uri.parse(
        ApiRoutes.updateDetailedStats.replaceFirst(':livre_id', livreId),
      );

      final response = await client.put(
        uri,
        headers: headers,
        body: jsonEncode({'reading_time_increment': minutes}),
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  ReaderStatsModel _getMockStats() {
    return ReaderStatsModel(booksRead: 0, totalTime: '0m', goalsAchieved: 0);
  }
}
