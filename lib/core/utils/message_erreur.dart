import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Traduire une panne en phrase lisible.
///
/// Une personne a vu ceci, en plein écran d'accueil :
///
///     Erreur lors du chargement des données: Exception: Erreur de
///     récupération du profil : {"error":"Token invalide ou expiré"}
///
/// Trois couches y avaient chacune ajouté leur part : le serveur son JSON, le
/// service son `Exception(...)`, l'écran son `$e`. Aucune n'avait tort seule ;
/// c'est l'empilement qui a produit une phrase illisible, et qui a surtout
/// caché le seul fait utile — la session avait expiré, il fallait se
/// reconnecter, pas « réessayer ».
///
/// Deux fonctions ici, une par bout de la chaîne : [messageDeLaReponse] pour un
/// service qui tient une réponse HTTP, [messageLisible] pour un écran qui tient
/// une exception.

/// Le message du serveur, ou à défaut une phrase tirée du code HTTP.
///
/// Le serveur répond souvent des phrases directement utilisables — « ce
/// manuscrit est trop court pour être publié : 4 page(s) déposée(s), 10 au
/// minimum ». Les jeter pour un message générique laisse la personne devant un
/// échec sans cause ni remède ; les afficher bruts, sans ce filtre, laisse
/// passer les accolades.
String messageDeLaReponse(
  http.Response reponse, {
  String repli = "Une erreur est survenue.",
}) {
  // Idem ici : un 401 se raconte toujours en « votre session a expiré », jamais
  // avec le mot du serveur.
  if (reponse.statusCode == 401) {
    return "Votre session a expiré. Reconnectez-vous.";
  }

  final duServeur = _messageDuCorps(reponse.body);
  if (duServeur != null) return duServeur;

  return switch (reponse.statusCode) {
    400 => "Demande invalide.",
    403 => "Vous n'avez pas accès à cette ressource.",
    404 => "Introuvable.",
    408 => "Le serveur a mis trop de temps à répondre.",
    409 => "Cette opération entre en conflit avec un enregistrement existant.",
    413 => "Fichier trop volumineux.",
    422 => "Ces informations ne peuvent pas être enregistrées telles quelles.",
    429 => "Trop de tentatives. Patientez un instant.",
    >= 500 =>
      "Le service est momentanément indisponible. Réessayez dans un instant.",
    _ => "$repli (${reponse.statusCode})",
  };
}

/// La phrase portée par un corps de réponse, si elle est présentable.
///
/// Un corps JSON peut contenir une phrase écrite pour un humain, ou une trace
/// technique. On ne garde que la première.
String? _messageDuCorps(String corps) {
  if (corps.isEmpty) return null;
  try {
    final decode = jsonDecode(corps);
    if (decode is Map) {
      for (final cle in const ['error', 'message', 'erreur', 'detail']) {
        final valeur = decode[cle];
        if (valeur is String && _estPresentable(valeur)) return _finir(valeur);
      }
    }
  } catch (_) {
    // Un corps qui n'est pas du JSON n'est pas pour autant un message : du HTML
    // de passerelle, une trace de pile. On ne l'affiche pas.
  }
  return null;
}

/// Rendre lisible ce qu'un `catch` a attrapé.
///
/// C'est la fonction que les écrans doivent appeler à la place de `"...$e"`.
/// Elle a une consigne stricte : dans le doute, taire. Un message générique
/// est désagréable ; une accolade et un nom de classe à l'écran font douter de
/// tout le produit.
String messageLisible(
  Object? erreur, {
  String repli = "Une erreur est survenue. Réessayez dans un instant.",
}) {
  if (erreur == null) return repli;

  if (erreur is TimeoutException) {
    return "Le serveur a mis trop de temps à répondre. Vérifiez votre connexion.";
  }
  if (erreur is http.ClientException || _estPanneReseau(erreur.toString())) {
    return "Pas de connexion. Vérifiez votre réseau, puis réessayez.";
  }
  if (erreur is FormatException) {
    return "Réponse inattendue du serveur. Réessayez dans un instant.";
  }

  // La session expirée passe avant tout le reste, y compris avant la phrase du
  // serveur — parce que celle du serveur est « Token invalide ou expiré ».
  // C'est exact, et c'est du jargon : « token » ne veut rien dire pour la
  // personne qui lit. Elle a besoin de savoir quoi FAIRE, pas ce qui s'est
  // techniquement produit.
  if (estSessionExpiree(erreur)) {
    return "Votre session a expiré. Reconnectez-vous.";
  }

  var texte = erreur.toString().trim();

  // `Exception("Session expirée")` s'affiche « Exception: Session expirée ».
  // Le préfixe est du bruit de langage, pas de l'information : les services
  // portent leur message dans une Exception faute de mieux.
  for (final prefixe in const [
    'Exception: ',
    'Exception:',
    '_Exception: ',
    'StateError: ',
    'ArgumentError: ',
    'Erreur: ',
  ]) {
    if (texte.startsWith(prefixe)) {
      texte = texte.substring(prefixe.length).trim();
      break;
    }
  }

  // Le message peut lui-même se terminer par un corps de réponse recopié :
  // c'est précisément ce qui a produit la capture d'écran. On tente d'en
  // extraire la phrase, sinon on abandonne le tout.
  final debutJson = texte.indexOf('{');
  if (debutJson >= 0) {
    final duCorps = _messageDuCorps(texte.substring(debutJson));
    if (duCorps != null) return duCorps;

    final avant = texte.substring(0, debutJson).trim();
    texte = avant.replaceAll(RegExp(r'[\s:—-]+$'), '');
  }

  return _estPresentable(texte) ? _finir(texte) : repli;
}

/// Un texte est présentable s'il a été écrit pour être lu.
///
/// Le test est volontairement sévère : on préfère un message générique à une
/// fuite. Tout ce qui sent le diagnostic — accolades, chevrons, chemins de
/// fichier, noms de classes Dart, codes d'erreur système — est écarté.
bool _estPresentable(String texte) {
  final t = texte.trim();
  if (t.length < 3 || t.length > 200) return false;

  const marqueurs = [
    '{', '}', '[]', '<', '>', '\\n', '\\t',
    'Exception', 'Error', 'error:', 'errno', 'Failed host',
    'null', 'Instance of', '#0 ', 'package:', 'dart:',
    'http://', 'https://', '.dart', 'StackTrace', 'Uri.parse',
    'SQLSTATE', 'pq:', 'gorm', 'panic:',
    // Les erreurs Dart ne se nomment pas comme leur classe : `StateError`
    // s'affiche « Bad state: … », `ArgumentError` « Invalid argument(s): … ».
    // Filtrer sur le nom de la classe les laissait donc toutes passer.
    'Bad state', 'Invalid argument', 'RangeError', 'is not a subtype',
    'Unsupported operation', 'NoSuchMethod', 'Concurrent modification',
    // Les messages de développeur laissés en anglais dans la couche service —
    // « Failed to fetch followers », « Failed to toggle like ». Rien en eux ne
    // sent la trace technique : sans cette ligne ils passeraient le filtre et
    // s'afficheraient tels quels à quelqu'un qui lit en français.
    'Failed to', 'failed to', 'Unable to', 'Cannot ',
  ];
  for (final marqueur in marqueurs) {
    if (t.contains(marqueur)) return false;
  }

  // Une phrase contient des lettres. « 500 » ou « -1 » n'en sont pas une.
  return RegExp(r'[A-Za-zÀ-ÿ]').hasMatch(t);
}

bool _estPanneReseau(String texte) {
  const marqueurs = [
    'SocketException',
    'Failed host lookup',
    'Connection refused',
    'Connection closed',
    'Network is unreachable',
    'HandshakeException',
    'No route to host',
    'Software caused connection abort',
  ];
  return marqueurs.any(texte.contains);
}

/// Une majuscule au début, un point à la fin.
String _finir(String texte) {
  var t = texte.trim();
  if (t.isEmpty) return t;
  t = t[0].toUpperCase() + t.substring(1);
  if (!t.endsWith('.') && !t.endsWith('!') && !t.endsWith('?')) t = '$t.';
  return t;
}

/// La session a-t-elle expiré ?
///
/// L'écran doit le savoir : un jeton mort ne se répare pas en réessayant, et
/// proposer « Réessayer » sur une session expirée, c'est offrir un bouton qui
/// ne peut par construction jamais aboutir.
bool estSessionExpiree(Object? erreur) {
  if (erreur == null) return false;
  final t = erreur.toString().toLowerCase();
  return t.contains('token invalide') ||
      t.contains('token expiré') ||
      t.contains('token expire') ||
      t.contains('session expirée') ||
      t.contains('session expiree') ||
      t.contains('non authentifié') ||
      t.contains('unauthorized') ||
      t.contains('jwt');
}
