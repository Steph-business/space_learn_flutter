import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../services/api_client.dart';
import '../../../utils/api_routes.dart';
import '../model/readingActivityModel.dart';

class ReadingProgressService {
  final http.Client client;

  ReadingProgressService({http.Client? client})
    : client = client ?? ApiClient.instance;

  Future<ReadingActivityModel?> getReadingProgress(
    String livreId,
    String authToken,
  ) async {
    // Utilisation de la route spécifique pour un livre
    return getProgressByLivre(livreId, authToken);
  }

  Future<List<ReadingActivityModel>> getAllProgressions(
    String authToken,
  ) async {
    final uri = Uri.parse(ApiRoutes.readingActivities);

    try {
      final response = await client.get(
        uri,
        headers: {'Authorization': 'Bearer $authToken'},
      );

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        List<dynamic> data = [];
        if (decoded is List) {
          data = decoded;
        } else if (decoded is Map) {
          final d = decoded['data'];
          if (d is List) {
            data = d;
          }
        }

        return data.map((item) => ReadingActivityModel.fromJson(item)).toList();
      } else if (response.statusCode == 404) {
        return [];
      } else {
        throw Exception(
          'Failed to fetch reading activities: ${response.statusCode}',
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<ReadingActivityModel?> getProgressByLivre(
    String livreId,
    String authToken,
  ) async {
    final uri = Uri.parse(
      ApiRoutes.readingProgress.replaceFirst(':livre_id', livreId),
    );

    try {
      final response = await client.get(
        uri,
        headers: {'Authorization': 'Bearer $authToken'},
      );

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final data = decoded['data'] ?? decoded;
          if (data is Map<String, dynamic>) {
            return ReadingActivityModel.fromJson(data);
          }
        }
      }
    } catch (_) {}

    // Fallback: lookup in getAllProgressions which queries /api/reading/activities
    try {
      final all = await getAllProgressions(authToken);
      final match = all.where((p) => p.livreId == livreId).toList();
      if (match.isNotEmpty) {
        return match.first;
      }
    } catch (_) {}

    return null;
  }

  Future<void> updateReadingProgress({
    required String livreId,
    required int currentPage,
    required int totalPages,
    required String authToken,
  }) async {
    final double percentage = (currentPage / totalPages * 100);
    final uri = Uri.parse(
      ApiRoutes.readingProgress.replaceFirst(':livre_id', livreId),
    );

    try {
      final response = await client.put(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({
          'livre_id': livreId,
          'last_page': currentPage,
          'total_pages': totalPages,
          'percentage': percentage,
        }),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(
          'Failed to update reading progress: ${response.statusCode}',
        );
      }
    } catch (e) {
      rethrow;
    }
  }
}
