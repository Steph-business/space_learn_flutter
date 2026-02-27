import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../utils/api_routes.dart';
import '../../../utils/token_storage.dart';
import '../model/badgeModel.dart';
import '../model/goalModel.dart';

class BadgeService {
  final http.Client client;

  BadgeService({http.Client? client}) : client = client ?? http.Client();

  Future<List<BadgeModel>> getUserBadges() async {
    try {
      final token = await TokenStorage.getToken();
      final headers = <String, String>{'Content-Type': 'application/json'};
      if (token != null) headers['Authorization'] = 'Bearer $token';

      final uri = Uri.parse(ApiRoutes.gamificationBadges);
      print("▶️ GET BADGES: $uri");

      final response = await client.get(uri, headers: headers);
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final List<dynamic> data = responseData['data'] ?? responseData;
        return data.map((json) => BadgeModel.fromJson(json)).toList();
      }
      return _getMockBadges();
    } catch (e) {
      print("❌ Error fetching badges: $e");
      return _getMockBadges();
    }
  }

  Future<List<GoalModel>> getGoals() async {
    try {
      final token = await TokenStorage.getToken();
      final headers = <String, String>{'Content-Type': 'application/json'};
      if (token != null) headers['Authorization'] = 'Bearer $token';

      final uri = Uri.parse(ApiRoutes.gamificationGoals);
      print("▶️ GET GOALS: $uri");

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
      print("❌ Error fetching goals: $e");
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
        id: '1',
        utilisateurId: 'me',
        debloqueLe: DateTime.now(),
        name: 'Expert du premier tome',
        description: 'A terminé son tout premier livre !',
        iconUrl:
            'https://uqmydsydlkwxcfcdtsbu.supabase.co/storage/v1/object/public/badges/badge_1.png',
        code: 'FIRST_BOOK',
      ),
    ];
  }
}
