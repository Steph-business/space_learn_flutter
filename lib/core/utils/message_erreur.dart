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

/// La phrase, unique, par laquelle l'application dit qu'un jeton est mort.
///
/// ELLE EST ÉCRITE ICI PARCE QUE [estSessionExpiree] DOIT LA RECONNAÎTRE.
/// Pendant un temps, [messageDeLaReponse] la rendait de son côté et
/// `estSessionExpiree` cherchait de l'autre « session expirée » : la phrase
/// produite dit « session A expiré », la recherche échouait, et les quatorze
/// écrans qui décident du bouton d'après cette fonction offraient « Réessayer »
/// sur un jeton mort — le seul bouton qui, par construction, ne pouvait pas
/// aboutir. Une constante partagée : la phrase rendue et la phrase reconnue ne
/// peuvent plus diverger.
const String phraseSessionExpiree = "Votre session a expiré. Reconnectez-vous.";

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
  //
  // C'EST UN CHOIX, ET IL EST TENU EXPRÈS — pas un oubli à corriger au prochain
  // tour. Le serveur des livres taille à la main de belles phrases de 401
  // (« … Reconnectez-vous pour voir la suite de la liste. »,
  // modules/relations/controller.go), et AUCUNE n'arrive à l'écran : cette
  // ligne les remplace toutes par [phraseSessionExpiree]. Ce n'est pas une
  // perte, parce que la même ligne écarte aussi ce qui sort du middleware sur
  // la grande majorité des 401 — « Token invalide ou expiré »,
  // « Utilisateur non authentifié » : du jargon, pour quelqu'un qui a besoin de
  // savoir quoi FAIRE. Trier les deux familles demanderait de reconnaître les
  // phrases une à une, c'est-à-dire de recopier ici des textes qui vivent dans
  // un autre dépôt et changent sans nous.
  //
  // CE QUI EN DÉCOULE, ET QU'IL FAUT SAVOIR AVANT D'ÉCRIRE UN 401 CÔTÉ
  // SERVEUR : la phrase n'atteindra pas ce client. Seul le GESTE compte, et il
  // est le même partout — mener à la connexion, jamais « Réessayer ». Voir
  // [estSessionExpiree], que les écrans interrogent pour choisir ce geste.
  if (reponse.statusCode == 401) {
    return phraseSessionExpiree;
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

/// La phrase du serveur, et RIEN si le corps n'en porte pas.
///
/// Pendant de [messageDeLaReponse] pour l'appelant qui a besoin de savoir si le
/// serveur a dit quelque chose, et non d'obtenir une phrase coûte que coûte :
/// la phrase de repli tirée du code HTTP (« Vous n'avez pas accès à cette
/// ressource. ») n'apprend rien à personne, et l'afficher à la place d'un
/// silence ferait passer une absence pour une explication.
///
/// Le seul appelant aujourd'hui est le renouvellement de session (`ApiClient`),
/// qui doit distinguer « le compte est fermé, voici pourquoi et à qui écrire »
/// de « le jeton est mort », les deux arrivant sur la même route.
String? phraseDuCorps(String corps) => _messageDuCorps(corps);

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
    return phraseSessionExpiree;
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

/// Au-delà, ce n'est plus une phrase : c'est un déversement.
///
/// LE PLAFOND QUI ÉTAIT ICI VALAIT DEUX CENTS, ET IL JETAIT LES MESSAGES DU
/// SERVEUR. Trois phrases du serveur d'authentification passent au-dessus :
/// le 409 de réinscription (`register.go`), les deux 403 de compte fermé
/// (`login.go`), la réponse de `DeleteAccount` (`user.go`, 329 caractères).
/// Le mobile affichait donc « Cette opération entre en conflit avec un
/// enregistrement existant. » là où le site — qui n'a aucun plafond — affiche
/// la cause, la date et l'adresse où écrire. Un serveur, trois clients, deux
/// vérités.
///
/// CE QUE LE PLAFOND PROTÉGEAIT VRAIMENT, ce n'était pas la longueur : c'était
/// une page HTML de passerelle, un vidage JSON, une trace de pile. Ces
/// trois-là se reconnaissent à ce qu'ils SONT — un chevron, une accolade, des
/// cadres empilés sur autant de lignes, un jeton de quarante caractères — et
/// c'est ainsi qu'ils sont écartés maintenant, par les trois tests qui suivent
/// le seuil. La longueur ne dit rien : une trace de pile de cent quatre-vingts
/// caractères passait, une phrase honnête de deux cent un était jetée.
///
/// Le seuil reste, parce qu'un texte de plus d'un paragraphe n'a pas été écrit
/// pour une boîte de dialogue quoi qu'il contienne. Il est calé haut, très
/// au-dessus du plus long message que le serveur écrive aujourd'hui.
const int _longueurMaximaleDunMessage = 600;

/// Aucun mot français ne fait quarante lettres.
///
/// Un jeton, une empreinte, une adresse encodée, un chemin de fichier, si.
/// C'est ce test — et non la longueur totale — qui écarte un déversement de
/// données là où il n'y a ni accolade ni chevron pour le trahir.
const int _longueurMaximaleDunMot = 40;

/// Un texte est présentable s'il a été écrit pour être lu.
///
/// Le test est volontairement sévère : on préfère un message générique à une
/// fuite. Tout ce qui sent le diagnostic — accolades, chevrons, chemins de
/// fichier, noms de classes Dart, codes d'erreur système — est écarté.
bool _estPresentable(String texte) {
  final t = texte.trim();
  if (t.length < 3 || t.length > _longueurMaximaleDunMessage) return false;

  // UN PARAGRAPHE, PAS UN LISTING. Une trace de pile porte un cadre par ligne,
  // une réponse de passerelle ses en-têtes de même. Une phrase écrite pour être
  // lue tient sur une ligne, deux quand elle nomme un geste à part.
  if ('\n'.allMatches(t).length > 2 || t.contains('\r')) return false;

  // Ce qui n'est pas un mot n'est pas de la prose : voir
  // [_longueurMaximaleDunMot].
  //
  // SAUF UNE ADRESSE WEB, ET C'EST LA SEULE EXCEPTION. Une URL dépasse
  // couramment quarante caractères sans rien avoir d'un déversement : c'est
  // souvent l'information même pour laquelle la phrase a été écrite — le lien
  // de reprise d'un paiement, la page où confirmer. La règle au mot jetait le
  // message ENTIER pour ce seul mot-là, et la personne retombait sur le repli
  // générique, privée du lien. Les jetons, empreintes et chemins que cette
  // règle vise ne commencent pas par « http ».
  for (final mot in t.split(RegExp(r'\s+'))) {
    if (mot.length <= _longueurMaximaleDunMot) continue;
    if (mot.startsWith('http://') || mot.startsWith('https://')) continue;
    return false;
  }

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
///
/// ON RECONNAÎT DEUX FAMILLES DE PHRASES, ET LA SECONDE MANQUAIT.
///
/// La première vient du SERVEUR — « Token invalide ou expiré »,
/// « Utilisateur non authentifié ». La seconde vient de NOUS : sur un 401,
/// [messageDeLaReponse] ne relaie plus le mot du serveur, il rend
/// [phraseSessionExpiree], et chaque service enveloppe cela dans une
/// `Exception`. C'est donc « Votre session A EXPIRÉ » que les écrans reçoivent
/// aujourd'hui, dans l'écrasante majorité des cas — une forme qu'aucune des
/// aiguilles d'origine ne contenait, « session expirée » et « session a
/// expiré » n'ayant aucune sous-chaîne commune utile.
///
/// Conséquence, tant que la ligne manquait : les quatorze écrans qui appellent
/// cette fonction recevaient `false` sur une VRAIE expiration et offraient
/// « Réessayer ». Le remède qu'on lisait ailleurs — « lire l'exception brute,
/// avant qu'elle ne devienne une phrase » — ne pouvait rien y faire :
/// l'exception EST déjà la phrase, elle sort du service ainsi.
bool estSessionExpiree(Object? erreur) {
  if (erreur == null) return false;
  final t = erreur.toString().toLowerCase();
  return t.contains('token invalide') ||
      t.contains('token expiré') ||
      t.contains('token expire') ||
      t.contains('session expirée') ||
      t.contains('session expiree') ||
      // Ce que l'application produit elle-même : voir [phraseSessionExpiree].
      t.contains('session a expiré') ||
      t.contains('session a expire') ||
      t.contains('non authentifié') ||
      t.contains('unauthorized') ||
      // LE SERVEUR DES LIVRES REFUSE EN ANGLAIS, et aucune aiguille ne le
      // reconnaissait. `middleware/auth.go` (space_learn_livres) rend
      // « Invalid token », « Authorization header required »,
      // « Bearer token required », « Invalid user ID in token » — quatre
      // phrases dont pas une ne contient « token invalide », « unauthorized »
      // ni « session ». Tant que le service passe par [messageDeLaReponse], le
      // 401 est intercepté avant le corps et rendu en [phraseSessionExpiree],
      // donc rien ne se voyait ; mais tout service qui court-circuite cette
      // fonction — et il en existe — laissait l'anglais remonter, et l'écran
      // offrait « Réessayer » sur un jeton mort.
      t.contains('invalid token') ||
      t.contains('token required') ||
      t.contains('authorization header') ||
      t.contains('invalid user id in token');
  // « JWT » A ÉTÉ RETIRÉ DE CETTE LISTE, et c'est un resserrement délibéré.
  //
  // L'aiguille était la sous-chaîne nue `jwt`, sans contexte. Elle ne
  // reconnaissait RIEN : la recherche sur les deux dépôts Go ne rend aucune
  // phrase contenant « jwt » qui parte vers un client — toutes les
  // occurrences sont des journaux de démarrage, des noms de variables
  // d'environnement ou des imports. Elle ne pouvait donc que se tromper : un
  // message qui mentionne le mot pour une autre raison — « la configuration
  // JWT_SECRET est absente », une erreur de configuration relayée telle
  // quelle — aurait fait conclure à une session morte, effacé la vraie cause
  // au profit de « Votre session a expiré » et mené à la connexion quelqu'un
  // dont le jeton n'avait rien.
}

/// LE SERVEUR N'A RIEN PU FAIRE, ET IL N'A RIEN FAIT.
///
/// Pendant exact de [AccesRefuse], et nécessaire pour la même raison : la
/// différence est invisible dans le texte, seul le service tient le code HTTP.
/// « La vérification du code est momentanément impossible. Réessayez dans un
/// instant. » est une phrase comme une autre pour un écran, alors qu'elle dit
/// quelque chose de très précis — rien n'a été écrit, aucun essai n'a été
/// compté contre la personne, son code est intact.
///
/// C'EST LE SEUL CAS DE CES ROUTES OÙ « RÉESSAYER » PEUT ABOUTIR, et c'est
/// pourquoi il fallait le distinguer. Le serveur d'authentification confondait
/// jusqu'ici la panne de base et le refus : sur un hoquet, il répondait « Code
/// OTP invalide ou expiré » ET comptait un essai fautif. Il rend maintenant 503
/// avec sa propre phrase (space_learn_auth, controllers/otp.go,
/// `reponsePanneCode`), sur `/auth/verify-otp`, `/auth/verification` et
/// `/auth/reset-password`.
///
/// Ce que l'écran en fait : afficher la phrase telle quelle, offrir de
/// réessayer, et NE PAS vider les cases du code déjà saisi.
///
/// `toString` rend le message nu, comme [AccesRefuse] : rien n'a besoin de
/// connaître ce type pour continuer d'afficher la bonne phrase.
class PanneServeur implements Exception {
  final String message;

  const PanneServeur(this.message);

  @override
  String toString() => message;
}

/// Un refus de DROIT — la porte est fermée, elle ne s'ouvrira pas en insistant.
///
/// Même raisonnement que pour la session expirée, juste au-dessus, et il vaut
/// mot pour mot : proposer « Réessayer » à qui n'a pas le droit d'entrer, c'est
/// offrir un bouton qui ne peut par construction jamais aboutir. La différence
/// avec une panne est invisible dans le texte — le serveur écrit « ce salon est
/// réservé aux lecteurs de ce livre », qui est une phrase comme une autre — et
/// un écran ne peut pas la deviner en lisant le message. D'où ce type : le
/// service, qui tient le code HTTP, le dit une fois pour toutes.
///
/// `toString` rend le message NU, sans préfixe de classe : [messageLisible] le
/// traite alors exactement comme celui d'une `Exception`, et rien n'a besoin de
/// connaître ce type pour continuer d'afficher la bonne phrase. Seuls les
/// écrans qui veulent changer le GESTE proposé (« Retour » au lieu de
/// « Réessayer ») ont à le tester.
class AccesRefuse implements Exception {
  final String message;

  const AccesRefuse(this.message);

  @override
  String toString() => message;
}

/// LE COMPTE EST DÉJÀ VALIDÉ : ce code n'a plus d'usage, et la sortie est la
/// connexion.
///
/// C'est un [AccesRefuse] — donc AUCUN « Réessayer » : réessayer ne peut pas
/// aboutir, le code présenté est mort et l'adresse est vérifiée depuis
/// longtemps. Le type existe à part parce que ce refus-là, seul de tous,
/// désigne une SORTIE précise : l'écran de connexion.
///
/// D'OÙ VIENNENT LES GENS QUI TOMBENT ICI. La version en production de
/// `/auth/verification` rendait 500 APRÈS avoir consommé le code et posé
/// `email_verified` : le compte était validé, le code mort, et la réponse
/// disait « le serveur n'a rien pu faire ». Ils ont donc rappuyé sur
/// « Réessayer » avec un code que le serveur venait de brûler, et recevaient
/// « L'email est déjà vérifié » — un refus qui ne nommait aucune sortie. Le
/// serveur a fermé la cause (l'ordre des écritures : session d'abord, code
/// consommé en dernier) et ouvert la porte pour ceux qui étaient déjà enfermés
/// dedans : 400 avec `deja_verifie: true` et la phrase que porte ce type
/// (space_learn_auth, controllers/verification.go, `reponseDejaValide`).
///
/// La phrase du serveur est affichée TELLE QUELLE : elle nomme les DEUX portes
/// — mot de passe ou Google — parce qu'un compte né d'une inscription par
/// e-mail a pu être validé par une connexion Google entre-temps, et qu'un
/// compte né de Google porte un mot de passe aléatoire que personne ne connaît.
class CompteDejaValide extends AccesRefuse {
  const CompteDejaValide(super.message);
}
