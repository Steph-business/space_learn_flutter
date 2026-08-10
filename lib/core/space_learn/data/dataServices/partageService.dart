import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';

import '../../../services/api_client.dart';
import '../../../utils/api_routes.dart';

/// Partage d'un livre en recommandation.
///
/// Point unique d'entrée : deux implémentations divergentes coexistaient,
/// l'une construisant un texte local sans aucun lien — le destinataire devait
/// deviner qu'il fallait installer une application et y chercher le livre —,
/// l'autre appelant le serveur. Le message de recommandation est désormais
/// toujours composé côté serveur, avec l'argumentaire de l'auteur et le lien.
class PartageService {
  final http.Client client;

  PartageService({http.Client? client}) : client = client ?? ApiClient.instance;

  /// Récupère le message de recommandation préparé par le serveur.
  Future<DonneesPartage?> getDonnees(String livreId) async {
    try {
      final uri = Uri.parse(ApiRoutes.shareBook.replaceFirst(':id', livreId));
      final reponse = await client.get(uri);
      if (reponse.statusCode != 200) {
        debugPrint('PartageService: ${reponse.statusCode} — ${reponse.body}');
        return null;
      }

      final data = (jsonDecode(reponse.body) as Map<String, dynamic>)['data'];
      if (data is! Map<String, dynamic>) return null;
      return DonneesPartage.fromJson(data);
    } catch (e) {
      debugPrint('PartageService: $e');
      return null;
    }
  }

  /// Ouvre la feuille de partage du système.
  ///
  /// [origine] doit être fourni sur iPad et macOS, où la feuille de partage
  /// s'ancre à l'élément qui l'a déclenchée ; sans elle, l'appel échoue.
  Future<void> partagerLivre({
    required String livreId,
    required String titreDeSecours,
    Rect? origine,
  }) async {
    final donnees = await getDonnees(livreId);

    // Repli si le serveur est injoignable : mieux vaut un partage sans lien
    // qu'un bouton qui ne fait rien.
    final texte =
        donnees?.texteDePartage ??
        "Je te recommande « $titreDeSecours » sur Space Learn.";
    final sujet = donnees?.titre ?? titreDeSecours;

    await SharePlus.instance.share(
      ShareParams(
        text: texte,
        subject: 'Recommandation : $sujet',
        sharePositionOrigin: origine,
      ),
    );
  }
}

/// Message de recommandation composé par le serveur.
class DonneesPartage {
  final String titre;
  final String auteur;
  final String description;
  final String image;

  /// Message complet : titre, argumentaire de l'auteur, prix, appel à
  /// l'action et lien.
  final String texteDePartage;

  /// Lien public du livre. Vide si le serveur n'a pas d'adresse publique
  /// configurée — il ne fabrique alors pas de lien mort.
  final String lien;

  const DonneesPartage({
    required this.titre,
    required this.auteur,
    required this.description,
    required this.image,
    required this.texteDePartage,
    required this.lien,
  });

  factory DonneesPartage.fromJson(Map<String, dynamic> json) => DonneesPartage(
    titre: json['title']?.toString() ?? '',
    auteur: json['author']?.toString() ?? '',
    description: json['description']?.toString() ?? '',
    image: json['image']?.toString() ?? '',
    texteDePartage: json['share_text']?.toString() ?? '',
    lien: json['share_url']?.toString() ?? '',
  );
}
