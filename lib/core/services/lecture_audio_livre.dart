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

  static const Duration _cadenceDuBattement = Duration(seconds: 15);

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
    _arreterLeBattement();
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
    _arreterLeBattement();
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
      _arreterLeBattement();
    }
    notifyListeners();
  }

  void _demarrerLeBattement() {
    if (_battement?.isActive ?? false) return;
    _dernierBattement = DateTime.now();
    _battement = Timer.periodic(_cadenceDuBattement, (_) => _porterLeTemps());
  }

  /// Arrête le battement et porte au compte ce qui restait.
  ///
  /// Sans ce dernier report, une écoute de cinquante secondes suivie d'une
  /// pause ne compterait pour rien : le battement n'aurait pas eu le temps de
  /// tomber une seule fois.
  void _arreterLeBattement() {
    if (_battement == null) return;
    _battement?.cancel();
    _battement = null;
    _porterLeTemps();
    _dernierBattement = null;
  }

  void _porterLeTemps() {
    final precedent = _dernierBattement;
    if (precedent == null || _livreId == null) return;

    final maintenant = DateTime.now();
    // On mesure le temps réellement écoulé plutôt que de supposer quinze
    // secondes : en arrière-plan, le système espace les minuteurs, et supposer
    // la cadence sous-compterait d'autant.
    final secondes = maintenant.difference(precedent).inSeconds;
    _dernierBattement = maintenant;

    if (secondes <= 0) return;
    unawaited(MinutesEnAttente.porter(livreId: _livreId, secondes: secondes));
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
  Future<int> _pageDeReprise() async {
    try {
      final token = await TokenStorage.getToken();
      if (token == null || _livreId == null) return 1;

      final avancee = await _progression.getProgressByLivre(_livreId!, token);
      final page = avancee?.lastPage ?? 0;
      // Un livre terminé se réécoute depuis le début : rester bloqué sur la
      // dernière page ne dirait plus rien.
      if (page <= 0 || page >= _total) return 1;
      return page;
    } catch (_) {
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
    try {
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
