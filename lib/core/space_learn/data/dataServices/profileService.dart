import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;

import 'package:space_learn_flutter/core/space_learn/data/model/profilModel.dart';
import 'package:space_learn_flutter/core/utils/api_routes.dart';
import 'package:space_learn_flutter/core/utils/profileStorage.dart';

class ProfileService {
  /// ✅ Récupérer les profils disponibles (Lecteur, Auteur, etc.)
  Future<List<ProfilModel>> getProfils() async {
    final response = await http.get(Uri.parse(ApiRoutes.profils));
    developer.log('ProfileService.getProfils: status ${response.statusCode}', name: 'ProfileService');
    developer.log('ProfileService.getProfils: body ${response.body}', name: 'ProfileService');

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = jsonDecode(response.body);
      // The backend returns {"profils": [...]}, so we need to extract the list.
      if (responseData.containsKey('profils') &&
          responseData['profils'] is List) {
        final List<dynamic> data = responseData['profils'];
        return data.map((json) => ProfilModel.fromJson(json)).toList();
      } else {
        throw Exception(
          "Erreur: Le format de la réponse de l'API pour les profils est incorrect.",
        );
      }
    } else {
      // Gérer les erreurs (ex: 404, 500)
      throw Exception(
        "Impossible de charger les profils. Code: ${response.statusCode}",
      );
    }
  }

  /// Sauvegarder le profil sélectionné localement
  Future<void> saveSelectedProfile(String profileId) async {
    await ProfileStorage.saveSelectedProfile(profileId);
  }

  /// Récupérer le profil sélectionné localement
  Future<String?> getSelectedProfile() async {
    return await ProfileStorage.getSelectedProfile();
  }

  /// Effacer le profil sélectionné localement
  Future<void> clearSelectedProfile() async {
    await ProfileStorage.clearSelectedProfile();
  }
}
