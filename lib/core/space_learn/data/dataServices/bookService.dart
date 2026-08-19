import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../services/api_client.dart';
import '../../../utils/api_routes.dart';
import '../model/book_model.dart';
import 'package:space_learn_flutter/core/utils/message_erreur.dart';

class BookService {
  final http.Client client;

  BookService({http.Client? client}) : client = client ?? ApiClient.instance;

  Future<BookModel> createBook(BookModel book, String authToken) async {
    // Only send the fields needed for creation (exclude id, relations, timestamps)
    // Using snake_case format that Go backend expects
    final Map<String, dynamic> createData = {
      'auteur_id': book.auteurId,
      'titre': book.titre,
      'description': book.description,
      'argumentaire_partage': book.argumentairePartage,
      'image_couverture': book.imageCouverture,
      // Ni fichier_url ni fichier_extrait_url : le serveur les refuse en
      // entrée depuis que le contrôle de doublon vit dans le téléversement.
      // Les envoyer quand même n'était que du poids mort, et laissait croire
      // que le client décidait de l'emplacement des fichiers.
      'format': book.format,
      'prix': book.prix,
      'stock': book.stock,
      'statut': book.statut,
    };

    // Always include categorie_id - if null, send empty string or handle appropriately
    if (book.categorieId != null && book.categorieId!.isNotEmpty) {
      createData['categorie_id'] = book.categorieId;
    } else {
      // Send empty string or null for categorie_id if not provided
      createData['categorie_id'] = '';
    }
    final response = await client.post(
      Uri.parse(ApiRoutes.books),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $authToken',
      },
      body: jsonEncode(createData),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      return BookModel.fromJson(data['data'] ?? data);
    } else {
      throw Exception(
        _messageServeur(response, "Impossible de créer ce livre."),
      );
    }
  }

  /// Taille d'une page, alignée sur le plafond du serveur.
  ///
  /// `utils.LimiteMax` vaut 100 côté serveur : demander davantage ne rend pas
  /// davantage, cela consomme seulement une requête pour rien.
  static const int taillePage = 100;

  /// Ce qu'un écran peut réclamer d'un coup sans le dire.
  ///
  /// Une version précédente enchaînait les pages jusqu'à recevoir la dernière.
  /// Correct sur un catalogue de trois livres, intenable ensuite : l'accueil
  /// aurait téléchargé le catalogue entier à chaque ouverture. Un chargement
  /// s'arrête maintenant à un nombre d'éléments annoncé — et le dit quand il
  /// s'arrête, plutôt que de laisser croire que la liste est complète.
  static const int maximumParDefaut = 200;

  /// Une page précise du catalogue, et elle seule.
  ///
  /// C'est ce qu'utilisent les écrans qui chargent la suite au défilement.
  /// [page] commence à 1.
  Future<List<BookModel>> getBooksPage({
    String? auteurId,
    String? statut,
    String? authToken,
    String? categorieId,
    String? recherche,
    int page = 1,
    int limit = taillePage,
  }) {
    return _pageDeLivres(
      auteurId: auteurId,
      statut: statut,
      authToken: authToken,
      categorieId: categorieId,
      recherche: recherche,
      limit: limit,
      page: page,
    );
  }

  /// Un ensemble borné de livres, en enchaînant les pages si nécessaire.
  ///
  /// Réservé aux ensembles dont on sait qu'ils sont petits — les livres d'un
  /// auteur, par exemple. [maximum] est un plafond ferme : atteint, la liste
  /// est incomplète et le journal le signale. Pour parcourir un catalogue,
  /// utiliser [getBooksPage] et charger la suite au défilement.
  Future<List<BookModel>> getAllBooks({
    String? auteurId,
    String? statut,
    String? authToken,
    int maximum = maximumParDefaut,
  }) async {
    final tous = <BookModel>[];

    for (var p = 1; tous.length < maximum; p++) {
      final reste = maximum - tous.length;
      final lot = await _pageDeLivres(
        auteurId: auteurId,
        statut: statut,
        authToken: authToken,
        limit: reste < taillePage ? reste : taillePage,
        page: p,
      );
      tous.addAll(lot);

      // Page incomplète : il n'y a plus rien derrière. C'est le seul signal de
      // fin dont on dispose, la réponse ne portant pas de compteur total.
      if (lot.length < taillePage) return tous;
    }

    debugPrint(
      'Catalogue : arrêt à $maximum livres. La liste affichée est incomplète.',
    );
    return tous;
  }

  /// Une page, un appel.
  Future<List<BookModel>> _pageDeLivres({
    String? auteurId,
    String? statut,
    String? authToken,
    String? categorieId,
    String? recherche,
    required int limit,
    required int page,
  }) async {
    final queryParameters = <String, String>{
      'limit': '$limit',
      'page': '$page',
    };
    if (auteurId != null) queryParameters['auteur_id'] = auteurId;
    if (statut != null) queryParameters['statut'] = statut;
    if (categorieId != null) queryParameters['categorie_id'] = categorieId;
    // Le serveur ignore une recherche de moins de deux caracteres : une lettre
    // seule ne restreint rien et lui coute un parcours complet.
    if (recherche != null && recherche.trim().length >= 2) {
      queryParameters['q'] = recherche.trim();
    }

    final uri = Uri.parse(
      ApiRoutes.books,
    ).replace(queryParameters: queryParameters);

    final headers = <String, String>{};
    if (authToken != null && authToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $authToken';
    }

    try {
      final response = await client.get(
        uri,
        headers: headers.isEmpty ? null : headers,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final List<dynamic> data = responseData['data'] ?? [];
        return data.map((json) => BookModel.fromJson(json)).toList();
      }

      // Un filtre inconnu du serveur : on retente sans lui plutôt que de
      // rendre une liste vide sans explication.
      if (response.statusCode == 404 &&
          (auteurId != null || statut != null)) {
        return _pageDeLivres(authToken: authToken, limit: limit, page: page);
      }

      // Le silence était total ici : trois branches vides, et un catalogue
      // vide à l'écran sans que rien ne dise pourquoi — 429 du limiteur de
      // débit compris.
      debugPrint(
        'Catalogue : HTTP ${response.statusCode} sur $uri '
        '— ${messageDeLaReponse(response, repli: 'sans détail')}',
      );
    } catch (e) {
      debugPrint('Catalogue : $uri injoignable — $e');
    }

    return [];
  }

  /// Fetch a single book by id. If [authToken] is provided, it will be sent
  /// in the Authorization header. Some endpoints return richer data for
  /// authenticated requests (including author info), so prefer passing the
  /// token when available.
  Future<BookModel> getBookById(String id, {String? authToken}) async {
    final url = ApiRoutes.bookById.replaceFirst(':id', id);
    final uri = Uri.parse(url);
    final headers = <String, String>{};
    if (authToken != null && authToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $authToken';
    }

    final response = await client.get(
      uri,
      headers: headers.isEmpty ? null : headers,
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = jsonDecode(response.body);
      return BookModel.fromJson(responseData['data'] ?? responseData);
    } else {
      throw Exception(
        messageDeLaReponse(response, repli: "Ce livre est introuvable."),
      );
    }
  }

  Future<BookModel> updateBook(
    String id,
    Map<String, dynamic> updates,
    String authToken,
  ) async {
    final url = ApiRoutes.bookById.replaceFirst(':id', id);
    final response = await client.put(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $authToken',
      },
      body: jsonEncode(updates),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = jsonDecode(response.body);
      return BookModel.fromJson(responseData['data'] ?? responseData);
    }
    throw Exception(
      _messageServeur(response, "Impossible d'enregistrer ce livre."),
    );
  }

  /// Le message du serveur, quand il en donne un.
  ///
  /// « Failed to update book » ne dit rien à personne. Le serveur, lui, répond
  /// des phrases utilisables : « ce manuscrit est trop court pour être publié :
  /// 4 page(s) déposée(s), 10 au minimum », ou « ce manuscrit est déjà publié
  /// sous le titre "X" ». Les jeter pour une chaîne générique laissait l'auteur
  /// devant un échec sans cause et sans remède.
  static String _messageServeur(http.Response reponse, String repli) {
    try {
      final corps = jsonDecode(reponse.body);
      if (corps is Map) {
        final message = corps['error'] ?? corps['message'];
        if (message is String && message.trim().isNotEmpty) return message;
      }
    } catch (_) {}

    return switch (reponse.statusCode) {
      401 => 'Session expirée, reconnectez-vous.',
      403 => "Vous n'êtes pas l'auteur de ce livre.",
      404 => 'Livre introuvable.',
      503 => 'Service momentanément indisponible. Réessayez dans un instant.',
      _ => '$repli (${reponse.statusCode})',
    };
  }

  Future<void> deleteBook(String id, String authToken) async {
    final url = ApiRoutes.bookById.replaceFirst(':id', id);
    final response = await client.delete(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $authToken'},
    );

    if (response.statusCode != 200) {
      throw Exception(
        _messageServeur(response, "Impossible de supprimer ce livre."),
      );
    }
  }

  Future<List<BookModel>> getBooksByAuthorId(String auteurId) async {
    final url = ApiRoutes.booksByAuthor.replaceFirst(':auteur_id', auteurId);
    try {
      final response = await client.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final List<dynamic> data = responseData['data'] ?? [];
        return data.map((json) => BookModel.fromJson(json)).toList();
      } else {}
    } catch (e) {}

    return [];
  }

  // Alias for consistency
  Future<List<BookModel>> getBooksByAuthor(String auteurId) =>
      getBooksByAuthorId(auteurId);
  Future<List<BookModel>> getBooksByCategory(String categorieId) async {
    final queryParameters = {'categorie_id': categorieId};
    final uri = Uri.parse(
      ApiRoutes.books,
    ).replace(queryParameters: queryParameters);
    final response = await client.get(uri);

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = jsonDecode(response.body);
      final List<dynamic> data = responseData['data'] ?? [];
      return data.map((json) => BookModel.fromJson(json)).toList();
    } else {
      throw Exception(
        messageDeLaReponse(
          response,
          repli: "Impossible de charger les livres de cette catégorie.",
        ),
      );
    }
  }
}
