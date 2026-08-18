import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/api_client.dart';
import '../../../utils/api_routes.dart';
import '../../../utils/token_storage.dart';
import '../model/badgeModel.dart';
import '../model/goalModel.dart';

class BadgeService {
  final http.Client client;

  BadgeService({http.Client? client}) : client = client ?? ApiClient.instance;

  static const String _cleCache = 'badges_cache';

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
        final badges = data.map((json) => BadgeModel.fromJson(json)).toList();
        await _memoriser(response.body);
        return badges;
      }
      return _dernierEtatConnu();
    } catch (e) {
      return _dernierEtatConnu();
    }
  }

  /// Le dernier catalogue reçu du serveur, gardé pour les moments hors ligne.
  ///
  /// Une liste de badges inventés tenait ce rôle : six trophées aux noms et aux
  /// seuils choisis ici, qui ne correspondaient à aucune règle du serveur —
  /// « Lecteur du Jour », « Grand Marathonien ». C'était un second catalogue,
  /// condamné à diverger du vrai dès la première règle ajoutée, et le lecteur
  /// hors ligne y voyait des badges qui n'existaient pas.
  ///
  /// Mieux vaut lui montrer sa propre collection, telle qu'il l'a vue la
  /// dernière fois.
  Future<List<BadgeModel>> _dernierEtatConnu() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final brut = prefs.getString(_cleCache);
      if (brut == null) return [];

      final Map<String, dynamic> decode = jsonDecode(brut);
      final List<dynamic> data = decode['data'] ?? [];
      return data.map((json) => BadgeModel.fromJson(json)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _memoriser(String corps) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cleCache, corps);
    } catch (_) {
      // Un cache qui ne s'écrit pas ne doit pas faire échouer l'affichage.
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
}
