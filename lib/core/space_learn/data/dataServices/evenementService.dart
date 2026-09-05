import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../services/api_client.dart';
import '../../../utils/api_routes.dart';
import '../model/evenementModel.dart';
import 'package:space_learn_flutter/core/utils/message_erreur.dart';

/// L'instant du rendez-vous, tel que le serveur doit le recevoir.
///
/// `toIso8601String()` sur un DateTime LOCAL produit une chaîne sans aucun
/// indicateur de fuseau — « 2026-09-05T18:00:00.000 ». Le serveur
/// (space_learn_livres, modules/evenement/controller.go, `parserDate`) la relit
/// alors comme de l'UTC : l'heure murale de l'organisateur devenait un instant
/// faux de tout son décalage horaire. L'aller-retour ne se compensait qu'en
/// UTC+0 — la Côte d'Ivoire — et se décalait partout ailleurs.
///
/// Une date d'événement désigne un INSTANT : 18 h à Douala, c'est 17 h à
/// Abidjan. L'instant part donc en UTC explicite, avec son « Z ». `parserDate`
/// le reconnaît par ses deux premiers gabarits — RFC3339Nano puis RFC3339 —
/// qui exigent justement un fuseau, celui-là même qu'une date locale Dart
/// n'avait pas.
String _instantPourLeServeur(DateTime date) => date.toUtc().toIso8601String();

class EvenementService {
  final http.Client client;

  EvenementService({http.Client? client})
    : client = client ?? ApiClient.instance;

  Future<Evenement> createEvenement({
    required String typePublication,
    required String titre,
    required String contenu,
    required String token,
    String? imageUrl,
    DateTime? dateEvenement,
    String? categorie,
    String? lienVisio,
  }) async {
    final Map<String, dynamic> body = {
      'type_publication': typePublication,
      'titre': titre,
      'contenu': contenu,
    };
    if (categorie != null && categorie.isNotEmpty) {
      body['categorie'] = categorie;
    }
    if (imageUrl != null) body['image_url'] = imageUrl;
    if (dateEvenement != null) {
      body['date_evenement'] = _instantPourLeServeur(dateEvenement);
    }
    if (lienVisio != null && lienVisio.trim().isNotEmpty) {
      body['lien_visio'] = lienVisio.trim();
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
      throw Exception(
        messageDeLaReponse(
          response,
          repli: "Cet événement n'a pas pu être créé.",
        ),
      );
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
      throw Exception(
        messageDeLaReponse(
          response,
          repli: "Impossible de charger les événements.",
        ),
      );
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
      throw Exception(
        messageDeLaReponse(
          response,
          repli: "Impossible de charger les événements de cet auteur.",
        ),
      );
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
    String? categorie,
    String? lienVisio,
  }) async {
    final url = ApiRoutes.evenementById.replaceFirst(':id', id);
    final Map<String, dynamic> body = {
      'type_publication': typePublication,
      'titre': titre,
      'contenu': contenu,
    };
    if (categorie != null && categorie.isNotEmpty) {
      body['categorie'] = categorie;
    }
    if (imageUrl != null) body['image_url'] = imageUrl;
    if (dateEvenement != null) {
      // Même règle qu'à la création : l'instant part en UTC explicite.
      // Une modification qui renverrait l'heure murale décalerait le
      // rendez-vous à chaque enregistrement pour tout organisateur hors UTC+0.
      body['date_evenement'] = _instantPourLeServeur(dateEvenement);
    }
    // Envoyer une chaîne vide pour effacer le lien existant
    body['lien_visio'] = lienVisio?.trim() ?? '';

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
      throw Exception(
        messageDeLaReponse(
          response,
          repli: "Cet événement n'a pas pu être modifié.",
        ),
      );
    }
  }

  Future<void> deleteEvenement(String id, String token) async {
    final url = ApiRoutes.evenementById.replaceFirst(':id', id);
    final response = await client.delete(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception(
        messageDeLaReponse(
          response,
          repli: "Cet événement n'a pas pu être supprimé.",
        ),
      );
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
      throw Exception(
        messageDeLaReponse(response, repli: "Cet événement est introuvable."),
      );
    }
  }
}
