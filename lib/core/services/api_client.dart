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

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    // Les routes d'authentification renvoient légitimement 401 (mauvais mot de
    // passe, OTP invalide) : ce n'est pas une session expirée. Elles n'ont pas
    // non plus besoin qu'on leur pose un jeton.
    final estRouteAuth = request.url.path.contains('/auth/');

    final posePar = request.headers.containsKey('Authorization');
    if (!estRouteAuth && !posePar) {
      await _poserLeJeton(request);
    }

    var reponse = await _envoyer(request);

    if (reponse.statusCode != 401 || estRouteAuth) return reponse;

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

      // Un second 401 avec un jeton tout neuf n'est plus une question de
      // session : l'accès est réellement refusé.
      if (reponse.statusCode == 401) _declencherDeconnexion();
      return reponse;
    }

    // Seul un refus explicite du serveur ferme la session.
    //
    // Une panne, un quota dépassé ou un réseau coupé laissent simplement
    // l'appelant recevoir son échec : il réessaiera, et la session sera
    // toujours là. C'est la différence entre « on vous a déconnecté » et
    // « ça n'est pas passé », et elle se voit à l'écran.
    if (verdict == Renouvellement.refuse) _declencherDeconnexion();

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

      await TokenStorage.saveToken(nouveau);
      await TokenStorage.saveRefreshToken(corps['refresh_token']?.toString());
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
