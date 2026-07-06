import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../utils/api_routes.dart';
import '../model/evenementModel.dart';

class EvenementService {
  final http.Client client;

  EvenementService({http.Client? client}) : client = client ?? http.Client();

  Future<Evenement> createEvenement({
    required String typePublication,
    required String titre,
    required String contenu,
    required String token,
    String? imageUrl,
    DateTime? dateEvenement,
  }) async {
    final Map<String, dynamic> body = {
      'type_publication': typePublication,
      'titre': titre,
      'contenu': contenu,
    };
    if (imageUrl != null) body['image_url'] = imageUrl;
    if (dateEvenement != null) {
      body['date_evenement'] = dateEvenement.toIso8601String();
    }

    final response = await client.post(
      Uri.parse(ApiRoutes.evenements),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode(body),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      return Evenement.fromJson(data['data'] ?? data);
    } else {
      throw Exception('Failed to create evenement');
    }
  }

  Future<List<Evenement>> getGlobalEvenements(String token) async {
    final response = await client.get(
      Uri.parse(ApiRoutes.evenementsGlobal),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = json.decode(response.body);
      final List<dynamic> list = responseData['data'] ?? [];
      return list.map((json) => Evenement.fromJson(json)).toList();
    } else {
      throw Exception('Failed to fetch global evenements');
    }
  }

  Future<List<Evenement>> getEvenementsByAuthor(
    String auteurId,
    String token,
  ) async {
    final url = ApiRoutes.evenementsByAuthor.replaceFirst(
      ':auteur_id',
      auteurId,
    );
    final response = await client.get(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = json.decode(response.body);
      final List<dynamic> list = responseData['data'] ?? [];
      return list.map((json) => Evenement.fromJson(json)).toList();
    } else {
      throw Exception('Failed to fetch author evenements');
    }
  }

  Future<Evenement> updateEvenement({
    required String id,
    required String typePublication,
    required String titre,
    required String contenu,
    required String token,
    String? imageUrl,
    DateTime? dateEvenement,
  }) async {
    final url = ApiRoutes.evenementById.replaceFirst(':id', id);
    final Map<String, dynamic> body = {
      'type_publication': typePublication,
      'titre': titre,
      'contenu': contenu,
    };
    if (imageUrl != null) body['image_url'] = imageUrl;
    if (dateEvenement != null) {
      body['date_evenement'] = dateEvenement.toIso8601String();
    }

    final response = await client.put(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode(body),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      return Evenement.fromJson(data['data'] ?? data);
    } else {
      throw Exception('Failed to update evenement');
    }
  }

  Future<void> deleteEvenement(String id, String token) async {
    final url = ApiRoutes.evenementById.replaceFirst(':id', id);
    final response = await client.delete(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to delete evenement');
    }
  }

  Future<Evenement> getEvenementById(String id, String token) async {
    final url = ApiRoutes.evenementById.replaceFirst(':id', id);
    final response = await client.get(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      return Evenement.fromJson(data['data'] ?? data);
    } else {
      throw Exception('Failed to get evenement');
    }
  }
}
