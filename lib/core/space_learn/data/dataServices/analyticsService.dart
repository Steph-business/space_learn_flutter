import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../model/analytics.dart';
import '../../../utils/api_routes.dart';

class AnalyticsService {
  final http.Client httpClient;

  AnalyticsService({http.Client? httpClient})
    : httpClient = httpClient ?? http.Client();

  Future<Analytics> fetchAnalyticsData(
    String utilisateurId,
    String periode,
  ) async {
    try {
      // Construct API URL with query params as needed
      final url = Uri.parse(
        '${ApiRoutes.analytics}?utilisateur_id=\$utilisateurId&period=\$periode',
      );

      final response = await httpClient.get(url);

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        return Analytics.fromJson(jsonResponse);
      } else {
        throw Exception('Failed to load analytics data');
      }
    } catch (e) {
      rethrow;
    }
  }

  // Additional methods to post or update analytics can be added here
}
