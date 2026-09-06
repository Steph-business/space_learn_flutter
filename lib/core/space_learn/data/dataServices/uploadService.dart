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
  extrait('extract'),

  /// Photo de profil.
  ///
  /// Seul type qui ne se rattache à aucun livre : il part sans `book_id`, et
  /// le serveur nomme l'objet d'après le compte lu dans le jeton.
  avatar('avatar');

  final String valeur;
  const TypeFichier(this.valeur);
}

/// Téléversement des fichiers d'un livre, et de la photo de profil.
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
    final corps = await _poster(
      authToken: authToken,
      type: type,
      champs: {'book_id': livreId, 'type': type.valeur},
      cheminFichier: cheminFichier,
      octets: octets,
      nomFichier: nomFichier,
      onProgress: onProgress,
    );

    final chemin = corps['path']?.toString();
    if (chemin == null || chemin.isEmpty) {
      throw Exception("Le serveur n'a pas retourné de chemin de fichier");
    }
    return chemin;
  }

  /// Envoie une photo de profil et retourne son adresse publique.
  ///
  /// Les trois écrans de réglages déposaient l'image eux-mêmes dans le seau
  /// « avatars » de Supabase. Pour cela l'application embarquait une clé de
  /// service — celle qui passe outre toutes les règles d'accès de la base — et
  /// un APK se décompile en une commande. La photo emprunte désormais la même
  /// route que les fichiers d'un livre : le serveur détient seul la clé.
  ///
  /// Aucun identifiant de compte n'accompagne l'envoi. Le serveur nomme
  /// l'objet d'après le compte lu dans le jeton : c'est ce qui garantit qu'une
  /// personne ne peut remplacer que sa propre photo, sans qu'aucun contrôle de
  /// propriété supplémentaire soit nécessaire.
  static Future<String> envoyerAvatar({
    required String authToken,
    String? cheminFichier,
    Uint8List? octets,
    String? nomFichier,
    void Function(double progression)? onProgress,
  }) async {
    final corps = await _poster(
      authToken: authToken,
      type: TypeFichier.avatar,
      // Pas de `book_id` : une photo de profil n'appartient à aucun livre.
      champs: {'type': TypeFichier.avatar.valeur},
      cheminFichier: cheminFichier,
      octets: octets,
      nomFichier: nomFichier,
      onProgress: onProgress,
    );

    // Une couverture rend un chemin relatif, que le serveur signe ensuite à la
    // demande ; une photo de profil rend directement une adresse publique,
    // parce qu'elle s'affiche partout — listes, commentaires, fiche auteur —
    // sans qu'on puisse signer chaque affichage.
    final url = corps['url']?.toString();
    if (url == null || url.isEmpty) {
      throw Exception("Le serveur n'a pas retourné l'adresse de la photo");
    }
    return url;
  }

  /// Le transport, commun à tous les types de fichiers.
  ///
  /// Extrait de [envoyer] pour que la photo de profil hérite sans copie du
  /// délai proportionné au poids, du suivi de progression, de l'interception
  /// des 401 et de la traduction des erreurs. Seuls les champs envoyés et la
  /// clé lue dans la réponse distinguent les deux usages.
  static Future<Map<String, dynamic>> _poster({
    required String authToken,
    required TypeFichier type,
    required Map<String, String> champs,
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

    // LE POIDS SE CONTRÔLE AVANT DE PARTIR, pour la photo de profil.
    //
    // Les trois écrans qui la choisissent bornent la définition de l'image
    // (`maxWidth`/`maxHeight` sur pickImage) : `imageQuality` seul ne fait que
    // réencoder, la photo garde sa définition d'origine et dépasse les 2 Mo du
    // serveur dès un capteur ordinaire. Ce contrôle-ci est la seconde ligne :
    // il rattrape ce qui passe malgré tout — une capture d'écran en PNG, une
    // plateforme où le sélecteur ignore ces bornes, un futur appelant qui les
    // oublierait — et il le rattrape SANS avoir consommé le forfait de la
    // personne pour un envoi que le serveur refusera en 413.
    //
    // Seule la photo est bornée ici. Les plafonds du manuscrit (100 Mo) et de
    // la couverture (10 Mo) sont larges et se règlent par variables
    // d'environnement : les recopier ici risquerait un refus que le serveur,
    // lui, n'aurait pas prononcé.
    if (type == TypeFichier.avatar && donnees.length > _plafondAvatar) {
      throw Exception(_tropLourdePourUnAvatar(donnees.length));
    }

    final nom =
        nomFichier ??
        (cheminFichier != null
            ? cheminFichier.split(RegExp(r'[/\\]')).last
            : 'fichier');

    final requete = http.MultipartRequest('POST', Uri.parse(_urlUpload))
      ..headers['Authorization'] = 'Bearer $authToken'
      ..fields.addAll(champs)
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
      throw Exception(_message(reponse, type));
    }

    return jsonDecode(reponse.body) as Map<String, dynamic>;
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

  /// Le poids que le serveur admet pour une photo de profil.
  ///
  /// Miroir de `tailleMaxAvatar` côté Go (2 Mo, réglable par
  /// `AVATAR_TAILLE_MAX_MO`). C'est le plus bas des trois plafonds, et le seul
  /// qu'une photo prise au téléphone dépasse couramment.
  ///
  /// SI CE PLAFOND EST RELEVÉ SUR LE SERVEUR, cette constante doit suivre :
  /// sinon l'application refuserait ici des photos que le serveur accepterait,
  /// et le refus serait incompréhensible puisqu'il ne viendrait de personne.
  static const int _plafondAvatar = 2 * 1024 * 1024;

  /// Le refus dit avec le poids réel et la limite, comme le fait le serveur.
  ///
  /// « Image trop volumineuse » n'apprend rien : la personne ne sait ni de
  /// combien elle dépasse, ni ce qu'elle doit faire. Le texte traverse
  /// `messageLisible` intact — ni accolade, ni jargon, ni nom de classe.
  static String _tropLourdePourUnAvatar(int octets) {
    final mo = (octets / (1024 * 1024)).toStringAsFixed(1).replaceAll('.', ',');
    final limite = _plafondAvatar ~/ (1024 * 1024);
    return "Cette photo pèse $mo Mo ; la limite est de $limite Mo. "
        "Choisissez une image moins lourde.";
  }

  /// Ce que lit qui change sa photo sur un serveur pas encore redéployé.
  static const String _photoIndisponible =
      "L'envoi de la photo n'est pas disponible sur ce serveur. "
      "Il doit être mis à jour.";

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

  static String _message(http.Response reponse, TypeFichier type) {
    // Les replis parlent du livre : ils n'ont aucun sens pour une photo de
    // profil, qui n'a ni auteur à vérifier ni livre à trouver.
    final estAvatar = type == TypeFichier.avatar;

    String? duServeur;
    try {
      final corps = jsonDecode(reponse.body) as Map<String, dynamic>;
      final message = corps['error'] ?? corps['message'];
      if (message is String && message.isNotEmpty) duServeur = message;
    } catch (_) {}

    // LE SERVEUR PAS ENCORE REDÉPLOYÉ NE RÉPOND PAS 404.
    //
    // La route /upload existe depuis toujours : un serveur d'avant la photo de
    // profil la sert, mais il ne connaît pas le type « avatar ». Il refuse donc
    // en 400, et son message — « book_id requis », ou « type invalide » — est
    // prioritaire ci-dessous : la personne venue changer sa photo lisait
    // « Book_id requis. », et le repli du 404, lui, ne s'affichait jamais.
    //
    // Le test porte sur la SIGNATURE de ce refus, pas sur le seul code 400 :
    // le serveur à jour répond aussi 400 pour dire « la photo doit être une
    // image JPEG, PNG, WebP ou GIF », et cette phrase-là est utile — l'avaler
    // avec le reste remplacerait un bon message par un mauvais.
    if (estAvatar &&
        reponse.statusCode == 400 &&
        _refusDUnServeurAncien(duServeur)) {
      return _photoIndisponible;
    }

    if (duServeur != null) return duServeur;

    return switch (reponse.statusCode) {
      401 => 'Session expirée, reconnectez-vous',
      403 when estAvatar => "Vous n'avez pas accès à cette fonction",
      403 => "Vous n'êtes pas l'auteur de ce livre",
      404 when estAvatar => _photoIndisponible,
      404 => 'Livre introuvable',
      413 when estAvatar => 'Image trop volumineuse',
      413 => 'Fichier trop volumineux',
      _ when estAvatar =>
        "Échec de l'envoi de la photo (${reponse.statusCode})",
      _ => "Échec de l'envoi du fichier (${reponse.statusCode})",
    };
  }

  /// Ce refus vient-il d'un serveur qui ignore la photo de profil ?
  ///
  /// Deux phrases le trahissent, et elles sont les seules : « book_id requis »
  /// — l'ancien gestionnaire réclamait le livre avant même de lire le type —
  /// et « type invalide », si sa validation du type précédait la nôtre. Aucune
  /// des deux ne peut sortir du serveur à jour pour un avatar : il saute
  /// entièrement la partie « livre » et accepte ce type.
  static bool _refusDUnServeurAncien(String? messageDuServeur) {
    if (messageDuServeur == null) return false;
    final m = messageDuServeur.toLowerCase();
    return m.contains('book_id') || m.contains('type invalide');
  }
}
