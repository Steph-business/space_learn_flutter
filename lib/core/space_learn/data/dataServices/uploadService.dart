import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../utils/api_routes.dart';

/// Nature du fichier envoyé, telle que l'attend le serveur.
enum TypeFichier {
  /// Image de couverture.
  couverture('image'),

  /// Manuscrit complet, réservé aux acheteurs.
  manuscrit('file'),

  /// Extrait librement consultable.
  extrait('extract');

  final String valeur;
  const TypeFichier(this.valeur);
}

/// Téléversement des fichiers d'un livre.
///
/// Tout passe par le backend, jamais directement par Supabase. L'application
/// envoyait auparavant les fichiers avec la clé publique `anon` et forçait le
/// bucket en accès public à chaque envoi : les manuscrits étaient alors
/// téléchargeables par quiconque connaissait leur adresse, et n'importe qui
/// pouvait déposer des fichiers dans le stockage.
///
/// Le serveur détient seul la clé de service, vérifie que l'appelant est bien
/// l'auteur du livre, et enregistre un chemin relatif — c'est ce qui permet de
/// ne délivrer ensuite que des URL signées à durée limitée.
class UploadService {
  // Déclarée ici plutôt que dans ApiRoutes pour ne pas toucher un fichier en
  // cours de modification ; à déplacer dans ApiRoutes à l'occasion.
  static String get _urlUpload => '${ApiRoutes.baseUrlsGin}/upload';

  /// Envoie un fichier et retourne le chemin enregistré côté stockage.
  ///
  /// [onProgress] reçoit une valeur entre 0 et 1. Sans elle, l'auteur qui
  /// publie un manuscrit de 20 Mo sur un réseau lent n'a aucun signe de vie
  /// pendant plusieurs minutes et croit l'application bloquée.
  static Future<String> envoyer({
    required String authToken,
    required String livreId,
    required TypeFichier type,
    String? cheminFichier,
    Uint8List? octets,
    String? nomFichier,
    void Function(double progression)? onProgress,
  }) async {
    assert(
      cheminFichier != null || octets != null,
      'Fournir un chemin de fichier ou des octets',
    );

    final donnees = octets ?? await File(cheminFichier!).readAsBytes();
    final nom =
        nomFichier ??
        (cheminFichier != null
            ? cheminFichier.split(RegExp(r'[/\\]')).last
            : 'fichier');

    final requete = http.MultipartRequest('POST', Uri.parse(_urlUpload))
      ..headers['Authorization'] = 'Bearer $authToken'
      ..fields['book_id'] = livreId
      ..fields['type'] = type.valeur
      ..files.add(http.MultipartFile.fromBytes('file', donnees, filename: nom));

    // MultipartRequest n'expose pas de progression : on enveloppe son flux
    // pour compter les octets réellement transmis.
    final flux = _fluxSuivi(
      requete.finalize(),
      requete.contentLength,
      onProgress,
    );
    final envoi = http.StreamedRequest('POST', requete.url)
      ..headers.addAll(requete.headers)
      ..contentLength = requete.contentLength;

    flux.listen(
      envoi.sink.add,
      onDone: envoi.sink.close,
      onError: envoi.sink.addError,
      cancelOnError: true,
    );

    final reponseFlux = await envoi.send();
    final reponse = await http.Response.fromStream(reponseFlux);

    if (reponse.statusCode != 200) {
      throw Exception(_message(reponse));
    }

    final corps = jsonDecode(reponse.body) as Map<String, dynamic>;
    final chemin = corps['path']?.toString();
    if (chemin == null || chemin.isEmpty) {
      throw Exception("Le serveur n'a pas retourné de chemin de fichier");
    }
    return chemin;
  }

  static Stream<List<int>> _fluxSuivi(
    Stream<List<int>> source,
    int total,
    void Function(double)? onProgress,
  ) async* {
    var envoyes = 0;
    await for (final morceau in source) {
      envoyes += morceau.length;
      if (onProgress != null && total > 0) {
        onProgress((envoyes / total).clamp(0.0, 1.0));
      }
      yield morceau;
    }
  }

  static String _message(http.Response reponse) {
    try {
      final corps = jsonDecode(reponse.body) as Map<String, dynamic>;
      final message = corps['error'] ?? corps['message'];
      if (message is String && message.isNotEmpty) return message;
    } catch (_) {}

    return switch (reponse.statusCode) {
      401 => 'Session expirée, reconnectez-vous',
      403 => "Vous n'êtes pas l'auteur de ce livre",
      404 => 'Livre introuvable',
      413 => 'Fichier trop volumineux',
      _ => "Échec de l'envoi du fichier (${reponse.statusCode})",
    };
  }
}
