import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../services/api_client.dart';
import '../model/discussionModel.dart';
import '../../../utils/api_routes.dart';
import 'package:space_learn_flutter/core/utils/message_erreur.dart';

class DiscussionService {
  final http.Client client;

  DiscussionService({http.Client? client})
    : client = client ?? ApiClient.instance;

  /// Les salons d'une réponse, un par un.
  ///
  /// Une boucle plutôt qu'un `map`, comme dans `DmService` : `map` propage
  /// l'échec du premier élément mal formé à toute la liste, et la page de
  /// forum entière s'affiche alors en panne pour un seul salon abîmé. Ici
  /// l'élément illisible est SAUTÉ et les autres s'affichent.
  ///
  /// Les quatre lectures de liste passent par ici : la règle vit en un seul
  /// endroit, sinon quatre copies finiraient par diverger.
  List<Discussion> _salons(List<dynamic> liste, String provenance) {
    final salons = <Discussion>[];
    for (final element in liste) {
      try {
        salons.add(Discussion.fromJson(Map<String, dynamic>.from(element)));
      } catch (e) {
        // Sauté, mais pas en silence complet : une trace pour le journal, rien
        // à l'écran — la personne qui lit n'a rien à faire de cette
        // information, et une liste amputée d'un salon reste utile.
        debugPrint('Salon illisible ignoré ($provenance) : $e');
        continue;
      }
    }
    return salons;
  }

  Future<Discussion> createDiscussion({
    required String type,
    required String titre,
    required String token,
    String? description,
    String? imageBanniere,
    String? livreId,
    String? auteurId,
    String? categorie,
  }) async {
    final Map<String, dynamic> body = {'type': type, 'titre': titre};
    if (categorie != null) body['categorie'] = categorie;
    if (description != null) body['description'] = description;
    if (imageBanniere != null) body['image_banniere'] = imageBanniere;
    if (livreId != null) body['livre_id'] = livreId;
    if (auteurId != null) body['auteur_id'] = auteurId;

    final response = await client.post(
      Uri.parse(ApiRoutes.discussions),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode(body),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      return Discussion.fromJson(data['data'] ?? data);
    } else {
      throw Exception(
        messageDeLaReponse(response, repli: "Ce salon n'a pas pu être créé."),
      );
    }
  }

  Future<List<Discussion>> getGlobalDiscussions() async {
    final response = await client.get(Uri.parse(ApiRoutes.discussionsGlobal));

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = json.decode(response.body);
      final List<dynamic> list = responseData['data'] ?? [];
      return _salons(list, 'salons publics');
    } else {
      throw Exception(
        messageDeLaReponse(
          response,
          repli: "Impossible de charger les salons.",
        ),
      );
    }
  }

  Future<List<Discussion>> getDiscussionsByAuthor(String auteurId) async {
    final url = ApiRoutes.discussionsByAuthor.replaceFirst(
      ':auteur_id',
      auteurId,
    );
    final response = await client.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = json.decode(response.body);
      final List<dynamic> list = responseData['data'] ?? [];
      return _salons(list, "salons de l'auteur $auteurId");
    } else {
      throw Exception(
        messageDeLaReponse(
          response,
          repli: "Impossible de charger les salons de cet auteur.",
        ),
      );
    }
  }

  Future<List<Discussion>> getDiscussionsByLivre(
    String livreId,
    String token,
  ) async {
    final url = ApiRoutes.discussionsByBook.replaceFirst(':livre_id', livreId);
    final response = await client.get(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = json.decode(response.body);
      final List<dynamic> list = responseData['data'] ?? [];
      return _salons(list, 'salons du livre $livreId');
    } else {
      throw Exception(
        messageDeLaReponse(
          response,
          repli: "Impossible de charger les salons de ce livre.",
        ),
      );
    }
  }

  Future<List<Discussion>> getDiscussionsByUser(String token) async {
    final response = await client.get(
      Uri.parse(ApiRoutes.discussions),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = json.decode(response.body);
      final List<dynamic> list = responseData['data'] ?? [];
      return _salons(list, 'mes salons');
    } else {
      throw Exception(
        messageDeLaReponse(
          response,
          repli: "Impossible de charger les salons.",
        ),
      );
    }
  }

  Future<Discussion> getDiscussionById(String id) async {
    final url = ApiRoutes.discussionById.replaceFirst(':id', id);
    final response = await client.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      return Discussion.fromJson(data['data'] ?? data);
    } else {
      throw Exception(
        messageDeLaReponse(response, repli: "Ce salon est introuvable."),
      );
    }
  }

  /// Modifie un sujet : titre, description, bannière.
  ///
  /// Seuls les champs fournis partent. Côté serveur, un champ absent veut dire
  /// « ne touche pas » et non « efface » — envoyer systématiquement le titre
  /// suffisait tant qu'on ne modifiait que lui, mais aurait effacé la
  /// description dès qu'on aurait voulu la corriger.
  Future<Discussion> updateDiscussion(
    String id,
    String token, {
    String? titre,
    String? description,
    String? imageBanniere,
  }) async {
    final url = ApiRoutes.discussionById.replaceFirst(':id', id);
    final response = await client.put(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({
        if (titre != null) 'titre': titre,
        if (description != null) 'description': description,
        if (imageBanniere != null) 'image_banniere': imageBanniere,
      }),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      return Discussion.fromJson(data['data'] ?? data);
    } else {
      throw Exception(
        messageDeLaReponse(
          response,
          repli: "Ce salon n'a pas pu être modifié.",
        ),
      );
    }
  }

  /// Aime un sujet, ou retire son j'aime.
  ///
  /// Un seul appel pour les deux sens : l'application n'a pas a savoir dans
  /// quel etat elle se trouve avant d'agir, ce qui evite qu'un double appui ne
  /// laisse deux mentions. Le serveur renvoie l'etat obtenu.
  Future<({bool aime, int total})> basculerJaime(
    String discussionId,
    String token,
  ) async {
    final url = '${ApiRoutes.discussions}/$discussionId/jaime';
    final response = await client.post(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final Map<String, dynamic> data = json.decode(response.body);
      final contenu = (data['data'] ?? data) as Map<String, dynamic>;
      return (
        aime: contenu['aime_par_moi'] == true,
        total: (contenu['nombre_jaime'] as num?)?.toInt() ?? 0,
      );
    }
    throw Exception(
      messageDeLaReponse(
        response,
        repli: "Votre mention j'aime n'a pas pu être enregistrée.",
      ),
    );
  }

  Future<void> deleteDiscussion(String id, String token) async {
    final url = ApiRoutes.discussionById.replaceFirst(':id', id);
    final response = await client.delete(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      throw Exception(
        messageDeLaReponse(
          response,
          repli: "Ce salon n'a pas pu être supprimé.",
        ),
      );
    }
  }
}
