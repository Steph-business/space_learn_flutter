import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../utils/api_routes.dart';
import '../model/readingActivityModel.dart';

class ReadingProgressService {
  final http.Client client;

  ReadingProgressService({http.Client? client})
    : client = client ?? http.Client();

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
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final List<dynamic>? data = responseData['data'];
        if (data != null) {
          return data
              .map((item) => ReadingActivityModel.fromJson(item))
              .toList();
        }
        return [];
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
      ApiRoutes.readingProgressByLivre.replaceFirst(':livre_id', livreId),
    );

    try {
      final response = await client.get(
        uri,
        headers: {'Authorization': 'Bearer $authToken'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final data = responseData['data'];
        if (data != null) {
          return ReadingActivityModel.fromJson(data);
        }
        return null;
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw Exception(
          'Failed to fetch reading progress: ${response.statusCode}',
        );
      }
    } catch (e) {
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
