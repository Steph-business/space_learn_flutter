import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../utils/api_routes.dart';
import '../model/readingActivityModel.dart';

class ReadingProgressService {
  final http.Client client;

  ReadingProgressService({http.Client? client}) : client = client ?? http.Client();

  Future<ReadingActivityModel?> getReadingProgress(String livreId, String authToken) async {
    // Assuming there's an endpoint to get progress for a specific book
    // If not, we might need to fetch all activities and filter, or use a specific endpoint
    // For now, let's assume we can pass livre_id as a query param or similar
    // Or maybe the backend handles it via the 'readingActivity' route
    
    final uri = Uri.parse('${ApiRoutes.readingActivity}?livre_id=$livreId');
    
    final response = await client.get(
      uri,
      headers: {'Authorization': 'Bearer $authToken'},
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = jsonDecode(response.body);
      // Check if data is present
      if (responseData['data'] != null) {
         return ReadingActivityModel.fromJson(responseData['data']);
      }
      return null;
    } else if (response.statusCode == 404) {
      return null;
    } else {
      throw Exception('Failed to fetch reading progress');
    }
  }

  Future<void> updateReadingProgress({
    required String livreId,
    required int currentPage,
    required int totalPages,
    required String authToken,
  }) async {
    final int percentage = (currentPage / totalPages * 100).round();
    
    final response = await client.post(
      Uri.parse(ApiRoutes.readingProgress),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $authToken',
      },
      body: jsonEncode({
        'livre_id': livreId,
        'chapitre_courant': currentPage, // Using chapter_current for page number
        'pourcentage': percentage,
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to update reading progress');
    }
  }
}
