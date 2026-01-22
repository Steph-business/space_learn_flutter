import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../utils/api_routes.dart';

class AuthorStatsService {
  final http.Client client;

  AuthorStatsService({http.Client? client}) : client = client ?? http.Client();

  Future<Map<String, dynamic>> getAuthorStats(String authorId, String period) async {
    final uri = Uri.parse(ApiRoutes.authorStats.replaceFirst(':authorId', authorId))
        .replace(queryParameters: {'period': period});

    try {
      final response = await client.get(uri);

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        return responseData['data'] ?? {};
      } else {
        // If endpoint not ready, return empty map or mock
        print("⚠️ Author stats API error: ${response.statusCode}");
        return {};
      }
    } catch (e) {
      print("❌ Error fetching author stats: $e");
      return {};
    }
  }
}
