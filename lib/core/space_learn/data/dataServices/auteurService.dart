import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../services/api_client.dart';
import '../../../utils/api_routes.dart';
import '../../../utils/message_erreur.dart';

/// Un auteur, tel que le serveur le résume.
///
/// L'écran « Tous les auteurs » fabriquait ces informations lui-même, à partir
/// des livres qu'il avait chargés — deux cents au plus. Le décompte ne comptait
/// donc que les livres reçus : un auteur prolifique en affichait moins qu'il
/// n'en a, et un auteur dont aucun livre n'était dans la page portait « 0 livre
/// publié » sous son nom.
///
/// Ces chiffres viennent maintenant de la base, où toutes les lignes sont
/// visibles.
class AuteurResume {
  const AuteurResume({
    required this.id,
    required this.nomComplet,
    this.photo,
    this.biographie,
    this.nombreLivres = 0,
    this.specialite,
    this.estSuivi = false,
  });

  final String id;
  final String nomComplet;
  final String? photo;
  final String? biographie;

  /// Le vrai total des livres publiés, toutes pages confondues.
  final int nombreLivres;

  /// La catégorie dans laquelle l'auteur publie le plus.
  final String? specialite;

  /// Renseigné par le serveur quand la requête porte un jeton.
  ///
  /// Évite de rapatrier la liste entière des abonnements du lecteur pour
  /// cocher quelques cases — une liste qui grandit avec le nombre d'auteurs
  /// suivis, et qu'aucun écran n'a besoin de connaître en entier.
  final bool estSuivi;

  factory AuteurResume.fromJson(Map<String, dynamic> json) {
    String? nonVide(dynamic v) {
      final s = v?.toString().trim();
      return (s == null || s.isEmpty) ? null : s;
    }

    return AuteurResume(
      id: json['id']?.toString() ?? '',
      nomComplet: json['nom_complet']?.toString().trim() ?? '',
      photo: nonVide(json['profile_photo']),
      biographie: nonVide(json['biographie']),
      nombreLivres: (json['nombre_livres'] as num?)?.toInt() ?? 0,
      specialite: nonVide(json['specialite']),
      estSuivi: json['est_suivi'] == true,
    );
  }

  AuteurResume copyWith({bool? estSuivi}) => AuteurResume(
    id: id,
    nomComplet: nomComplet,
    photo: photo,
    biographie: biographie,
    nombreLivres: nombreLivres,
    specialite: specialite,
    estSuivi: estSuivi ?? this.estSuivi,
  );

  /// L'initiale du cercle, quand il n'y a pas de photo.
  ///
  /// Un nom vide ne doit pas faire tomber la liste : `substring(0, 1)` levait
  /// sur une chaîne vide, et un seul profil incomplet suffisait à faire
  /// disparaître l'écran entier.
  String get initiale =>
      nomComplet.isEmpty ? '?' : nomComplet.substring(0, 1).toUpperCase();
}

class AuteurService {
  AuteurService({http.Client? client}) : client = client ?? ApiClient.instance;

  final http.Client client;

  /// Taille d'une page, alignée sur le plafond du serveur (`utils.LimiteMax`).
  static const int taillePage = 20;

  /// Une page de l'annuaire, du plus prolifique au moins.
  ///
  /// [recherche] est appliquée par le serveur. En dessous de deux caractères
  /// elle est ignorée — une lettre seule ne restreint rien et lui coûte un
  /// parcours complet.
  Future<List<AuteurResume>> getAuteurs({
    int page = 1,
    int limit = taillePage,
    String? recherche,
    String? authToken,
  }) async {
    final parametres = <String, String>{'page': '$page', 'limit': '$limit'};
    if (recherche != null && recherche.trim().length >= 2) {
      parametres['q'] = recherche.trim();
    }

    final uri = Uri.parse(ApiRoutes.auteurs).replace(queryParameters: parametres);

    final entetes = <String, String>{};
    if (authToken != null && authToken.isNotEmpty) {
      entetes['Authorization'] = 'Bearer $authToken';
    }

    final reponse = await client.get(uri, headers: entetes.isEmpty ? null : entetes);

    if (reponse.statusCode == 200) {
      final corps = jsonDecode(reponse.body);
      final List<dynamic> data = (corps is Map ? corps['data'] : null) ?? [];
      return data
          .whereType<Map<String, dynamic>>()
          .map(AuteurResume.fromJson)
          .toList();
    }

    // Une liste vide et un serveur qui refuse ne se ressemblent pas : lever
    // laisse l'écran dire ce qui s'est passé, au lieu d'afficher « aucun
    // auteur » sur un 429 ou un 500.
    debugPrint('Annuaire des auteurs : HTTP ${reponse.statusCode} sur $uri');
    throw Exception(
      messageDeLaReponse(reponse, repli: "Les auteurs n'ont pas pu être chargés."),
    );
  }
}
