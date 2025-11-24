import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../utils/api_routes.dart';
import '../model/detailedStatsModel.dart';

class DetailedStatsService {
  final http.Client client;

  DetailedStatsService({http.Client? client})
    : client = client ?? http.Client();

  Future<DetailedStatsModel> createDetailedStats({
    required String livreId,
    required double tauxConversion,
    required int nouveauxLecteurs,
    required double satisfaction,
    required double tempsLectureMoyen,
    required double lecteursReccurents,
    required double revenuParVue,
  }) async {
    final response = await client.post(
      Uri.parse(ApiRoutes.createDetailedStats),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'livre_id': livreId,
        'taux_conversion': tauxConversion,
        'nouveaux_lecteurs': nouveauxLecteurs,
        'satisfaction': satisfaction,
        'temps_lecture_moyen': tempsLectureMoyen,
        'lecteurs_recurrents': lecteursReccurents,
        'revenu_par_vue': revenuParVue,
      }),
    );

    if (response.statusCode == 201) {
      return DetailedStatsModel.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to create detailed statistics');
    }
  }

  Future<DetailedStatsModel> getDetailedStatsByBook(String livreId) async {
    final url = ApiRoutes.detailedStatsByBook.replaceFirst(
      ':livre_id',
      livreId,
    );
    final response = await client.get(Uri.parse(url));

    if (response.statusCode == 200) {
      return DetailedStatsModel.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to fetch detailed statistics for book');
    }
  }

  Future<DetailedStatsModel> updateDetailedStats({
    required String livreId,
    double? tauxConversion,
    int? nouveauxLecteurs,
    double? satisfaction,
    double? tempsLectureMoyen,
    double? lecteursReccurents,
    double? revenuParVue,
  }) async {
    final url = ApiRoutes.updateDetailedStats.replaceFirst(
      ':livre_id',
      livreId,
    );
    final body = <String, dynamic>{};
    if (tauxConversion != null) body['taux_conversion'] = tauxConversion;
    if (nouveauxLecteurs != null) body['nouveaux_lecteurs'] = nouveauxLecteurs;
    if (satisfaction != null) body['satisfaction'] = satisfaction;
    if (tempsLectureMoyen != null)
      body['temps_lecture_moyen'] = tempsLectureMoyen;
    if (lecteursReccurents != null)
      body['lecteurs_recurrents'] = lecteursReccurents;
    if (revenuParVue != null) body['revenu_par_vue'] = revenuParVue;

    final response = await client.put(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      return DetailedStatsModel.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to update detailed statistics');
    }
  }
}
