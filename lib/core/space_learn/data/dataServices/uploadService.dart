import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../utils/api_routes.dart';
import 'package:space_learn_flutter/core/services/api_client.dart';

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

    final abonnement = flux.listen(
      envoi.sink.add,
      onDone: envoi.sink.close,
      onError: envoi.sink.addError,
      cancelOnError: true,
    );

    // envoi.send() instancie son propre client : la requete ne traverserait
    // pas l'intercepteur, et un 401 sur le depot d'un manuscrit ne purgerait
    // jamais la session.
    //
    // Le délai est posé ICI et pas dans ApiClient : l'intercepteur écarte
    // délibérément les StreamedRequest de son délai de 30 s (voir
    // ApiClient.estBornee), parce qu'un manuscrit met légitimement plus
    // longtemps que ça. Résultat : le téléversement était la seule requête de
    // l'application sans aucune borne. Sur un réseau qui se dégrade sans se
    // couper — la sortie d'une zone de couverture, un partage de connexion qui
    // sature — rien ne lève jamais : l'auteur regarde une roue qui tourne
    // indéfiniment, sans message et sans recours.
    final http.StreamedResponse reponseFlux;
    try {
      reponseFlux = await ApiClient.instance
          .send(envoi)
          .timeout(_budget(donnees.length));
    } on TimeoutException {
      // Le délai n'interrompt pas l'envoi tout seul : sans ce coup d'arrêt, le
      // corps continuerait de partir dans le vide et la connexion resterait
      // ouverte jusqu'à ce que le système la ferme, en consommant les données
      // mobiles de l'auteur pour un envoi déjà abandonné.
      await abonnement.cancel();
      _interrompre(envoi);
      throw Exception(_messageExpiration);
    }

    // Le corps de la RÉPONSE se borne aussi. Un serveur qui envoie ses
    // en-têtes puis se tait — ce que fait un portail captif — laisserait
    // sinon l'attente repartir pour l'infini, juste après l'avoir bornée.
    final http.Response reponse;
    try {
      reponse = await http.Response.fromStream(
        reponseFlux,
      ).timeout(ApiClient.delaiRequete);
    } on TimeoutException {
      throw Exception(_messageExpiration);
    }

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

  /// Ce que lit l'auteur quand l'envoi n'aboutit pas dans le temps imparti.
  ///
  /// La phrase est portée par le service, et non laissée à `messageLisible` :
  /// sa formule pour un `TimeoutException` — « Le serveur a mis trop de temps
  /// à répondre » — accuse le serveur, alors que c'est le lien qui a lâché
  /// pendant que le fichier montait, et surtout elle ne dit pas le seul fait
  /// qui compte pour l'auteur : le fichier n'est PAS parti, il faut
  /// recommencer. Le texte traverse `messageLisible` intact (pas de jargon, ni
  /// d'accolade, ni de nom de classe) et s'affiche tel quel.
  static const String _messageExpiration =
      "L'envoi a été interrompu : votre connexion est trop lente ou instable. "
      "Réessayez.";

  /// Le temps qu'un envoi a le droit de prendre, selon le poids du fichier.
  ///
  /// Un délai fixe ne pouvait pas convenir : une couverture de 300 Ko et un
  /// manuscrit — que le serveur accepte jusqu'à 100 Mo — ne se mesurent pas à
  /// la même aune. Trop court, il amputerait un envoi parfaitement sain et
  /// l'auteur ne pourrait JAMAIS publier son livre ; trop long, il ne
  /// protégerait de rien.
  ///
  /// D'où une minute de base — le temps d'établir la connexion et de laisser
  /// le serveur écrire dans le stockage — plus douze secondes par mégaoctet,
  /// ce qui suppose un débit montant très modeste (~85 Ko/s). Une couverture
  /// tient donc dans la minute et un manuscrit courant dans les deux ; le
  /// plafond de quinze minutes borne le cas extrême sans le condamner.
  static Duration _budget(int octets) {
    final megaoctets = octets / (1024 * 1024);
    final secondes = 60 + (megaoctets * 12).round();
    return Duration(seconds: secondes.clamp(60, 900));
  }

  /// Coupe court à un envoi abandonné.
  ///
  /// Fermer proprement enverrait un corps tronqué que le serveur prendrait
  /// pour un fichier valide : on signale une erreur, ce qui fait avorter la
  /// requête. Le tout sous `try` car le flux peut avoir déjà rendu ses
  /// derniers octets — le puits est alors clos et refuserait l'écriture.
  static void _interrompre(http.StreamedRequest envoi) {
    try {
      envoi.sink.addError(
        TimeoutException("Téléversement abandonné : délai dépassé"),
      );
      envoi.sink.close();
    } catch (_) {
      // Déjà fermé : il n'y a plus rien à interrompre.
    }
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
