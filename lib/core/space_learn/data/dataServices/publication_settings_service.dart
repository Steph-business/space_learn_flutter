import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../services/api_client.dart';
import '../../../utils/api_routes.dart';

/// Les préférences de publication d'un auteur, telles que le serveur les tient.
///
/// Elles vivaient dans les préférences du téléphone : changer d'appareil,
/// réinstaller l'application ou se connecter ailleurs les perdait, alors
/// qu'elles décrivent une intention d'auteur et non un confort d'affichage.
class ParametresPublication {
  const ParametresPublication({
    required this.visibiliteParDefaut,
    required this.licenceParDefaut,
    required this.deviseParDefaut,
    required this.partAuteurPourcent,
    required this.commissionPourcent,
    required this.prixConseilleMin,
    required this.prixConseilleMax,
  });

  final bool visibiliteParDefaut;
  final String licenceParDefaut;
  final String deviseParDefaut;

  /// Ce que l'auteur touche réellement sur chaque vente.
  ///
  /// Calculé par le serveur, jamais envoyé par l'application. L'écran offrait
  /// auparavant un champ libre « Part de l'auteur (%) » : on pouvait y saisir
  /// 95 et lire « enregistré ! », sans que cela change quoi que ce soit au
  /// versement.
  final double partAuteurPourcent;
  final double commissionPourcent;

  /// Fourchette conseillée, en francs CFA. Un repérage, pas une limite :
  /// l'auteur reste libre de son prix.
  final double prixConseilleMin;
  final double prixConseilleMax;

  /// Ce que l'auteur perçoit sur une vente à [prix].
  double gainPour(double prix) => prix * partAuteurPourcent / 100;

  bool dansLaFourchette(double prix) =>
      prix >= prixConseilleMin && prix <= prixConseilleMax;

  factory ParametresPublication.fromJson(Map<String, dynamic> json) {
    double nombre(dynamic v, double defaut) {
      if (v is num) return v.toDouble();
      return double.tryParse('${v ?? ''}') ?? defaut;
    }

    return ParametresPublication(
      visibiliteParDefaut: json['visibilite_par_defaut'] != false,
      licenceParDefaut:
          (json['licence_par_defaut'] as String?)?.trim().isNotEmpty == true
          ? json['licence_par_defaut'] as String
          : 'Tous droits réservés',
      deviseParDefaut:
          (json['devise_par_defaut'] as String?)?.trim().isNotEmpty == true
          ? json['devise_par_defaut'] as String
          : 'FCFA',
      partAuteurPourcent: nombre(json['part_auteur_pourcent'], 80),
      commissionPourcent: nombre(json['commission_pourcent'], 20),
      prixConseilleMin: nombre(json['prix_conseille_min'], 1000),
      prixConseilleMax: nombre(json['prix_conseille_max'], 5000),
    );
  }
}

class PublicationSettingsService {
  PublicationSettingsService({http.Client? client})
    : client = client ?? ApiClient.instance;

  final http.Client client;

  Future<ParametresPublication> lire(String authToken) async {
    final reponse = await client.get(
      Uri.parse(ApiRoutes.publicationSettings),
      headers: {'Authorization': 'Bearer $authToken'},
    );
    return _lireReponse(reponse, "Impossible de charger vos préférences.");
  }

  /// Enregistre les trois choix de l'auteur.
  ///
  /// Ni la part ni la commission ne sont envoyées : le serveur les refuserait
  /// en entrée, et c'est bien ainsi — un client modifié pourrait sinon
  /// s'attribuer un taux.
  Future<ParametresPublication> enregistrer(
    String authToken, {
    required bool visibiliteParDefaut,
    required String licenceParDefaut,
    required String deviseParDefaut,
  }) async {
    final reponse = await client.put(
      Uri.parse(ApiRoutes.publicationSettings),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $authToken',
      },
      body: jsonEncode({
        'visibilite_par_defaut': visibiliteParDefaut,
        'licence_par_defaut': licenceParDefaut,
        'devise_par_defaut': deviseParDefaut,
      }),
    );
    return _lireReponse(reponse, "Impossible d'enregistrer vos préférences.");
  }

  ParametresPublication _lireReponse(http.Response reponse, String repli) {
    if (reponse.statusCode == 200) {
      final corps = jsonDecode(reponse.body);
      final donnees = (corps is Map && corps['data'] is Map)
          ? corps['data']
          : corps;
      return ParametresPublication.fromJson(
        Map<String, dynamic>.from(donnees as Map),
      );
    }

    String message = repli;
    try {
      final corps = jsonDecode(reponse.body);
      if (corps is Map) {
        final m = corps['error'] ?? corps['message'];
        if (m is String && m.trim().isNotEmpty) message = m;
      }
    } catch (_) {}
    throw Exception(message);
  }
}
