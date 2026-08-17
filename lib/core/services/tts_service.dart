import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'preparation_texte.dart';

enum TtsState { stopped, playing, paused }

/// État de la voix française sur l'appareil.
///
/// Quand la langue demandée manque, `setLanguage` ne lève rien : il renvoie 0
/// en silence, ne touche pas au moteur, et la lecture continue avec la voix
/// par défaut — donc du français dit avec une voix anglaise. Il faut donc
/// savoir, et pouvoir le dire au lecteur.
enum EtatVoix {
  /// Résolution pas encore terminée.
  inconnu,

  /// Une voix française est en place.
  ok,

  /// Le moteur fonctionne, mais aucune voix française n'est installée.
  absente,

  /// Aucun moteur de synthèse utilisable sur cet appareil.
  moteurIndisponible,
}

/// Lecture d'un livre à voix haute.
///
/// Le service lisait une page ou un chapitre entier en un seul appel à
/// `speak()`. Trois choses en découlaient, toutes silencieuses :
///
///   - au-delà de 4 000 caractères, Android **refuse** l'énoncé. Il ne le
///     tronque pas : il ne dit rien du tout, et aucune erreur ne remonte côté
///     Dart. Un chapitre d'EPUB dépasse couramment cette taille ;
///   - `speak()` commençait par `stop()`, lequel efface la position mémorisée
///     par le moteur. La reprise après pause repartait donc du début ;
///   - `speak()` rappelait `setLanguage()` à chaque page, ce qui annule toute
///     voix épinglée par `setVoice()`.
///
/// D'où le fonctionnement actuel : le texte est découpé en segments courts,
/// le service tient lui-même l'index du segment en cours, et les enchaîne un
/// par un en attendant la fin de chacun.
class TtsService extends ChangeNotifier {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;

  TtsService._internal() {
    _initTts();
  }

  /// Taille visée d'un segment.
  ///
  /// Bien en dessous des 4 000 caractères qu'Android refuse : la marge absorbe
  /// les substitutions que le moteur opère sur le texte, et un segment court
  /// veut aussi dire qu'une reprise mal placée coûte une phrase, pas une page.
  static const int _tailleSegmentVisee = 2500;

  /// L'échelle est celle de flutter_tts, où 0,5 vaut la vitesse normale.
  ///
  /// Ce n'est pas l'échelle native : le greffon multiplie par deux côté
  /// Android pour aligner les deux plateformes. Porter cette valeur à 1,0 en
  /// lisant la seule documentation Android donnerait le double de la vitesse
  /// normale sur Android et le plafond absolu sur iOS.
  static const double vitesseNormale = 0.5;

  late FlutterTts _flutterTts;
  TtsState _state = TtsState.stopped;
  double _speechRate = vitesseNormale;
  double _pitch = 1.0;
  String _language = 'fr-FR';
  List<String> _languages = [];
  bool _isInitialized = false;

  EtatVoix _etatVoix = EtatVoix.inconnu;
  String? _nomVoix;

  /// Les voix francaises installees sur l'appareil, la meilleure d'abord.
  ///
  /// Le service en choisissait une et gardait la liste pour lui. Or les
  /// moteurs en proposent souvent plusieurs — masculine, feminine, de qualites
  /// differentes — et laquelle « sonne bien » ne se decide pas depuis le code :
  /// cela s'ecoute.
  List<Map<String, String>> _voixDisponibles = const [];

  /// Plafond réellement accepté, lu sur l'appareil.
  ///
  /// Android accepte jusqu'à 1,5 sur l'échelle du greffon ; iOS écrête tout
  /// au-dessus de 1,0 sans le signaler. Coder les paliers en dur revient donc
  /// à mentir sur l'une des deux plateformes.
  double _vitesseMax = 1.0;

  /// Segments du texte en cours, et position dans cette liste.
  List<String> _segments = const [];
  int _segmentCourant = 0;
  bool _arretDemande = false;

  /// Numéro de la boucle de lecture en cours.
  ///
  /// `_dire()` s'attend à être seul. Or trois chemins le relancent alors qu'une
  /// boucle tourne déjà — un changement de voix, un saut de segment, une
  /// reprise. `_arretDemande` ne suffit pas à congédier l'ancienne : la
  /// nouvelle boucle commence par le remettre à faux, si bien que l'ancienne,
  /// réveillée entre-temps par le `stop()`, ne voyait plus aucune raison de
  /// s'arrêter. Deux boucles avançaient alors sur leurs propres compteurs, et
  /// comme `speak()` travaille en QUEUE_FLUSH, chacune coupait la phrase de
  /// l'autre indéfiniment.
  ///
  /// Chaque boucle retient son numéro. Dès qu'un autre lui succède, elle sort.
  int _generation = 0;

  /// Vrai quand ce qui est dit est un échantillon de voix, pas le livre.
  ///
  /// La fin d'une lecture tourne la page. Sans cette distinction, écouter
  /// quatre voix dans les réglages faisait avancer le livre de quatre pages,
  /// position enregistrée au passage.
  bool _apercu = false;

  TtsState get state => _state;
  bool get isPlaying => _state == TtsState.playing;
  bool get isPaused => _state == TtsState.paused;
  bool get isStopped => _state == TtsState.stopped;
  double get speechRate => _speechRate;
  double get pitch => _pitch;
  String get language => _language;
  List<String> get languages => _languages;
  bool get isInitialized => _isInitialized;

  EtatVoix get etatVoix => _etatVoix;
  String? get nomVoix => _nomVoix;
  List<Map<String, String>> get voixDisponibles => _voixDisponibles;
  bool get voixFrancaiseDisponible => _etatVoix == EtatVoix.ok;
  double get vitesseMax => _vitesseMax;

  /// Avancement dans le texte en cours, de 0 à 1.
  double get avancement {
    if (_segments.isEmpty) return 0;
    return (_segmentCourant + 1) / _segments.length;
  }

  VoidCallback? onCompletion;
  VoidCallback? onStart;
  VoidCallback? onPause;
  VoidCallback? onStop;

  Future<void> _initTts() async {
    _flutterTts = FlutterTts();

    await _configurerIOS();

    _flutterTts.setStartHandler(() {
      _state = TtsState.playing;
      notifyListeners();
      onStart?.call();
    });

    // La fin d'un segment n'est pas la fin de la lecture : la boucle de
    // _dire() enchaîne. On ne prévient l'appelant qu'une fois le dernier
    // segment passé, sans quoi la page suivante se déclencherait à chaque
    // phrase.
    _flutterTts.setCancelHandler(() {
      _state = TtsState.stopped;
      notifyListeners();
      onStop?.call();
    });

    _flutterTts.setErrorHandler((msg) {
      // Sans ce gestionnaire, le refus d'un énoncé trop long est totalement
      // muet côté Dart : le message n'existe que dans le journal Android.
      debugPrint('Erreur TTS : $msg');
      _state = TtsState.stopped;
      notifyListeners();
    });

    _flutterTts.setPauseHandler(() {
      _state = TtsState.paused;
      notifyListeners();
      onPause?.call();
    });

    _flutterTts.setContinueHandler(() {
      _state = TtsState.playing;
      notifyListeners();
      onStart?.call();
    });

    // Indispensable : sans cela, `await speak()` rend la main aussitôt et la
    // boucle enverrait tous les segments en une milliseconde, ce qui ferait
    // perdre tout point de contrôle. Ne fonctionne qu'en mode QUEUE_FLUSH,
    // qui est le mode par défaut — ne pas y toucher.
    try {
      await _flutterTts.awaitSpeakCompletion(true);
    } catch (e) {
      debugPrint("awaitSpeakCompletion indisponible : $e");
    }

    await _lireLaPlageDeVitesse();
    // Après la plage : l'écrêtage dépend du plafond de l'appareil.
    await _relireLaVitesse();
    await _resoudreVoixFrancaise();

    try {
      await _flutterTts.setSpeechRate(_speechRate);
      await _flutterTts.setPitch(_pitch);
    } catch (e) {
      debugPrint("Réglages TTS par défaut refusés : $e");
    }

    _isInitialized = true;
    notifyListeners();
  }

  Future<void> _configurerIOS() async {
    if (kIsWeb || !Platform.isIOS) return;
    try {
      await _flutterTts.setSharedInstance(true);
      // `defaultToSpeaker` est incompatible avec la catégorie `playback` et
      // fait échouer toute la configuration de session — en silence, le
      // greffon avalant l'exception. Le son ne survivait alors pas à
      // l'arrière-plan sans que rien ne l'explique.
      await _flutterTts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
          IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
        ],
        IosTextToSpeechAudioMode.defaultMode,
      );
    } catch (e) {
      debugPrint("Configuration de la session audio iOS impossible : $e");
    }
  }

  /// Lit sur l'appareil la plage de vitesse réellement acceptée.
  Future<void> _lireLaPlageDeVitesse() async {
    try {
      final plage = await _flutterTts.getSpeechRateValidRange;
      final max = plage.max;
      if (max > 0) _vitesseMax = max;
    } catch (e) {
      debugPrint("Plage de vitesse indisponible, plafond à 1,0 : $e");
    }
  }

  /// Choisit une voix française explicite, plutôt que d'espérer.
  ///
  /// `setLanguage('fr-FR')` ne suffit pas : il renvoie 0 sans rien dire quand
  /// la langue manque, et `isLanguageAvailable` répond vrai dès qu'un français
  /// d'un autre pays existe, voire quand la voix est déclarée sans que ses
  /// données soient téléchargées.
  Future<void> _resoudreVoixFrancaise() async {
    try {
      final brut = await _flutterTts.getVoices.timeout(
        const Duration(seconds: 5),
        // Un appareil sans moteur de synthèse ne répond jamais : sans ce
        // délai, l'initialisation reste bloquée pour toujours.
        onTimeout: () => null,
      );

      if (brut == null) {
        _etatVoix = EtatVoix.moteurIndisponible;
        return;
      }

      final voix = (brut as List)
          .whereType<Map>()
          .map((v) => v.map((k, val) => MapEntry('$k', '$val')))
          .where(_estFrancaiseEtInstallee)
          .toList();

      if (voix.isEmpty) {
        _etatVoix = EtatVoix.absente;
        return;
      }

      voix.sort(_meilleureEnPremier);
      _voixDisponibles = voix;

      // Le choix du lecteur l'emporte sur le classement, s'il tient encore :
      // une voix desinstallee depuis ne doit pas laisser la lecture muette.
      final prefs = await SharedPreferences.getInstance();
      final memorisee = prefs.getString(_cleVoix);
      final choisie = voix.firstWhere(
        (v) => v['name'] == memorisee,
        orElse: () => voix.first,
      );

      _etatVoix = await _appliquerVoix(choisie)
          ? EtatVoix.ok
          : EtatVoix.absente;
    } catch (e) {
      debugPrint("Résolution de la voix française impossible : $e");
      _etatVoix = EtatVoix.moteurIndisponible;
    }
  }

  static const String _cleVoix = 'tts_voix_choisie';

  Future<bool> _appliquerVoix(Map<String, String> voix) async {
    final retenu = await _flutterTts.setVoice({
      'name': voix['name'] ?? '',
      'locale': voix['locale'] ?? 'fr-FR',
    });
    if (retenu != 1) return false;
    _nomVoix = voix['name'];
    _language = voix['locale'] ?? 'fr-FR';
    return true;
  }

  /// Change de voix, et retient le choix.
  ///
  /// La lecture en cours est relancee sur le segment courant : changer de voix
  /// au milieu d'un paragraphe sans rien reprendre laisserait le lecteur sur
  /// une phrase coupee, dans l'ancienne voix.
  Future<bool> choisirVoix(Map<String, String> voix) async {
    final ok = await _appliquerVoix(voix);
    if (!ok) return false;

    // Une voix qui s'applique est une voix française en place.
    //
    // L'état restait sur `absente` quand la résolution du démarrage avait
    // échoué : le lecteur choisissait une voix, entendait son échantillon, et
    // le bouton de lecture continuait de refuser en affichant « aucune voix
    // française installée ». Rien dans l'application ne permettait d'en sortir.
    _etatVoix = EtatVoix.ok;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cleVoix, voix['name'] ?? '');

    if (_state == TtsState.playing && _segments.isNotEmpty) {
      final reprise = _segmentCourant;
      // Congédier la boucle en cours avant d'en ouvrir une autre. Sans ce
      // drapeau, l'ancienne repartait sur le segment suivant pendant que la
      // nouvelle reprenait le courant.
      _arretDemande = true;
      await _flutterTts.stop();
      _segmentCourant = reprise;
      await _dire();
    }
    notifyListeners();
    return true;
  }

  /// Réexamine les voix installées sur l'appareil.
  ///
  /// La résolution n'avait lieu qu'une fois, dans le constructeur du singleton.
  /// Le lecteur à qui l'application conseillait d'installer une voix française
  /// l'installait, revenait — et lisait le même message : il fallait tuer
  /// l'application pour que la nouvelle voix soit vue. Même chose après une
  /// mise à jour du moteur, ou quand `getVoices` avait dépassé son délai de
  /// cinq secondes au démarrage d'un appareil lent, ce qui condamnait la
  /// lecture pour toute la session sur un verdict provisoire.
  Future<void> reexaminerLesVoix() async {
    await _resoudreVoixFrancaise();
    notifyListeners();
  }

  bool _estFrancaiseEtInstallee(Map<String, String> v) {
    final locale = (v['locale'] ?? '').toLowerCase();
    if (!locale.startsWith('fr')) return false;
    // Une voix qui exige le réseau ne sert pas un lecteur hors couverture.
    if (v['network_required'] == '1') return false;
    final traits = (v['features'] ?? '').split('\t');
    if (traits.contains('notInstalled')) return false;
    return true;
  }

  /// Meilleure qualité d'abord, puis le français de France.
  int _meilleureEnPremier(Map<String, String> a, Map<String, String> b) {
    const rangs = {
      'very high': 0,
      'high': 1,
      'normal': 2,
      'low': 3,
      'very low': 4,
    };
    final qa = rangs[(a['quality'] ?? '').toLowerCase()] ?? 2;
    final qb = rangs[(b['quality'] ?? '').toLowerCase()] ?? 2;
    if (qa != qb) return qa.compareTo(qb);

    final fa = (a['locale'] ?? '').toLowerCase().startsWith('fr-fr') ? 0 : 1;
    final fb = (b['locale'] ?? '').toLowerCase().startsWith('fr-fr') ? 0 : 1;
    return fa.compareTo(fb);
  }

  /// Lit un texte, du début.
  ///
  /// Le texte est découpé, puis dit segment par segment. Un `stop()` explicite
  /// précède la lecture : c'est ce qui la distingue d'une reprise, laquelle
  /// ne doit surtout pas arrêter le moteur.
  /// [apercu] : un échantillon de voix, qui ne doit pas faire tourner la page.
  Future<void> speak(String text, {bool apercu = false}) async {
    if (text.trim().isEmpty) return;
    if (_etatVoix == EtatVoix.moteurIndisponible) return;

    await stop();
    _apercu = apercu;
    _segments = decouperPourLecture(text, maxCaracteres: _tailleSegmentVisee);
    _segmentCourant = 0;
    if (_segments.isEmpty) return;

    await _dire();
  }

  /// Enchaîne les segments à partir de [_segmentCourant].
  Future<void> _dire() async {
    final moi = ++_generation;
    _arretDemande = false;
    _state = TtsState.playing;
    notifyListeners();

    for (var i = _segmentCourant; i < _segments.length; i++) {
      // Deux raisons de sortir : on a demandé l'arrêt, ou une autre boucle a
      // pris la suite. La seconde n'était pas testée, et laissait deux voix
      // se disputer le moteur.
      if (_arretDemande || moi != _generation) return;
      _segmentCourant = i;
      try {
        await _flutterTts.speak(_segments[i]);
      } catch (e) {
        debugPrint("Lecture du segment $i impossible : $e");
        if (moi != _generation) return;
        _state = TtsState.stopped;
        notifyListeners();
        return;
      }
      if (_arretDemande || moi != _generation) return;
    }

    if (moi != _generation) return;

    final cetaitUnApercu = _apercu;
    _state = TtsState.stopped;
    _segments = const [];
    _segmentCourant = 0;
    _apercu = false;
    notifyListeners();
    if (!cetaitUnApercu) onCompletion?.call();
  }

  /// Suspend la lecture sans perdre la position.
  Future<void> pause() async {
    if (_state != TtsState.playing) return;
    // Le drapeau évite que la boucle n'enchaîne le segment suivant dès que
    // l'énoncé en cours rend la main.
    _arretDemande = true;
    try {
      await _flutterTts.pause();
    } catch (e) {
      debugPrint("Mise en pause impossible : $e");
    }
    _state = TtsState.paused;
    notifyListeners();
  }

  /// Reprend là où la lecture s'était arrêtée.
  ///
  /// Sans `stop()` préalable : c'est précisément lui qui effaçait la position
  /// et faisait repartir du début. Au pire — Android antérieur à 8, ou iOS —
  /// la reprise recommence le segment courant, soit une phrase ou deux, pas
  /// une page entière.
  Future<void> resume() async {
    if (_state != TtsState.paused || _segments.isEmpty) return;
    await _dire();
  }

  /// Passe au segment suivant, sans attendre la fin du courant.
  ///
  /// Sur une lecture à voix haute, « avancer de trente secondes » ne veut rien
  /// dire : on ignore où cela tombe, et cela coupe au milieu d'un mot. Sauter
  /// à la phrase suivante, si.
  Future<void> segmentSuivant() async {
    if (_segments.isEmpty) return;
    if (_segmentCourant >= _segments.length - 1) return;
    await _sauterVers(_segmentCourant + 1);
  }

  /// Revient au segment précédent.
  Future<void> segmentPrecedent() async {
    if (_segments.isEmpty) return;
    if (_segmentCourant <= 0) return;
    await _sauterVers(_segmentCourant - 1);
  }

  Future<void> _sauterVers(int index) async {
    final reprendre = _state != TtsState.stopped;
    // Interrompre l'énoncé en cours sans perdre la liste des segments : le
    // `stop()` public la vide, ce qu'on ne veut pas ici.
    _arretDemande = true;
    try {
      await _flutterTts.stop();
    } catch (e) {
      debugPrint("Saut de segment : arrêt impossible : $e");
    }
    _segmentCourant = index;
    notifyListeners();
    if (reprendre) await _dire();
  }

  Future<void> stop() async {
    _arretDemande = true;
    try {
      await _flutterTts.stop();
    } catch (e) {
      debugPrint("Arrêt impossible : $e");
    }
    _segments = const [];
    _segmentCourant = 0;
    _state = TtsState.stopped;
    notifyListeners();
  }

  Future<void> setRate(double rate) async {
    // Écrêter ici plutôt que de laisser iOS le faire en silence : au-delà de
    // son plafond, le réglage « fonctionne » sans que la vitesse ne change.
    _speechRate = rate.clamp(0.1, _vitesseMax);
    try {
      await _flutterTts.setSpeechRate(_speechRate);
    } catch (e) {
      debugPrint("Réglage de la vitesse refusé : $e");
    }
    // La voix choisie était retenue, la vitesse non : le lecteur qui trouve la
    // lecture trop rapide refaisait le réglage à chaque ouverture de livre.
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_cleVitesse, _speechRate);
    } catch (e) {
      debugPrint("Vitesse non mémorisée : $e");
    }
    notifyListeners();
  }

  static const String _cleVitesse = 'tts_vitesse';

  Future<void> _relireLaVitesse() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final memorisee = prefs.getDouble(_cleVitesse);
      if (memorisee != null && memorisee > 0) {
        _speechRate = memorisee.clamp(0.1, _vitesseMax);
      }
    } catch (e) {
      debugPrint("Vitesse mémorisée illisible : $e");
    }
  }

  Future<void> setPitch(double pitch) async {
    _pitch = pitch;
    try {
      await _flutterTts.setPitch(_pitch);
    } catch (e) {
      debugPrint("Réglage de la tonalité refusé : $e");
    }
    notifyListeners();
  }

  /// Change de langue explicitement.
  ///
  /// À n'appeler que sur un choix du lecteur. `setLanguage` détruit la voix
  /// épinglée par `setVoice` — côté iOS le greffon met `voice = nil`, côté
  /// Android la langue réaffecte la voix par défaut du pays. C'est pourquoi
  /// [speak] ne l'appelle plus : il le faisait à chaque page, ce qui annulait
  /// la voix choisie au démarrage.
  Future<void> setLanguage(String lang) async {
    _language = lang;
    try {
      final retenu = await _flutterTts.setLanguage(_language);
      if (retenu != 1) {
        debugPrint("Langue $lang non disponible (retour $retenu)");
        _etatVoix = EtatVoix.absente;
      }
    } catch (e) {
      debugPrint("Réglage de la langue refusé : $e");
    }
    notifyListeners();
  }
}
