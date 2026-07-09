import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

enum TtsState { stopped, playing, paused }

class TtsService extends ChangeNotifier {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;

  TtsService._internal() {
    _initTts();
  }

  late FlutterTts _flutterTts;
  TtsState _state = TtsState.stopped;
  double _speechRate = 0.5; // Vitesse de lecture par défaut
  double _pitch = 1.0;
  String _language = 'fr-FR';
  List<String> _languages = [];
  bool _isInitialized = false;

  TtsState get state => _state;
  bool get isPlaying => _state == TtsState.playing;
  bool get isPaused => _state == TtsState.paused;
  bool get isStopped => _state == TtsState.stopped;
  double get speechRate => _speechRate;
  double get pitch => _pitch;
  String get language => _language;
  List<String> get languages => _languages;
  bool get isInitialized => _isInitialized;

  VoidCallback? onCompletion;
  VoidCallback? onStart;
  VoidCallback? onPause;
  VoidCallback? onStop;

  Future<void> _initTts() async {
    _flutterTts = FlutterTts();

    try {
      if (!kIsWeb && Platform.isIOS) {
        await _flutterTts.setSharedInstance(true);
        await _flutterTts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          [
            IosTextToSpeechAudioCategoryOptions.allowBluetooth,
            IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
            IosTextToSpeechAudioCategoryOptions.mixWithOthers,
            IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
          ],
          IosTextToSpeechAudioMode.defaultMode,
        );
      }
    } catch (e) {
      debugPrint("Erreur lors de la configuration de l'audio session iOS: $e");
    }

    _flutterTts.setStartHandler(() {
      _state = TtsState.playing;
      notifyListeners();
      if (onStart != null) onStart!();
    });

    _flutterTts.setCompletionHandler(() {
      _state = TtsState.stopped;
      notifyListeners();
      if (onCompletion != null) onCompletion!();
    });

    _flutterTts.setCancelHandler(() {
      _state = TtsState.stopped;
      notifyListeners();
      if (onStop != null) onStop!();
    });

    _flutterTts.setErrorHandler((msg) {
      _state = TtsState.stopped;
      notifyListeners();
      debugPrint("Erreur TTS: $msg");
    });

    _flutterTts.setPauseHandler(() {
      _state = TtsState.paused;
      notifyListeners();
      if (onPause != null) onPause!();
    });

    _flutterTts.setContinueHandler(() {
      _state = TtsState.playing;
      notifyListeners();
      if (onStart != null) onStart!();
    });

    // Configuration par défaut
    try {
      await _flutterTts.setLanguage(_language);
      await _flutterTts.setSpeechRate(_speechRate);
      await _flutterTts.setPitch(_pitch);
    } catch (e) {
      debugPrint("Erreur lors de l'application des réglages TTS par défaut: $e");
    }

    try {
      final dynamic langs = await _flutterTts.getLanguages;
      if (langs != null) {
        _languages = List<String>.from(langs);
      }
    } catch (e) {
      debugPrint("Erreur lors de la récupération des langues: $e");
    }

    _isInitialized = true;
    notifyListeners();
  }

  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;

    try {
      await _flutterTts.stop();
      await _flutterTts.setLanguage(_language);
      await _flutterTts.setSpeechRate(_speechRate);
      await _flutterTts.setPitch(_pitch);
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint("Erreur lors de l'exécution de speak: $e");
      _state = TtsState.stopped;
      notifyListeners();
    }
  }

  Future<void> pause() async {
    try {
      await _flutterTts.pause();
      _state = TtsState.paused;
      notifyListeners();
    } catch (e) {
      debugPrint("Erreur lors de la mise en pause: $e");
    }
  }

  Future<void> stop() async {
    try {
      await _flutterTts.stop();
      _state = TtsState.stopped;
      notifyListeners();
    } catch (e) {
      debugPrint("Erreur lors de l'arrêt: $e");
    }
  }

  Future<void> setRate(double rate) async {
    _speechRate = rate;
    try {
      await _flutterTts.setSpeechRate(_speechRate);
    } catch (e) {
      debugPrint("Erreur lors du réglage de la vitesse: $e");
    }
    notifyListeners();
  }

  Future<void> setPitch(double pitch) async {
    _pitch = pitch;
    try {
      await _flutterTts.setPitch(_pitch);
    } catch (e) {
      debugPrint("Erreur lors du réglage de la tonalité: $e");
    }
    notifyListeners();
  }

  Future<void> setLanguage(String lang) async {
    _language = lang;
    try {
      await _flutterTts.setLanguage(_language);
    } catch (e) {
      debugPrint("Erreur lors du réglage de la langue: $e");
    }
    notifyListeners();
  }
}
