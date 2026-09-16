import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../services/api_client.dart';
import '../../../utils/api_routes.dart';
import '../model/review_model.dart';
import 'package:space_learn_flutter/core/utils/message_erreur.dart';

class ReviewService {
  final http.Client client;

  ReviewService({http.Client? client}) : client = client ?? ApiClient.instance;

  Future<ReviewModel> addReview({
    required String livreId,
    required int note,
    required String commentaire,
    required String authToken,
  }) async {
    final response = await client.post(
      Uri.parse(ApiRoutes.reviews),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $authToken',
      },
      body: jsonEncode({
        'livre_id': livreId,
        'note': note,
        'commentaire': commentaire,
      }),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      final Map<String, dynamic> responseData = jsonDecode(response.body);
      return ReviewModel.fromJson(responseData['data'] ?? responseData);
    } else {
      throw Exception(
        messageDeLaReponse(
          response,
          repli: "Votre avis n'a pas pu être publié.",
        ),
      );
    }
  }

  /// Les avis d'un livre — les CENT PLUS RÉCENTS, et pas davantage.
  ///
  /// Sans paramètre, le serveur rend sa première tranche : cent avis pour un
  /// livre (`PlafondAvisParLivre`, space_learn_livres modules/avis) plus un
  /// `meta{total, limite, decalage}`. Le nombre et la moyenne ne se déduisent
  /// JAMAIS de la longueur de cette liste : ils viennent du livre
  /// (`nombre_avis`, `note_moyenne`), et `book_detail_page.dart` comme
  /// `all_reviews_page.dart` les lisent déjà là.
  ///
  /// SI UN JOUR UN « VOIR PLUS » S'AJOUTE ICI, LA RÈGLE EST CELLE-CI, et elle
  /// corrige une instruction du tour précédent qui était FAUSSE : envoyer
  /// `?limit=100&page=N`, LES DEUX ENSEMBLE, jamais `page` seul. `page` seul
  /// faisait retomber le serveur sur sa limite par défaut de dix : la page 2
  /// rendait les avis 11 à 20 alors que la page 1 en avait rendu cent — que
  /// des doublons, et l'avis n° 101 inatteignable. Le serveur a corrigé sa
  /// moitié (le défaut d'une liste vaut désormais son plafond), la règle vaut
  /// avant comme après ce déploiement.
  ///
  /// Trois refus possibles, et AUCUN n'appelle « Réessayer » : 400
  /// « Connectez-vous pour parcourir l'ensemble des avis. » à un vrai anonyme
  /// qui demande une page > 1 — c'est un refus de droit, l'écran mène à la
  /// connexion ; 401 « Votre session a expiré… » quand un jeton périmé a été
  /// présenté — `ApiClient` renouvelle et rejoue, l'écran ne devrait jamais le
  /// voir ; 400 « Cette page est trop loin dans les avis de ce livre… »
  /// au-delà du décalage 5 000. Sur un échec RÉSEAU, la doctrine ordinaire :
  /// le message et un bouton « Réessayer », jamais « aucun avis ».
  ///
  /// Ne posez PAS l'en-tête `Authorization` à la main ici : `ApiClient` est la
  /// couche transport par défaut de ce service et le pose lui-même
  /// (api_client.dart). Le poser deux fois empêcherait le rejeu après
  /// renouvellement, qui compare le jeton posé à celui de la session.
  Future<List<ReviewModel>> getBookReviews(String livreId) async {
    final url = ApiRoutes.reviewsByBook.replaceFirst(':livre_id', livreId);
    final response = await client.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = jsonDecode(response.body);
      final List<dynamic> data = responseData['data'] ?? [];
      return data.map((json) => ReviewModel.fromJson(json)).toList();
    } else {
      throw Exception(
        messageDeLaReponse(
          response,
          repli: "Impossible de charger les avis sur ce livre.",
        ),
      );
    }
  }

  Future<List<ReviewModel>> getUserReviews(String authToken) async {
    final response = await client.get(
      Uri.parse(ApiRoutes.reviewsByUser),
      headers: {'Authorization': 'Bearer $authToken'},
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = jsonDecode(response.body);
      final List<dynamic> data = responseData['data'] ?? [];
      return data.map((json) => ReviewModel.fromJson(json)).toList();
    } else {
      throw Exception(
        messageDeLaReponse(response, repli: "Impossible de charger vos avis."),
      );
    }
  }
}
