import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../services/api_client.dart';
import '../../../utils/api_routes.dart';
import '../../../utils/token_storage.dart';
import '../model/badgeModel.dart';
import '../model/goalModel.dart';

class BadgeService {
  final http.Client client;

  BadgeService({http.Client? client}) : client = client ?? ApiClient.instance;

  Future<List<BadgeModel>> getUserBadges() async {
    try {
      final token = await TokenStorage.getToken();
      final headers = <String, String>{'Content-Type': 'application/json'};
      if (token != null) headers['Authorization'] = 'Bearer $token';

      final uri = Uri.parse(ApiRoutes.gamificationBadges);
      final response = await client.get(uri, headers: headers);
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final List<dynamic> data = responseData['data'] ?? responseData;
        return data.map((json) => BadgeModel.fromJson(json)).toList();
      }
      return _getMockBadges();
    } catch (e) {
      return _getMockBadges();
    }
  }

  Future<List<GoalModel>> getGoals() async {
    try {
      final token = await TokenStorage.getToken();
      final headers = <String, String>{'Content-Type': 'application/json'};
      if (token != null) headers['Authorization'] = 'Bearer $token';

      final uri = Uri.parse(ApiRoutes.gamificationGoals);
      final response = await client.get(uri, headers: headers);
      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        final List<dynamic> data = (decoded is Map)
            ? (decoded['data'] ?? [])
            : decoded;
        return data.map((json) => GoalModel.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<bool> updateGoalValue(String goalId, int increment) async {
    try {
      final token = await TokenStorage.getToken();
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final uri = Uri.parse(ApiRoutes.updateGoal.replaceFirst(':id', goalId));
      final response = await client.put(
        uri,
        headers: headers,
        body: jsonEncode({'valeur_ajoutee': increment}),
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  List<BadgeModel> _getMockBadges() {
    return [
      BadgeModel(
        id: 'badge_first_page',
        utilisateurId: 'me',
        debloqueLe: DateTime.now(),
        name: 'Premier Pas',
        description: 'A commencé sa toute première lecture.',
        iconUrl: 'auto_stories',
        code: 'FIRST_STEP',
      ),
      BadgeModel(
        id: 'badge_first_book',
        utilisateurId: 'me',
        debloqueLe: null,
        name: 'Expert du Premier Tome',
        description: 'A terminé son tout premier livre à 100%.',
        iconUrl: 'stars',
        code: 'FIRST_BOOK',
      ),
      BadgeModel(
        id: 'badge_daily_reader',
        utilisateurId: 'me',
        debloqueLe: null,
        name: 'Lecteur du Jour',
        description: 'A lu 15 minutes dans la même journée.',
        iconUrl: 'timer',
        code: 'DAILY_15MIN',
      ),
      BadgeModel(
        id: 'badge_bibliophile',
        utilisateurId: 'me',
        debloqueLe: null,
        name: 'Bibliophile',
        description: 'A rassemblé au moins 2 livres dans sa bibliothèque.',
        iconUrl: 'inventory_2',
        code: 'COLLECTION_2',
      ),
      BadgeModel(
        id: 'badge_critic',
        utilisateurId: 'me',
        debloqueLe: null,
        name: 'Critique Littéraire',
        description: 'A publié son premier avis ou notation de lecture.',
        iconUrl: 'rate_review',
        code: 'FIRST_REVIEW',
      ),
      BadgeModel(
        id: 'badge_marathon',
        utilisateurId: 'me',
        debloqueLe: null,
        name: 'Grand Marathonien',
        description: 'A cumulé plus de 60 minutes de temps de lecture.',
        iconUrl: 'stars',
        code: 'READ_60MIN',
      ),
    ];
  }
}
