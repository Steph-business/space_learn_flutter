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
      }
    } catch (e) {
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
    }
    return {};
  }
}