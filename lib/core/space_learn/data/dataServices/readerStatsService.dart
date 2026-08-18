import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../services/api_client.dart';
import '../../../utils/api_routes.dart';
import '../../../utils/token_storage.dart';
import '../model/readerStatsModel.dart';
import '../model/bookReaderStatsModel.dart';

class ReaderStatsService {
  final http.Client client;

  ReaderStatsService({http.Client? client})
    : client = client ?? ApiClient.instance;

  Future<ReaderStatsModel> getReaderStats(String userId) async {
    // ... existing global stats code ...
    try {
      final token = await TokenStorage.getToken();
      final headers = <String, String>{'Content-Type': 'application/json'};
      if (token != null) headers['Authorization'] = 'Bearer $token';

      final uri = Uri.parse('${ApiRoutes.analytics}/reader/$userId');
      final response = await client.get(uri, headers: headers);
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final dynamic data = responseData['data'] ?? responseData;
        return ReaderStatsModel.fromJson(data);
      }
      return _getMockStats();
    } catch (e) {
      return _getMockStats();
    }
  }

  Future<BookReaderStatsModel?> getBookReaderStats(String livreId) async {
    try {
      final token = await TokenStorage.getToken();
      final headers = <String, String>{'Content-Type': 'application/json'};
      if (token != null) headers['Authorization'] = 'Bearer $token';

      final uri = Uri.parse('${ApiRoutes.analytics}/reader/$livreId');
      final response = await client.get(uri, headers: headers);
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final dynamic data = responseData['data'] ?? responseData;
        return BookReaderStatsModel.fromJson(data);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

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

      // Detailed stats endpoint typically handles per-book reading time increments
      final uri = Uri.parse(
        ApiRoutes.updateDetailedStats.replaceFirst(':livre_id', livreId),
      );

      final response = await client.put(
        uri,
        headers: headers,
        body: jsonEncode({'reading_time_increment': minutes}),
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  ReaderStatsModel _getMockStats() {
    return ReaderStatsModel(booksRead: 0, totalTime: '0m', goalsAchieved: 0);
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
      };
    } catch (_) {
      return null;
    }
  }

  /// Déclare des minutes de lecture au compte du lecteur.
  Future<void> declarerMinutes(int minutes) async {
    if (minutes <= 0) return;
    try {
      final token = await TokenStorage.getToken();
      if (token == null || token.isEmpty) return;

      await client.post(
        Uri.parse(ApiRoutes.readingTemps),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'minutes': minutes}),
      );
    } catch (_) {
      // Le comptage local a déjà eu lieu : une minute perdue côté serveur ne
      // doit pas interrompre la lecture.
    }
  }
}
