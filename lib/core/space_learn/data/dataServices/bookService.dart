import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../services/api_client.dart';
import '../../../utils/api_routes.dart';
import '../model/book_model.dart';

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
      throw Exception(_messageServeur(response, "Impossible de créer ce livre."));
    }
  }

  Future<List<BookModel>> getAllBooks({
    String? auteurId,
    String? statut,
    String? authToken,
  }) async {
    final queryParameters = <String, String>{};
    if (auteurId != null) queryParameters['auteur_id'] = auteurId;
    if (statut != null) queryParameters['statut'] = statut;

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
      } else if (response.statusCode == 404 && queryParameters.isNotEmpty) {
        // Fallback: if filtered query fails with 404, try getting all books

        return getAllBooks(authToken: authToken);
      } else {}
    } catch (e) {}

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
      throw Exception('Failed to fetch book');
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
    throw Exception(_messageServeur(response, "Impossible d'enregistrer ce livre."));
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
      throw Exception(_messageServeur(response, "Impossible de supprimer ce livre."));
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
      throw Exception('Failed to fetch books by category');
    }
  }
}
