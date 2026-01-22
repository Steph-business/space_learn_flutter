import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../utils/api_routes.dart';
import '../model/readingActivityModel.dart';

class ReadingProgressService {
  final http.Client client;

  ReadingProgressService({http.Client? client}) : client = client ?? http.Client();

  Future<ReadingActivityModel?> getReadingProgress(String livreId, String authToken) async {
    final uri = Uri.parse('${ApiRoutes.readingActivity}?livre_id=$livreId');
    
    print("🔍 [ReadingProgressService] Fetching progress for book: $livreId");
    print("📡 [ReadingProgressService] GET URL: $uri");

    try {
      final response = await client.get(
        uri,
        headers: {'Authorization': 'Bearer $authToken'},
      );

      print("📥 [ReadingProgressService] Response Status: ${response.statusCode}");
      print("📥 [ReadingProgressService] Response Body: ${response.body}");

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final data = responseData['data'];
        if (data != null) {
          if (data is List) {
            if (data.isNotEmpty) {
              return ReadingActivityModel.fromJson(data.first);
            }
            return null;
          } else if (data is Map<String, dynamic>) {
            return ReadingActivityModel.fromJson(data);
          }
        }
        return null;
      } else if (response.statusCode == 404) {
        print("⚠️ [ReadingProgressService] No progress found (404). This might be normal for a new book.");
        return null;
      } else {
        print("❌ [ReadingProgressService] Error: ${response.statusCode}");
        throw Exception('Failed to fetch reading progress: ${response.statusCode}');
      }
    } catch (e) {
      print("❌ [ReadingProgressService] Exception: $e");
      rethrow;
    }
  }

  Future<void> updateReadingProgress({
    required String livreId,
    required int currentPage,
    required int totalPages,
    required String authToken,
  }) async {
    final int percentage = (currentPage / totalPages * 100).round();
    final uri = Uri.parse(ApiRoutes.readingProgress);

    print("💾 [ReadingProgressService] Updating progress: Book=$livreId, Page=$currentPage ($percentage%)");
    print("📡 [ReadingProgressService] POST URL: $uri");
    
    try {
      final response = await client.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({
          'livre_id': livreId,
          'chapitre_courant': currentPage,
          'pourcentage': percentage,
        }),
      );

      print("📥 [ReadingProgressService] Update Response Status: ${response.statusCode}");
      print("📥 [ReadingProgressService] Update Response Body: ${response.body}");

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to update reading progress: ${response.statusCode}');
      }
    } catch (e) {
      print("❌ [ReadingProgressService] Update Exception: $e");
      rethrow;
    }
  }
}
