import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../services/api_client.dart';
import '../../../utils/api_routes.dart';
import '../../../utils/token_storage.dart';

/// Le temps de lecture du LECTEUR, vu du serveur.
///
/// Ce service portait aussi `getReaderStats` et `getBookReaderStats`, tous deux
/// retirés : ils interrogeaient `GET /api/analytics/reader/:livre_id`, une route
/// qui rend les statistiques D'UN LIVRE, en lui passant un identifiant
/// d'UTILISATEUR. Le serveur ne trouvait rien, et le premier rendait alors des
/// statistiques factices (`_getMockStats`, tout à zéro) que l'accueil prenait
/// pour une réponse : une PANNE déguisée en compte à zéro.
///
/// Les deux vraies sources subsistent et suffisent : [lireBilan] pour le compte
/// (total, journée, série, livres), `ReadingTimeStorage` pour l'appareil.
class ReaderStatsService {
  final http.Client client;

  ReaderStatsService({http.Client? client})
    : client = client ?? ApiClient.instance;

  /// Déclare [minutes] minutes de lecture sur un livre.
  ///
  /// Le nombre de minutes est un paramètre, et non plus la constante 1 : la
  /// page de lecture appelait cette méthode toutes les quinze secondes en
  /// annonçant chaque fois une minute, ce qui quadruplait le temps de lecture
  /// affiché à l'auteur.
  Future<bool> recordReadingTime(String livreId, {int minutes = 1}) async {
    if (minutes <= 0) return false;
    try {
      final token = await TokenStorage.getToken();
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      // `/api/reading/activity`, et non `detailed-stats`.
      //
      // L'appel visait auparavant `PUT /api/detailed-stats/:livre_id` avec un
      // champ `reading_time_increment`. Le commentaire d'origine disait que
      // cette route « gère généralement » les incréments de temps : elle ne
      // les gère pas du tout. Ce champ n'existe nulle part côté serveur, et la
      // route est réservée à l'AUTEUR du livre — un lecteur reçoit 403. Les
      // minutes par livre n'ont donc jamais été enregistrées, et la file
      // d'attente locale ne se vidait jamais.
      //
      // Pire quand le lecteur se trouvait être l'auteur : la requête passait,
      // le serveur liait une clé inconnue, obtenait une structure vide, et
      // remettait à zéro les six statistiques du livre.
      final uri = Uri.parse(ApiRoutes.readingActivity);

      final response = await client.post(
        uri,
        headers: headers,
        body: jsonEncode({'livre_id': livreId, 'duree_minutes': minutes}),
      );

      // 201 : la route rend « Created » sur l'activité enregistrée.
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  /// Le bilan de lecture tenu par le serveur : total, journée, série.
  ///
  /// Rend null quand le serveur ne répond pas — l'appelant retombe alors sur
  /// le comptage local, qui reste tenu en parallèle comme cache hors ligne.
  Future<Map<String, int>?> lireBilan() async {
    try {
      final token = await TokenStorage.getToken();
      if (token == null || token.isEmpty) return null;

      final reponse = await client.get(
        Uri.parse(ApiRoutes.readingBilan),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (reponse.statusCode != 200) return null;

      final corps = jsonDecode(reponse.body);
      final d = (corps is Map ? (corps['data'] ?? corps) : null);
      if (d is! Map) return null;

      int lire(String cle) {
        final v = d[cle];
        if (v is num) return v.toInt();
        return int.tryParse('${v ?? ''}') ?? 0;
      }

      return {
        'total': lire('total_minutes'),
        'jour': lire('minutes_jour'),
        'serie': lire('serie_jours'),
        // Les livres terminés et en cours, comptés une seule fois, au même
        // endroit. Chaque écran les recalculait à sa façon : l'accueil depuis
        // les progressions, les paramètres depuis la TAILLE de la bibliothèque
        // — d'où « 1 livre lu » ici et « 2 » là, le même jour, pour le même
        // lecteur.
        'lus': lire('livres_lus'),
        'en_cours': lire('livres_en_cours'),
      };
    } catch (_) {
      return null;
    }
  }

  /// Déclare des minutes de lecture au compte du lecteur.
  ///
  /// Rend `true` seulement si le serveur les a enregistrées. L'appelant en a
  /// besoin : sans cette réponse, il retranchait les minutes de son solde avant
  /// de savoir, et une session lue sans réseau était perdue pour toujours —
  /// avec elle le temps cumulé, la série de jours et les badges d'assiduité.
  Future<bool> declarerMinutes(int minutes) async {
    if (minutes <= 0) return true;
    try {
      final token = await TokenStorage.getToken();
      if (token == null || token.isEmpty) return false;

      final reponse = await client.post(
        Uri.parse(ApiRoutes.readingTemps),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'minutes': minutes}),
      );
      return reponse.statusCode >= 200 && reponse.statusCode < 300;
    } catch (_) {
      // Le comptage local a déjà eu lieu : une minute perdue côté serveur ne
      // doit pas interrompre la lecture. Elle repartira plus tard.
      return false;
    }
  }
}
