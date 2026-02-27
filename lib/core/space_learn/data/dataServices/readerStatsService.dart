import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../utils/api_routes.dart';
import '../../../utils/token_storage.dart';
import '../model/readerStatsModel.dart';
import '../model/bookReaderStatsModel.dart';

class ReaderStatsService {
  final http.Client client;

  ReaderStatsService({http.Client? client}) : client = client ?? http.Client();

  Future<ReaderStatsModel> getReaderStats(String userId) async {
    // ... existing global stats code ...
    try {
      final token = await TokenStorage.getToken();
      final headers = <String, String>{'Content-Type': 'application/json'};
      if (token != null) headers['Authorization'] = 'Bearer $token';

      final uri = Uri.parse('${ApiRoutes.analytics}/reader/$userId');
      print("▶️ GET GLOBAL STATS: $uri");

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
      print("▶️ GET BOOK STATS: $uri");

      final response = await client.get(uri, headers: headers);
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final dynamic data = responseData['data'] ?? responseData;
        return BookReaderStatsModel.fromJson(data);
      }
      return null;
    } catch (e) {
      print("❌ Error fetching book stats: $e");
      return null;
    }
  }

  Future<bool> recordReadingTime(String livreId) async {
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

      // We send 1 minute of reading time
      final response = await client.put(
        uri,
        headers: headers,
        body: jsonEncode({'reading_time_increment': 1}),
      );

      return response.statusCode == 200;
    } catch (e) {
      print("❌ Error recording reading time: $e");
      return false;
    }
  }

  ReaderStatsModel _getMockStats() {
    return ReaderStatsModel(booksRead: 12, totalTime: '34h', goalsAchieved: 5);
  }
}
