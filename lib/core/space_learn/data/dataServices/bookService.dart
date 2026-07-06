import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../utils/api_routes.dart';
import '../model/book_model.dart';

class BookService {
  final http.Client client;

  BookService({http.Client? client}) : client = client ?? http.Client();

  Future<BookModel> createBook(BookModel book, String authToken) async {
    // Only send the fields needed for creation (exclude id, relations, timestamps)
    // Using snake_case format that Go backend expects
    final Map<String, dynamic> createData = {
      'auteur_id': book.auteurId,
      'titre': book.titre,
      'description': book.description,
      'image_couverture': book.imageCouverture,
      'fichier_url': book.fichierUrl,
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
      throw Exception('Failed to create book: ${response.body}');
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
      } else {
      }
    } catch (e) {
    }

    // Fallback: try the main baseUrl host
    try {
      final fallbackUri = Uri.parse(
        ApiRoutes.books.replaceFirst(ApiRoutes.baseUrlsGin, ApiRoutes.baseUrl),
      ).replace(queryParameters: queryParameters);

      final resp2 = await client.get(
        fallbackUri,
        headers: headers.isEmpty ? null : headers,
      );
      if (resp2.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(resp2.body);
        final List<dynamic> data = responseData['data'] ?? [];
        return data.map((json) => BookModel.fromJson(json)).toList();
      } else if (resp2.statusCode == 404 && queryParameters.isNotEmpty) {
        final resp3 = await client.get(
          Uri.parse(
            ApiRoutes.books.replaceFirst(
              ApiRoutes.baseUrlsGin,
              ApiRoutes.baseUrl,
            ),
          ),
          headers: headers.isEmpty ? null : headers,
        );
        if (resp3.statusCode == 200) {
          final Map<String, dynamic> responseData = jsonDecode(resp3.body);
          final List<dynamic> data = responseData['data'] ?? [];
          return data.map((json) => BookModel.fromJson(json)).toList();
        }
      }
    } catch (e) {
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
    } else {
      throw Exception('Failed to update book');
    }
  }

  Future<void> deleteBook(String id, String authToken) async {
    final url = ApiRoutes.bookById.replaceFirst(':id', id);
    final response = await client.delete(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $authToken'},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete book');
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
      } else {
      }
    } catch (e) {
    }

    // Fallback attempt: try the same path using the main baseUrl instead of baseUrlsGin
    try {
      final fallbackUrl = ApiRoutes.booksByAuthor
          .replaceFirst(ApiRoutes.baseUrlsGin, ApiRoutes.baseUrl)
          .replaceFirst(':auteur_id', auteurId);
      final resp2 = await client.get(Uri.parse(fallbackUrl));
      if (resp2.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(resp2.body);
        final List<dynamic> data = responseData['data'] ?? [];
        return data.map((json) => BookModel.fromJson(json)).toList();
      } else {
      }
    } catch (e) {
    }

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
