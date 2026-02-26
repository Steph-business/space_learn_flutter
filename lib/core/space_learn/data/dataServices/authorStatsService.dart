import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../utils/api_routes.dart';

class AuthorStatsService {
  final http.Client client;

  AuthorStatsService({http.Client? client}) : client = client ?? http.Client();

  Future<Map<String, dynamic>> getAuthorStats(
    String authorId,
    String period,
  ) async {
    Uri uri = Uri.parse(
      ApiRoutes.authorStats.replaceFirst(':authorId', authorId),
    ).replace(queryParameters: {'period': period});

    try {
      final response = await client.get(uri);

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        return responseData['data'] ?? {};
      } else {
        print(
          "⚠️ Author stats API error: ${response.statusCode}, attempting fallback host",
        );
      }
    } catch (e) {
      print("❌ Error fetching author stats: $e - trying fallback host");
    }

    // Fallback: try same path but with the main `baseUrl` instead of `baseUrlsGin`.
    try {
      final fallback = ApiRoutes.authorStats
          .replaceFirst(ApiRoutes.baseUrlsGin, ApiRoutes.baseUrl)
          .replaceFirst(':authorId', authorId);
      final fallbackUri = Uri.parse(
        fallback,
      ).replace(queryParameters: {'period': period});
      final resp2 = await client.get(fallbackUri);
      if (resp2.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(resp2.body);
        return responseData['data'] ?? {};
      } else {
        print('⚠️ Fallback author stats failed: ${resp2.statusCode}');
      }
    } catch (e) {
      print('❌ Fallback error fetching author stats: $e');
    }

    return {};
  }

  Future<Map<String, dynamic>> getAuthorRevenue(
    String authorId,
    String period,
  ) async {
    Uri uri = Uri.parse(
      ApiRoutes.authorRevenue.replaceFirst(':authorId', authorId),
    ).replace(queryParameters: {'period': period});

    try {
      final response = await client.get(uri);
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        return responseData['data'] ?? {};
      }
    } catch (e) {
      print("❌ Error fetching author revenue: $e");
    }
    return {};
  }
}
