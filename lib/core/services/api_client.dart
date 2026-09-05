import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:space_learn_flutter/core/utils/api_routes.dart';
import 'package:space_learn_flutter/core/utils/token_storage.dart';

/// Ce qu'une tentative de renouvellement apprend sur la session.
///
/// Trois issues, et non deux. La distinction porte tout : « le serveur a dit
/// non » finit la session, « je n'ai pas pu lui demander » n'apprend rien.
/// Le code ne connaissait que `true` et `false`, et `false` déconnectait — si
/// bien qu'une session parfaitement valide tombait dès que la demande ne
/// passait pas. Sur un réseau mobile ivoirien, ce n'est pas un cas limite.
enum Renouvellement {
  /// La session repart : un jeton neuf est en réserve.
  reussi,

  /// Le serveur a refusé. Le jeton de rafraîchissement ne vaut plus rien —
  /// périmé, révoqué, rejoué — ou le compte lui-même est fermé. C'est la
  /// SEULE issue qui ramène à l'écran de connexion.
  refuse,

  /// On n'a pas pu demander : réseau coupé, délai dépassé, serveur en panne,
  /// quota du limiteur atteint. La session est peut-être intacte ; on ne
  /// déconnecte personne sur une supposition.
  indisponible,
}

/// Client HTTP partagé par tous les services de l'application.
///
/// Il porte trois responsabilités, toutes parce qu'elles n'ont de sens qu'en un
/// seul endroit.
///
/// D'abord la pose du jeton. Chaque service composait ses en-têtes à la main,
/// et plusieurs lectures partaient donc sans jeton — celle du salon global
/// notamment. Le poser ici le pose partout, une fois.
///
/// Ensuite le renouvellement de la session. Le jeton d'accès ne vit plus qu'une
/// heure : sans ce point unique, le lecteur serait renvoyé à l'écran de
/// connexion en pleine lecture, toutes les heures.
///
/// Enfin la réaction à une session vraiment finie : purger et ramener à la
/// connexion, quelle que soit la page d'où partait la requête.
///
/// Usage : les services prennent `ApiClient.instance` par défaut et acceptent
/// toujours un client injecté pour les tests.
class ApiClient extends http.BaseClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();

  final http.Client _inner = http.Client();

  /// Branché une fois au démarrage (cf. `main.dart`) : purge la session locale
  /// et renvoie vers l'écran de connexion. Laissé nul, un 401 est simplement
  /// propagé au service appelant.
  static Future<void> Function()? onUnauthorized;

  /// Évite d'enchaîner plusieurs déconnexions quand un écran déclenche
  /// plusieurs requêtes en parallèle et qu'elles échouent toutes.
  bool _handlingUnauthorized = false;

  /// Ce qu'une requête ordinaire a le droit de faire attendre.
  ///
  /// Sur les cent trente-six requêtes de l'application, cinq portaient un
  /// délai. Or une requête qui n'aboutit jamais ne lève rien : aucun `catch`
  /// ne se déclenche, aucun message ne s'affiche, et l'écran reste sur son
  /// indicateur de chargement, indéfiniment et sans recours. `messageLisible`
  /// a pourtant une phrase toute prête pour `TimeoutException` — que presque
  /// rien ne pouvait déclencher.
  ///
  /// Le délai s'applique deux fois : à l'obtention de la réponse, puis entre
  /// deux morceaux du corps. Ne borner que la première laisserait passer un
  /// serveur qui envoie ses en-têtes puis se tait — un portail captif fait
  /// exactement cela.
  static const Duration delaiRequete = Duration(seconds: 30);

  /// Marqueur posé par un appelant dont la route répond 401 pour une raison
  /// MÉTIER, et non de session.
  ///
  /// La couche transport ne peut pas deviner ce qu'un 401 veut dire : elle voit
  /// un code, pas un corps. Elle s'appuyait donc sur le chemin — `/auth/` —, et
  /// `POST /utilisateurs/:id/change-password` n'en fait pas partie alors qu'il
  /// répond 401 pour dire « Ancien mot de passe incorrect ». Une simple faute
  /// de frappe déclenchait ainsi un renouvellement PUIS un rejeu : trois
  /// allers-retours au lieu d'un, le mot de passe actuel et le nouveau
  /// retraversant le réseau et les journaux du proxy une seconde fois, deux
  /// jetons du limiteur consommés au lieu d'un — ce limiteur est commun à la
  /// connexion et aux OTP, et sous CGNAT le gaspillage retombe sur des voisins
  /// —, et une rotation de la lignée de rafraîchissement pour rien.
  ///
  /// L'appelant, lui, lit le corps et sait faire la différence. Il pose cet
  /// en-tête ; `send` le retire AVANT l'envoi — c'est une convention interne à
  /// l'application, elle n'a rien à faire sur le réseau — et rend la réponse
  /// telle quelle : ni renouvellement, ni rejeu. À charge pour l'appelant de
  /// mener lui-même le renouvellement quand le corps dit une session finie, et
  /// de relayer un refus par [constaterSessionFinie].
  static const enTete401Metier = 'X-SL-401-Metier';

  /// Le renouvellement en cours, s'il y en a un.
  ///
  /// Un écran d'accueil lance une dizaine de requêtes d'un coup. Passé l'heure,
  /// les dix reviennent en 401 en même temps. Sans ce partage, dix
  /// renouvellements partiraient de front : le premier ferait tourner le jeton,
  /// les neuf autres présenteraient un jeton déjà consommé — et le serveur,
  /// qui voit là un rejeu, fermerait la session entière. La protection contre
  /// le vol deviendrait une déconnexion à chaque ouverture.
  Future<Renouvellement>? _renouvellementEnCours;

  /// Ce qu'un code de réponse de `/auth/refresh` dit de la session.
  ///
  /// Publique, et c'est délibéré : la règle était jusqu'ici recopiée à la main
  /// dans les tests, qui vérifiaient donc l'intention et non le code. Les deux
  /// avaient divergé sans que rien ne le signale.
  static Renouvellement verdictDuServeur(int codeHttp) {
    if (codeHttp == 200) return Renouvellement.reussi;

    // 401 : le jeton présenté ne vaut plus rien. 403 : le compte est fermé —
    // archivé, suspendu, supprimé. Les deux sont définitifs, et réessayer
    // n'y changera rien.
    if (codeHttp == 401 || codeHttp == 403) return Renouvellement.refuse;

    // Tout le reste est passager : le 429 du limiteur derrière une adresse
    // partagée par des milliers d'abonnés, un 5xx, une passerelle qui répond
    // de travers. Rien de tout cela ne dit que la session est finie.
    return Renouvellement.indisponible;
  }

  /// Faut-il ramener la personne à l'écran de connexion ?
  ///
  /// Une seule chose en décide : ce que `/auth/refresh` a répondu. Ni le code
  /// d'une route métier, ni le nombre de fois qu'elle a échoué.
  ///
  /// La nuance a coûté cher. Une requête qui répondait 401 même après un
  /// renouvellement RÉUSSI provoquait la déconnexion : on en concluait que
  /// « l'accès est réellement refusé ». Mais le serveur d'authentification
  /// venait précisément de délivrer un jeton — la session était vivante,
  /// prouvée telle. Le lecteur se faisait éjecter quelques secondes après
  /// s'être connecté, se reconnectait, et ressortait par la même porte.
  ///
  /// Qu'une route refuse l'accès est un problème de cette route. Ce n'en est
  /// pas un de session.
  static bool sessionTerminee(Renouvellement verdict) =>
      verdict == Renouvellement.refuse;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    // Les routes d'authentification renvoient légitimement 401 (mauvais mot de
    // passe, OTP invalide) : ce n'est pas une session expirée. Elles n'ont pas
    // non plus besoin qu'on leur pose un jeton.
    final estRouteAuth = request.url.path.contains('/auth/');

    // Le retrait précède l'envoi, sinon le marqueur partirait sur le réseau.
    // `BaseRequest.headers` compare ses clés sans tenir compte de la casse :
    // cette écriture-ci suffit, quelle que soit celle de l'appelant.
    final quatreCentUnMetier = request.headers.remove(enTete401Metier) != null;

    final posePar = request.headers.containsKey('Authorization');
    if (!estRouteAuth && !posePar) {
      await _poserLeJeton(request);
    }

    var reponse = await _envoyer(request);

    // `quatreCentUnMetier` rend la main pour la même raison que `estRouteAuth`,
    // constatée autrement : sur ces routes-là, un 401 ne parle pas de session.
    // Cf. [enTete401Metier].
    if (reponse.statusCode != 401 || estRouteAuth || quatreCentUnMetier) {
      return reponse;
    }

    // ── DIAGNOSTIC : quelle requête déclenche le 401 ? ──
    debugPrint('\n╔══ DIAGNOSTIC SESSION ══════════════════════');
    debugPrint('║ 401 reçu sur : ${request.method} ${request.url}');
    debugPrint('║ Authorization présent : $posePar');
    debugPrint('╚════════════════════════════════════════════\n');

    // Le jeton porté par la requête est-il celui de la session ?
    //
    // Presque tous les services de l'application prennent un `token` en
    // paramètre et posent l'en-tête eux-mêmes — ce jeton, ils l'ont lu dans le
    // même coffre. Les écarter au motif qu'ils « ont choisi leur jeton »
    // revenait à ne jamais rejouer aucune requête métier : passé une heure, la
    // première action dans un salon, une bibliothèque ou un paiement échouait,
    // la session se renouvelait en coulisses, et il fallait recommencer pour
    // que ça passe. Un échec sur deux, invisible à l'analyse et systématique à
    // l'usage.
    //
    // La lecture se fait AVANT le renouvellement : après, le jeton en réserve
    // est déjà le nouveau et la comparaison ne dirait plus rien.
    final ancienJeton = await TokenStorage.getToken();
    final porteLeJetonDeSession =
        !posePar || request.headers['Authorization'] == 'Bearer $ancienJeton';

    // On tente TOUJOURS de renouveler, même quand cette requête-ci ne pourra
    // pas être rejouée. Ne pas le faire déconnecterait un auteur pour un dépôt
    // de manuscrit tombé à la mauvaise minute, alors que sa session est
    // parfaitement valide et que la requête suivante passerait.
    final verdict = await _renouvelerLaSession();

    // Un appelant qui porte un AUTRE jeton que celui de la session a
    // véritablement choisi une identité : celui-là, on ne le remplace pas.
    if (verdict == Renouvellement.reussi &&
        porteLeJetonDeSession &&
        _peutEtreRejouee(request)) {
      // Le corps a été consommé par le premier envoi : on reconstruit.
      final seconde = _copier(request as http.Request);
      // L'en-tête recopié porte le jeton mort : il faut l'écraser, sinon le
      // rejeu présente exactement ce que le serveur vient de refuser.
      seconde.headers.remove('Authorization');
      await _poserLeJeton(seconde);
      reponse = await _envoyer(seconde);

      // Un second 401 ne ferme PLUS la session.
      //
      // C'était le cas, et le raisonnement paraissait solide : « avec un jeton
      // tout neuf, l'accès est réellement refusé ». Il confondait deux choses.
      //
      // Nous venons de renouveler la session AVEC SUCCÈS : le serveur
      // d'authentification vient de nous délivrer un jeton, donc la session est
      // vivante, prouvée telle à la seconde près. Qu'UNE route réponde 401
      // malgré cela dit quelque chose de cette route — un défaut, un droit qui
      // manque, un chemin mal formé — jamais que la personne doit être remise
      // à l'écran de connexion.
      //
      // C'est ce qui se produisait : une seule requête fautive, et le lecteur
      // était éjecté quelques secondes après s'être connecté. Il se
      // reconnectait, la même requête repartait, et il ressortait.
      //
      // L'appelant reçoit son 401 et l'affiche à sa façon. La session, elle,
      // ne se juge qu'à /auth/refresh.
      if (reponse.statusCode == 401) {
        debugPrint(
          'Refus persistant sur ${request.method} ${request.url} : '
          'la session est pourtant valide (renouvelée à l\'instant). '
          'C\'est cette route qu\'il faut regarder, pas la session.',
        );
      }
      return reponse;
    }

    if (sessionTerminee(verdict)) _declencherDeconnexion();

    // Session renouvelée mais requête non rejouable : rien à déconnecter,
    // l'appelant reçoit son échec et pourra recommencer.
    return reponse;
  }

  /// Cette requête-ci est-elle bornée dans le temps ?
  ///
  /// Non pour les envois de fichiers. Un dépôt de manuscrit part en
  /// `StreamedRequest` et peut légitimement durer plusieurs minutes sur un
  /// réseau lent : lui imposer le délai d'une requête ordinaire couperait
  /// l'envoi en cours de route, et l'auteur perdrait son fichier à chaque
  /// fois. C'est la même frontière que [_peutEtreRejouee] — seules les
  /// requêtes au corps entièrement connu sont bornées.
  ///
  /// Publique pour la même raison que [verdictDuServeur] : une règle qu'un
  /// test recopie à la main est une règle qui finira par diverger du code.
  static bool estBornee(http.BaseRequest requete) => requete is http.Request;

  /// Envoie en bornant l'attente, selon [estBornee].
  ///
  /// Le flux de notifications n'entre jamais ici : il ouvre son propre
  /// `HttpClient`.
  Future<http.StreamedResponse> _envoyer(http.BaseRequest request) async {
    if (!estBornee(request)) return _inner.send(request);

    final reponse = await _inner.send(request).timeout(delaiRequete);
    return http.StreamedResponse(
      reponse.stream.timeout(delaiRequete),
      reponse.statusCode,
      contentLength: reponse.contentLength,
      request: reponse.request,
      headers: reponse.headers,
      isRedirect: reponse.isRedirect,
      persistentConnection: reponse.persistentConnection,
      reasonPhrase: reponse.reasonPhrase,
    );
  }

  Future<void> _poserLeJeton(http.BaseRequest request) async {
    final token = await TokenStorage.getToken();
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }
  }

  /// Une requête ne se rejoue que si son corps est encore disponible.
  ///
  /// `StreamedRequest` — le dépôt d'un manuscrit — envoie son corps au fil de
  /// l'eau : une fois parti, il n'est plus là. Le rejouer enverrait un fichier
  /// vide. Ces requêtes-là échouent donc franchement, et l'auteur recommence.
  bool _peutEtreRejouee(http.BaseRequest request) => request is http.Request;

  http.Request _copier(http.Request origine) {
    final copie = http.Request(origine.method, origine.url)
      ..headers.addAll(origine.headers)
      ..followRedirects = origine.followRedirects
      ..maxRedirects = origine.maxRedirects
      ..persistentConnection = origine.persistentConnection
      ..bodyBytes = origine.bodyBytes;
    return copie;
  }

  /// Renouvelle la session à la demande.
  ///
  /// Pour ce qui ne passe pas par `send` : le flux de notifications est une
  /// connexion HTTP longue, ouverte à la main avec `HttpClient`. L'intercepteur
  /// ne peut rien pour elle — une fois la connexion établie, il n'y a plus de
  /// requête à rejouer. Elle doit donc pouvoir demander un jeton neuf
  /// elle-même, et profite du même appel unique partagé.
  Future<Renouvellement> renouvelerSession() => _renouvelerLaSession();

  /// Constate de l'extérieur qu'une session est finie : purge et retour à la
  /// connexion, exactement comme si le 401 était passé par `send`.
  ///
  /// Pendant de [renouvelerSession], et nécessaire pour la même raison. Un
  /// appelant qui pose [enTete401Metier] mène son renouvellement lui-même :
  /// c'est donc lui, et non `send`, qui apprend le refus de `/auth/refresh`.
  /// Sans ce relais, le marqueur supprimerait au passage la déconnexion que
  /// `send` déclenchait jusqu'ici sur ce refus, et la personne resterait sur
  /// son écran avec « Token invalide ou expiré » pour toute explication et une
  /// session morte dans le coffre — jusqu'au prochain 401 d'un autre écran.
  ///
  /// La garde de non-réentrance est celle de `send` : deux constats
  /// rapprochés ne déclenchent qu'une seule déconnexion.
  void constaterSessionFinie() => _declencherDeconnexion();

  /// Échange le jeton de rafraîchissement contre un couple neuf.
  ///
  /// Un seul appel à la fois, partagé par toutes les requêtes qui attendent.
  Future<Renouvellement> _renouvelerLaSession() {
    return _renouvellementEnCours ??= _renouveler().whenComplete(() {
      _renouvellementEnCours = null;
    });
  }

  Future<Renouvellement> _renouveler() async {
    try {
      final refresh = await TokenStorage.getRefreshToken();
      // ── DIAGNOSTIC ──
      debugPrint('\n╔══ DIAGNOSTIC REFRESH ═════════════════════');
      debugPrint('║ Refresh token présent : ${refresh != null && refresh.isNotEmpty}');
      debugPrint('║ Refresh token (début) : ${refresh != null && refresh.length > 20 ? refresh.substring(0, 20) : refresh}...');
      // Rien à présenter : aucune requête ne ranimera cette session-là.
      if (refresh == null || refresh.isEmpty) {
        debugPrint('║ ⛔ PAS DE REFRESH TOKEN → refuse');
        debugPrint('╚════════════════════════════════════════════\n');
        return Renouvellement.refuse;
      }

      // Volontairement `_inner` : passer par `send` relancerait ce même
      // mécanisme sur son propre 401, indéfiniment.
      final reponse = await _inner
          .post(
            Uri.parse(ApiRoutes.refresh),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refresh_token': refresh}),
          )
          .timeout(const Duration(seconds: 20));

      debugPrint('║ Réponse refresh : ${reponse.statusCode}');
      debugPrint('║ Corps refresh : ${reponse.body.length > 200 ? reponse.body.substring(0, 200) : reponse.body}');

      final verdict = verdictDuServeur(reponse.statusCode);
      if (verdict != Renouvellement.reussi) {
        debugPrint('║ ⛔ Verdict : $verdict');
        debugPrint('╚════════════════════════════════════════════\n');
        return verdict;
      }

      // Un 200 illisible est une anomalie du serveur, pas une session finie :
      // on ne met personne dehors sur une réponse qu'on n'a pas su lire.
      final corps = jsonDecode(reponse.body);
      if (corps is! Map) return Renouvellement.indisponible;

      final nouveau = corps['token']?.toString();
      if (nouveau == null || nouveau.isEmpty) {
        debugPrint('║ ⛔ Token absent dans la réponse refresh');
        debugPrint('╚════════════════════════════════════════════\n');
        return Renouvellement.indisponible;
      }

      // Le RAFRAÎCHISSEMENT s'écrit en premier, et l'ordre porte tout.
      //
      // Le serveur fait tourner la lignée : dès qu'il a répondu, l'ancien
      // jeton de rafraîchissement est révoqué, et le présenter à nouveau vaut
      // rejeu — `FaireTourner` ferme alors TOUTE la famille. Écrire l'accès en
      // premier laissait donc une fenêtre : l'application tuée entre les deux
      // (mémoire réclamée par le système, plantage) gardait un accès neuf et
      // un rafraîchissement déjà mort, et la session entière tombait au
      // renouvellement suivant — sans que rien ne l'explique.
      //
      // Dans cet ordre-ci, la même interruption laisse un rafraîchissement
      // valide et un accès périmé : le prochain 401 le renouvelle, et personne
      // ne s'aperçoit de rien. `saveRefreshToken` ignore une valeur vide, donc
      // un serveur qui ne renvoie pas le champ n'efface rien.
      await TokenStorage.saveRefreshToken(corps['refresh_token']?.toString());
      await TokenStorage.saveToken(nouveau);
      debugPrint('║ ✅ Session renouvelée avec succès');
      debugPrint('╚════════════════════════════════════════════\n');
      return Renouvellement.reussi;
    } catch (e) {
      // Coupure, délai dépassé, DNS injoignable : on n'a rien appris sur la
      // session. C'était le cas qui déconnectait à tort.
      debugPrint('Renouvellement de session impossible : $e');
      return Renouvellement.indisponible;
    }
  }

  void _declencherDeconnexion() {
    // ── DIAGNOSTIC ──
    debugPrint('\n╔══ ⛔ DÉCONNEXION DÉCLENCHÉE ════════════════');
    debugPrint('║ Stacktrace :');
    debugPrint('║ ${StackTrace.current.toString().split('\n').take(5).join('\n║ ')}');
    debugPrint('╚════════════════════════════════════════════\n');
    final handler = onUnauthorized;
    if (handler == null || _handlingUnauthorized) return;

    _handlingUnauthorized = true;
    handler().whenComplete(() => _handlingUnauthorized = false);
  }

  @override
  void close() {
    _inner.close();
  }
}
