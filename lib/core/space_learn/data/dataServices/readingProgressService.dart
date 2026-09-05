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
    // GET /api/reading/progress (ListProgressions), et non /activities.
    //
    // Cette méthode interrogeait GET /api/reading/activities, qui rend des
    // SÉANCES {duree_minutes, chapitre, cree_le} — jamais last_page,
    // total_pages ni percentage. Le modèle inventait alors pourcentage=0, et
    // les consommateurs (accueil, bibliothèque, badges) écrasaient avec ce
    // zéro la progression réelle : barre à 0 % sur un livre lu à 40 %, carte
    // « Reprendre la lecture » disparue, badges « livres lus » figés. La route
    // des progressions existe côté serveur (routes.go) et rend exactement les
    // champs que le modèle attend.
    final uri = Uri.parse('${ApiRoutes.baseUrlsGin}/api/reading/progress');

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
          'Failed to fetch reading progressions: ${response.statusCode}',
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

    // Repli : chercher dans la liste complète des progressions
    // (GET /api/reading/progress)
    try {
      final all = await getAllProgressions(authToken);
      final match = all.where((p) => p.livreId == livreId).toList();
      if (match.isNotEmpty) {
        return match.first;
      }
    } catch (_) {}

    return null;
  }

  /// Un envoi à la fois par livre : la file des progressions en cours.
  ///
  /// Statique, car les écrivains sont plusieurs et chacun a SON instance du
  /// service (la page de lecture, la lecture audio, l'accueil). Une file
  /// d'instance ne sérialiserait rien du tout.
  static final Map<String, Future<void>> _fileParLivre = {};

  /// Le numéro du dernier envoi DEMANDÉ pour ce livre.
  static final Map<String, int> _dernierNumero = {};

  /// Envoie la position courante — au plus une requête en vol par livre.
  ///
  /// Deux PUT pouvaient voyager ensemble : le minuteur de deux secondes de la
  /// page de lecture tire à T, la sortie du livre à T+1 s envoie
  /// immédiatement la page suivante, et rien ne les départageait. Pas côté
  /// client (un `client.put` nu), pas côté serveur (lecture/controller.go lit
  /// puis écrit sans transaction, sans numéro de version, et n'accepte aucun
  /// horodatage dans le corps). Le dernier `Save` arrivé gagnait, sans que ce
  /// soit le plus récent : le lecteur rouvrait son livre à la page
  /// précédente, et surtout, s'il venait de tourner la DERNIÈRE page, son
  /// pourcentage retombait de 100 à 99,67 % — le livre quittait alors le
  /// compteur « livres lus » et les badges qui s'y adossent, sans aucun moyen
  /// de le corriger autrement qu'en rouvrant le livre.
  ///
  /// La parade tient en deux gestes, tous deux ici — c'est le seul endroit qui
  /// voit TOUS les écrivains :
  ///   1. une chaîne de futurs par livre : le PUT suivant n'est émis qu'une
  ///      fois le précédent retombé, donc l'ordre d'arrivée au serveur est
  ///      celui de l'émission ;
  ///   2. un numéro d'ordre : au moment de partir, un envoi dépassé par un
  ///      plus récent est abandonné sans requête. La valeur envoyée est
  ///      ABSOLUE et non incrémentale — abandonner l'ancienne ne perd rien, et
  ///      c'est autant de réseau économisé sur une page tournée vite.
  ///
  /// Le futur rendu est celui de CET appel : il porte l'erreur du PUT à son
  /// appelant, tandis que la file, elle, ne retient pas l'échec — sinon un
  /// serveur en panne condamnerait tous les envois suivants du même livre.
  Future<void> updateReadingProgress({
    required String livreId,
    required int currentPage,
    required int totalPages,
    required String authToken,
  }) {
    // Le numéro est pris MAINTENANT, sans `await` avant lui : c'est ce qui
    // fait de l'ordre des appels un ordre observable.
    final int numero = (_dernierNumero[livreId] ?? 0) + 1;
    _dernierNumero[livreId] = numero;

    final Future<void> precedent =
        _fileParLivre[livreId] ?? Future<void>.value();

    final Future<void> envoi = precedent.then((_) {
      if (_dernierNumero[livreId] != numero) {
        // Dépassé pendant l'attente : une position plus récente part juste
        // après. Rendre la main sans erreur, il n'y a rien à signaler.
        return Future<void>.value();
      }
      return _envoyerProgression(
        livreId: livreId,
        currentPage: currentPage,
        totalPages: totalPages,
        authToken: authToken,
      );
    });

    _fileParLivre[livreId] = envoi.catchError((_) {}).whenComplete(() {
      // Plus rien en attente pour ce livre : on ne garde pas une entrée
      // par livre ouvert pendant toute la vie de l'application.
      if (_dernierNumero[livreId] == numero) {
        _fileParLivre.remove(livreId);
        _dernierNumero.remove(livreId);
      }
    });

    return envoi;
  }

  Future<void> _envoyerProgression({
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
