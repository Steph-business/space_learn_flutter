import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../utils/api_routes.dart';
import '../model/citation_model.dart';

class CitationService {
  final http.Client client;

  CitationService({http.Client? client}) : client = client ?? http.Client();

  Future<CitationModel?> getDailyCitation(String authToken) async {
    try {
      final response = await client.get(
        Uri.parse(ApiRoutes.citationsDaily),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        return CitationModel.fromJson(responseData['data']);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}