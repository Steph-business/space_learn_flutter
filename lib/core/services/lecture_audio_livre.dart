import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'package:space_learn_flutter/core/services/book_cache_service.dart';
import 'package:space_learn_flutter/core/services/lecture_audio_handler.dart';
import 'package:space_learn_flutter/core/services/preparation_texte.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/minutes_en_attente.dart';
import 'package:space_learn_flutter/core/services/tts_service.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/bookService.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/readingProgressService.dart';
import 'package:space_learn_flutter/core/utils/token_storage.dart';

/// Écouter un livre sans l'ouvrir.
///
/// La lecture à voix haute n'existait qu'à l'intérieur du lecteur : il fallait
/// ouvrir l'ouvrage, attendre le rendu du PDF, puis lancer l'audio — et garder
/// l'écran sur cette page. Le petit bouton ▶ de la bibliothèque, lui, n'était
/// qu'un dessin : un `Container` avec une icône, sans le moindre geste attaché.
///
/// Ce service fait le même travail que la page de lecture, mais sans écran :
/// il retrouve le fichier, l'ouvre, extrait le texte page par page et
/// l'enchaîne. On peut donc ranger son téléphone et continuer d'écouter.
///
/// Un seul livre à la fois, d'où le singleton : deux lectures simultanées se
/// parleraient par-dessus, et [TtsService] est lui-même unique.
class LectureAudioLivre extends ChangeNotifier {
  LectureAudioLivre._interne();
  static final LectureAudioLivre instance = LectureAudioLivre._interne();

  final TtsService _tts = TtsService();
  final BookCacheService _cache = BookCacheService();
  final ReadingProgressService _progression = ReadingProgressService();

  PdfDocument? _document;

  String? _livreId;
  String _titre = '';
  String _auteur = '';

  /// Le compte au nom duquel la séance a COMMENCÉ.
  ///
  /// Aucun chemin de déconnexion n'arrête ce singleton : la voix continue de
  /// parler sur l'écran de connexion. Or minutes et progression étaient
  /// résolues AU MOMENT de l'écriture (TokenStorage à chaque battement, à
  /// chaque tour de page) : si un utilisateur B se connectait pendant que la
  /// voix de A parlait encore, les minutes d'écoute de A étaient créditées à
  /// B, et la progression du livre de A écrite avec le jeton de B. On mémorise
  /// donc l'identité du début de séance et l'on vérifie, avant CHAQUE
  /// écriture, qu'elle n'a pas changé — sinon on stoppe et on n'écrit rien.
  String? _uidSeance;

  /// Faux quand écrire l'avancée serait un mensonge : progression illisible
  /// au démarrage (on écraserait une position réelle qu'on n'a simplement pas
  /// pu lire), ou livre déjà terminé (réécouter ne doit pas ramener 100 % à
  /// quelques pour cent — le livre sortirait du compteur « livres lus »).
  bool _ecrireLAvancee = true;

  /// Page en cours, à partir de 1 — comme dans le lecteur.
  int _page = 1;
  int _total = 0;

  bool _preparation = false;
  String? _erreur;

  /// Le battement qui porte le temps écouté au compte du lecteur.
  ///
  /// Écouter, c'est lire. Sans ce battement, l'écoute faisait avancer le livre
  /// jusqu'à cent pour cent sans compter une seule minute : quelqu'un qui
  /// écoute chaque jour aurait vu sa série de jours rester à zéro, son temps
  /// cumulé ne pas bouger, et aucun badge d'assiduité se débloquer. Le livre
  /// se terminait tout seul, sans que personne ne l'ait lu.
  ///
  /// Même cadence que le lecteur — quinze secondes — et le même chemin :
  /// [MinutesEnAttente], qui n'envoie que des minutes entières, garde le
  /// reliquat et réessaie ce que le réseau a refusé.
  Timer? _battement;
  DateTime? _dernierBattement;

  /// Vrai pendant le report final déclenché par [arreter].
  ///
  /// Ce report peut constater un changement de compte et vouloir tout couper —
  /// c'est-à-dire rappeler [arreter] alors qu'il s'exécute déjà. Sans ce
  /// témoin, l'arrêt se dédoublait et libérait deux fois le même document.
  bool _arretEnCours = false;

  static const Duration _cadenceDuBattement = Duration(seconds: 15);

  /// Ce qu'on accepte d'attendre pour le dernier report d'une séance.
  ///
  /// La déconnexion attend ce report — c'est ce qui garantit qu'il s'écrit avec
  /// la bonne identité. Elle ne doit pas pour autant attendre le réseau.
  static const Duration _delaiDuReportFinal = Duration(seconds: 5);

  /// Le livre écouté, s'il y en a un.
  String? get livreId => _livreId;
  String get titre => _titre;
  String get auteur => _auteur;
  int get page => _page;
  int get total => _total;

  /// Le fichier est en cours de récupération : c'est le temps d'attente le plus
  /// long, et il mérite d'être annoncé.
  bool get preparation => _preparation;
  String? get erreur => _erreur;

  bool get enLecture => _tts.isPlaying;
  bool get enPause => _tts.isPaused;

  /// Y a-t-il un livre chargé, en lecture ou en pause ?
  bool get actif => _livreId != null;

  bool estLeLivre(String? id) => id != null && id.isNotEmpty && id == _livreId;

  /// Démarre — ou bascule pause/reprise si c'est déjà ce livre.
  ///
  /// Le même bouton sert aux trois gestes : appuyer sur ▶ d'un livre en cours
  /// de lecture doit mettre en pause, pas tout recommencer depuis la page
  /// enregistrée.
  Future<void> basculer(Map<String, dynamic> livre) async {
    final id = (livre['id'] ?? livre['ID'] ?? '').toString();
    if (id.isEmpty) return;

    if (estLeLivre(id)) {
      if (_tts.isPlaying) {
        await _tts.pause();
      } else if (_tts.isPaused) {
        await _tts.resume();
      } else {
        await _direLaPage();
      }
      notifyListeners();
      return;
    }

    await demarrer(livre);
  }

  /// Ouvre un livre et commence à le dire.
  Future<void> demarrer(Map<String, dynamic> livre) async {
    await arreter();

    _livreId = (livre['id'] ?? livre['ID'] ?? '').toString();
    _titre = (livre['titre'] ?? livre['title'] ?? 'Lecture').toString();
    _auteur =
        (livre['auteur_nom'] ?? livre['auteurNom'] ?? livre['auteur'] ?? '')
            .toString();
    // L'identité du lecteur au départ : toute écriture ultérieure la
    // revérifiera (voir _uidSeance).
    _uidSeance = await TokenStorage.getUserId();
    _erreur = null;
    _preparation = true;
    notifyListeners();

    try {
      final octets = await _recupererLeFichier(livre);
      if (octets == null) {
        _echouer("Ce livre n'a pas pu être ouvert.");
        return;
      }

      // Seul le PDF se lit sans écran.
      //
      // L'EPUB passe par un contrôleur lié à un widget : l'extraire ici
      // demanderait une seconde mécanique, et mieux vaut le dire que faire
      // semblant.
      final format = (livre['format'] ?? '').toString().toLowerCase();
      if (format == 'epub') {
        _echouer(
          "L'écoute directe ne fonctionne pas encore sur les livres au format "
          "EPUB. Ouvrez le livre pour l'écouter.",
        );
        return;
      }

      _document = PdfDocument(inputBytes: octets);
      _total = _document!.pages.count;

      // On reprend là où la lecture s'était arrêtée : écouter un livre commencé
      // depuis le début serait une punition.
      _page = await _pageDeReprise();

      _preparation = false;
      notifyListeners();

      lectureAudio?.annoncerLivre(
        titre: _titre,
        auteur: _auteur,
        couverture: (livre['image_couverture'] ?? livre['couverture'] ?? '')
            .toString(),
      );

      _tts.onCompletion = _pageSuivante;
      _tts.addListener(_surEtatTts);

      await _direLaPage();
    } catch (e) {
      debugPrint('Écoute impossible : $e');
      _echouer("Ce livre n'a pas pu être ouvert.");
    }
  }

  Future<void> pause() async {
    // Attendu : le report du reliquat est asynchrone, et le laisser courir
    // derrière la pause revenait à ne jamais savoir s'il a abouti.
    await _arreterLeBattement();
    await _tts.pause();
    notifyListeners();
  }

  Future<void> reprendre() async {
    if (_tts.isPaused) {
      await _tts.resume();
    } else {
      await _direLaPage();
    }
    notifyListeners();
  }

  /// Arrête tout et libère le document.
  Future<void> arreter() async {
    // Le temps écouté est porté au compte AVANT de perdre l'identifiant du
    // livre : après, on ne saurait plus à quel ouvrage l'attribuer.
    //
    // ATTENDU, et c'est le point délicat. Le report était lancé sans être
    // attendu : `arreter()` filait jusqu'à `_uidSeance = null` (plus bas) et
    // jusqu'à rendre la main à son appelant. Deux dégâts, tous deux observés :
    //   - la vérification différée comparait alors un uid réel à `null`,
    //     concluait au changement de compte et JETAIT les dernières secondes —
    //     ouvrir un livre pendant une écoute perdait le reliquat à chaque fois ;
    //   - SessionService.terminer croyait l'écriture faite et effaçait le
    //     jeton ; le report arrivait après, sans identité, et n'écrivait rien.
    _arretEnCours = true;
    try {
      await _arreterLeBattement();
    } finally {
      _arretEnCours = false;
    }
    _tts.removeListener(_surEtatTts);

    // On ne débranche que SI la voix est encore la nôtre.
    //
    // Le lecteur et la bibliothèque partagent le même [TtsService] — il est
    // unique. Ouvrir un livre pendant une écoute installe son propre
    // enchaînement de pages ; effacer aveuglément `onCompletion` ici couperait
    // le sien, et sa lecture s'arrêterait à la fin de la première page sans
    // que rien ne l'explique. L'ordre des deux appels n'a alors plus
    // d'importance, ce qui vaut mieux qu'une règle à retenir.
    if (identical(_tts.onCompletion, _pageSuivante)) {
      _tts.onCompletion = null;
      await _tts.stop();
    }

    // Un PdfDocument garde le fichier entier en mémoire : ne pas le refermer
    // laisserait chaque livre écouté peser jusqu'à la fermeture de
    // l'application.
    _document?.dispose();
    _document = null;

    _livreId = null;
    _titre = '';
    _auteur = '';
    _uidSeance = null;
    _ecrireLAvancee = true;
    _page = 1;
    _total = 0;
    _preparation = false;
    _erreur = null;
    notifyListeners();
  }

  // ── Interne ───────────────────────────────────────────────────────────────

  void _echouer(String message) {
    _preparation = false;
    _erreur = message;
    _livreId = null;
    notifyListeners();
  }

  void _surEtatTts() {
    // Le temps ne court que pendant que ça parle : ni en pause, ni pendant la
    // récupération du fichier, qui peut durer sur une connexion lente et
    // gonflerait le compteur sans qu'une ligne ait été lue.
    if (_tts.isPlaying) {
      _demarrerLeBattement();
    } else {
      // Un écouteur de ChangeNotifier ne rend pas de futur : le report part
      // détaché ici, mais l'identité de la séance lui est déjà passée en
      // paramètre — il n'a plus rien à relire au moment de son exécution.
      unawaited(_arreterLeBattement());
    }
    notifyListeners();
  }

  void _demarrerLeBattement() {
    if (_battement?.isActive ?? false) return;
    _dernierBattement = DateTime.now();
    _battement = Timer.periodic(
      _cadenceDuBattement,
      (_) => unawaited(_porterLeTemps()),
    );
  }

  /// Arrête le battement et porte au compte ce qui restait.
  ///
  /// Sans ce dernier report, une écoute de cinquante secondes suivie d'une
  /// pause ne compterait pour rien : le battement n'aurait pas eu le temps de
  /// tomber une seule fois.
  Future<void> _arreterLeBattement() async {
    if (_battement == null) return;
    _battement?.cancel();
    _battement = null;
    // Attendu, mais pas indéfiniment.
    //
    // [MinutesEnAttente.porter] pose d'abord le solde sur l'appareil, PUIS
    // tente de le vider vers le serveur — et cette tentative peut tenir trente
    // secondes sur un réseau mort. Attendre le tout ferait figer la
    // déconnexion d'autant. Passé ce délai on cesse d'attendre, sans rien
    // perdre : les minutes sont déjà sur le disque et repartiront à la
    // prochaine ouverture d'un livre.
    await _porterLeTemps()
        .catchError((Object e) => debugPrint('Report du temps écouté : $e'))
        .timeout(_delaiDuReportFinal, onTimeout: () {});
    _dernierBattement = null;
  }

  Future<void> _porterLeTemps() async {
    final precedent = _dernierBattement;
    if (precedent == null || _livreId == null) return;

    final maintenant = DateTime.now();
    // On mesure le temps réellement écoulé plutôt que de supposer quinze
    // secondes : en arrière-plan, le système espace les minuteurs, et supposer
    // la cadence sous-compterait d'autant.
    final secondes = maintenant.difference(precedent).inSeconds;
    _dernierBattement = maintenant;

    if (secondes <= 0) return;
    // L'identité attendue est CAPTURÉE ICI, pas relue plus tard.
    //
    // Le report était détaché et relisait `_uidSeance` au moment de son
    // exécution — c'est-à-dire après que `arreter()` l'avait remis à null. La
    // garde d'identité, faite pour protéger le compte, jetait alors les
    // dernières secondes de CHAQUE écoute normalement terminée.
    await _porterAuCompteDeLaSeance(
      uidAttendu: _uidSeance,
      livreId: _livreId,
      secondes: secondes,
    );
  }

  /// Porte les secondes au compte qui écoute, puis coupe la voix si ce compte
  /// n'est plus celui de l'appareil.
  ///
  /// [uidAttendu] vient de l'appelant et non de `_uidSeance` : ce champ est
  /// remis à zéro par [arreter], et le lire ici faisait passer une fin
  /// d'écoute ordinaire pour un changement de compte.
  ///
  /// L'identifiant de séance descend maintenant JUSQU'À L'ÉCRITURE.
  /// [MinutesEnAttente] relisait le compte dans [TokenStorage] au moment de
  /// poser le solde sur l'appareil, et ce moment tombe APRÈS `clearToken` dès
  /// que le report final dépasse [_delaiDuReportFinal] : la déconnexion
  /// n'attend pas au-delà, le report poursuit seul, et il ne trouvait plus
  /// aucun compte à créditer — les dernières minutes de la séance étaient
  /// jetées au lieu de rester en attente. Le compte qui écoute est connu
  /// depuis `demarrer()` ; on le transmet plutôt que de le redécouvrir trop
  /// tard.
  Future<void> _porterAuCompteDeLaSeance({
    required String? uidAttendu,
    String? livreId,
    required int secondes,
  }) async {
    // Une séance ouverte sans compte identifié n'a personne à créditer : ces
    // secondes ne sont pas celles de qui se serait connecté entre-temps.
    if (uidAttendu != null && uidAttendu.isNotEmpty) {
      await MinutesEnAttente.porter(
        livreId: livreId,
        secondes: secondes,
        uid: uidAttendu,
      );
    }

    // La vérification d'identité vient MAINTENANT, après l'écriture : elle ne
    // sert plus à décider où vont les minutes — elles sont nominatives — mais
    // à couper une voix qui aurait survécu à la déconnexion de celui qui
    // l'avait lancée.
    final uid = await TokenStorage.getUserId();
    if (uid != uidAttendu) {
      // Sauf si c'est justement `arreter()` qui nous a appelés : il fait déjà
      // ce travail, et le relancer d'ici le dédoublerait.
      if (!_arretEnCours) await arreter();
    }
  }

  /// Le fichier, depuis le cache ou depuis le serveur.
  ///
  /// Même règle que dans le lecteur : une seule adresse fait foi,
  /// `fichier_url`, et c'est le serveur qui décide de ce qu'elle contient —
  /// le manuscrit entier pour qui possède le livre, l'aperçu sinon.
  Future<Uint8List?> _recupererLeFichier(Map<String, dynamic> livre) async {
    String? url = (livre['fichier_url'] ?? livre['fichierUrl'])?.toString();
    final id = _livreId ?? '';

    if ((url == null || url.isEmpty) && id.isNotEmpty) {
      final token = await TokenStorage.getToken();
      if (token != null && token.isNotEmpty) {
        final frais = await BookService().getBookById(id, authToken: token);
        url = frais.fichierUrl;
      }
    }
    if (url == null || url.isEmpty || id.isEmpty) return null;

    if (await _cache.isBookCached(id, url)) {
      return _cache.getCachedBookBytes(id, url);
    }
    return _cache.downloadAndCache(id, url);
  }

  /// La page où reprendre l'écoute.
  ///
  /// Règle aussi [_ecrireLAvancee] : rendre 1 « par défaut » puis ÉCRIRE
  /// cette page 1 au serveur écrasait la progression réelle — appuyer sur ▶
  /// d'un livre fini (ou écouter pendant un raté transitoire du réseau)
  /// suffisait à réécrire 100 % → ~0 %, et le livre quittait le compteur
  /// « livres lus ».
  Future<int> _pageDeReprise() async {
    try {
      final token = await TokenStorage.getToken();
      if (token == null || _livreId == null) {
        // Sans jeton on ne sait rien de la progression : on n'écrira rien.
        _ecrireLAvancee = false;
        return 1;
      }

      final avancee = await _progression.getProgressByLivre(_livreId!, token);
      if (avancee == null) {
        // Le serveur n'a pas répondu (le service avale ses erreurs et rend
        // null) : « page 1 » n'est qu'un défaut d'affichage, pas une
        // observation. On écoute quand même, mais sans écrire.
        _ecrireLAvancee = false;
        return 1;
      }

      final page = avancee.lastPage;
      // Un livre terminé se réécoute depuis le début : rester bloqué sur la
      // dernière page ne dirait plus rien. Mais sa progression, elle, reste à
      // 100 % — la remettre à zéro ferait reculer « livres lus » et badges.
      if (_total > 0 && page >= _total) {
        _ecrireLAvancee = false;
        return 1;
      }

      _ecrireLAvancee = true;
      if (page <= 0) return 1;
      return page;
    } catch (_) {
      _ecrireLAvancee = false;
      return 1;
    }
  }

  /// Extrait la page courante et la fait dire.
  Future<void> _direLaPage() async {
    final document = _document;
    if (document == null) return;

    // On saute les pages sans texte plutôt que de s'arrêter dessus : une page
    // d'illustration ou une page blanche interromprait sinon l'écoute, et il
    // faudrait rouvrir le livre pour la franchir.
    while (_page <= _total) {
      String texte = '';
      try {
        texte = texteDepuisPdf(
          PdfTextExtractor(
            document,
          ).extractText(startPageIndex: _page - 1, endPageIndex: _page - 1),
        );
      } catch (e) {
        debugPrint('Extraction impossible page $_page : $e');
      }

      if (texte.trim().isNotEmpty) {
        notifyListeners();
        unawaited(_enregistrerLAvancee());
        await _tts.speak(texte);
        return;
      }
      _page++;
    }

    // Plus rien à dire : le livre est fini.
    await arreter();
  }

  /// Appelé quand la page vient d'être dite en entier.
  void _pageSuivante() {
    if (_document == null) return;
    if (_page >= _total) {
      unawaited(arreter());
      return;
    }
    _page++;
    unawaited(_direLaPage());
  }

  /// Écouter, c'est lire : l'avancée suit.
  ///
  /// Sans cela, une heure d'écoute laisserait la progression du livre au même
  /// point, et rouvrir l'ouvrage renverrait le lecteur là où il en était avant
  /// d'écouter.
  Future<void> _enregistrerLAvancee() async {
    if (_livreId == null || _total <= 0) return;
    // Progression de départ inconnue, ou livre déjà terminé : écrire la page
    // courante détruirait une position réelle (voir _pageDeReprise).
    if (!_ecrireLAvancee) return;
    try {
      // Le compte a pu changer depuis le début de la séance : le jeton
      // présent maintenant n'est plus celui du lecteur qui écoute. On stoppe
      // et on n'écrit rien (voir _uidSeance).
      final uid = await TokenStorage.getUserId();
      if (uid != _uidSeance) {
        await arreter();
        return;
      }
      final token = await TokenStorage.getToken();
      if (token == null || token.isEmpty) return;
      await _progression.updateReadingProgress(
        livreId: _livreId!,
        currentPage: _page,
        totalPages: _total,
        authToken: token,
      );
    } catch (e) {
      // Une avancée non enregistrée ne doit pas interrompre l'écoute.
      debugPrint('Avancée non enregistrée : $e');
    }
  }
}
