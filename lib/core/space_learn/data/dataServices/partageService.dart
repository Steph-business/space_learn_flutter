import 'dart:convert';
import 'dart:io';

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

    // Couverture jointe au partage quand le serveur en fournit une : la
    // plateforme n'a pas encore de lien https public, donc les messageries
    // (WhatsApp…) ne peuvent pas construire d'aperçu riche — joindre l'image
    // est le seul moyen d'avoir la couverture dans le message aujourd'hui.
    // Dans WhatsApp, l'image devient le message et le texte sa légende.
    // Hiérarchie : « texte toujours, image quand on peut » — tout échec du
    // chemin image retombe sans bruit sur le partage texte, une couverture
    // manquante ne doit jamais empêcher une recommandation de partir.
    final urlImage = donnees?.image ?? '';
    if (urlImage.isNotEmpty) {
      final couverture = await _telechargerCouverture(urlImage, livreId);
      if (couverture != null) {
        await SharePlus.instance.share(
          ShareParams(
            files: [couverture],
            text: texte,
            subject: 'Recommandation : $sujet',
            sharePositionOrigin: origine,
          ),
        );
        return;
      }
    }

    await SharePlus.instance.share(
      ShareParams(
        text: texte,
        subject: 'Recommandation : $sujet',
        sharePositionOrigin: origine,
      ),
    );
  }

  /// Taille au-delà de laquelle on renonce à la couverture : une vraie
  /// couverture ne pèse pas 5 Mo, et un fichier aberrant ne doit pas
  /// bloquer la feuille de partage le temps de l'écrire et de l'envoyer.
  static const int _tailleMaxCouverture = 5 * 1024 * 1024;

  /// Télécharge la couverture dans un fichier temporaire jetable.
  ///
  /// Retourne null au moindre problème — téléchargement raté, statut ≠ 200,
  /// corps vide ou démesuré, écriture impossible — pour que l'appelant
  /// retombe sur le partage texte. `Directory.systemTemp` suffit pour un
  /// fichier jetable, pas besoin de path_provider.
  Future<XFile?> _telechargerCouverture(String url, String livreId) async {
    try {
      final reponse = await client.get(Uri.parse(url));
      if (reponse.statusCode != 200) return null;

      final octets = reponse.bodyBytes;
      if (octets.isEmpty || octets.length > _tailleMaxCouverture) return null;

      // Nom construit sur l'identifiant du livre et l'extension déduite du
      // Content-Type (jpg par défaut) : la feuille de partage affiche le nom
      // du fichier, autant qu'il soit propre.
      final typeContenu = (reponse.headers['content-type'] ?? '')
          .split(';')
          .first
          .trim()
          .toLowerCase();
      final extension =
          const {
            'image/png': 'png',
            'image/webp': 'webp',
            'image/gif': 'gif',
          }[typeContenu] ??
          'jpg';
      final nom = livreId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
      final fichier = File(
        '${Directory.systemTemp.path}${Platform.pathSeparator}'
        'couverture_$nom.$extension',
      );
      await fichier.writeAsBytes(octets, flush: true);

      return XFile(
        fichier.path,
        mimeType: typeContenu.isEmpty ? null : typeContenu,
      );
    } catch (e) {
      // Silencieux côté utilisateur : on trace pour le débogage et on laisse
      // partir la recommandation en texte seul.
      debugPrint('PartageService: couverture ignorée — $e');
      return null;
    }
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
