import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';

import 'tts_service.dart';

/// Fait vivre la lecture à voix haute hors de l'écran.
///
/// Sans ce pont, la synthèse s'arrêtait dès que l'application passait en
/// arrière-plan ou que l'écran s'éteignait. Le contournement en place était
/// `WakelockPlus`, qui force l'écran à rester allumé : téléphone déverrouillé
/// dans la main et batterie qui fond, soit l'inverse de ce qu'on attend d'un
/// livre qu'on écoute.
///
/// Ce gestionnaire déclare la lecture au système. Android en fait un service
/// de premier plan avec sa notification, iOS une session audio d'arrière-plan,
/// et les deux affichent les commandes sur l'écran verrouillé et répondent aux
/// boutons du casque.
///
/// Il ne synthétise rien lui-même : il relaie [TtsService], qui reste la seule
/// pièce à savoir découper un texte et tenir sa position.
class LectureAudioHandler extends BaseAudioHandler {
  LectureAudioHandler(this._tts) {
    // L'état publié suit celui du service, et non l'inverse : le lecteur peut
    // agir depuis la page comme depuis l'écran verrouillé, et les deux doivent
    // montrer la même chose.
    _tts.addListener(_publierEtat);
    _publierEtat();
  }

  final TtsService _tts;

  /// Ce que la notification annonce. Renseigné à l'ouverture d'un livre.
  Future<void> annoncerLivre({
    required String titre,
    required String auteur,
    String? couverture,
  }) async {
    mediaItem.add(
      MediaItem(
        id: titre,
        title: titre,
        artist: auteur,
        artUri: (couverture != null && couverture.isNotEmpty)
            ? Uri.tryParse(couverture)
            : null,
        // La durée d'une synthèse n'est pas connue d'avance : on ne l'annonce
        // pas plutôt que d'afficher une barre qui ment.
        duration: null,
      ),
    );
  }

  void _publierEtat() {
    final enLecture = _tts.isPlaying;
    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.rewind,
          if (enLecture) MediaControl.pause else MediaControl.play,
          MediaControl.stop,
          MediaControl.fastForward,
        ],
        systemActions: const {
          MediaAction.play,
          MediaAction.pause,
          MediaAction.stop,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: _tts.isStopped
            ? AudioProcessingState.idle
            : AudioProcessingState.ready,
        playing: enLecture,
      ),
    );
  }

  @override
  Future<void> play() async {
    // Reprendre plutôt que recommencer : c'est la distinction que le service
    // sait faire, et le bouton de l'écran verrouillé doit s'y conformer.
    if (_tts.isPaused) {
      await _tts.resume();
    }
  }

  @override
  Future<void> pause() => _tts.pause();

  @override
  Future<void> stop() async {
    await _tts.stop();
    await super.stop();
  }

  /// Les deux flèches servent à sauter un morceau de texte.
  ///
  /// Sur une lecture à voix haute, avancer de trente secondes n'a pas de sens
  /// — on ne sait pas où cela tombe. Sauter au segment suivant, si.
  @override
  Future<void> fastForward() => _tts.segmentSuivant();

  @override
  Future<void> rewind() => _tts.segmentPrecedent();

  @override
  Future<void> onTaskRemoved() async {
    // L'application balayée hors des tâches récentes : on arrête, sinon une
    // voix continue de parler sans qu'aucun écran ne permette de l'arrêter.
    await stop();
  }

  /// Détache l'écoute du service.
  ///
  /// Pas un `dispose` : `BaseAudioHandler` n'en déclare aucun, et le
  /// gestionnaire vit aussi longtemps que l'application. La méthode existe
  /// pour les tests, qui doivent pouvoir rendre le service à son état neuf.
  void detacher() {
    _tts.removeListener(_publierEtat);
  }
}

/// Le gestionnaire, une fois branché au système.
///
/// Nul tant que [demarrerLectureAudio] n'a pas abouti — sur un appareil où le
/// service ne peut pas démarrer, la lecture doit rester possible dans l'écran,
/// simplement sans arrière-plan.
LectureAudioHandler? lectureAudio;

/// Branche la lecture au système. À appeler une fois, au démarrage.
Future<void> demarrerLectureAudio() async {
  if (lectureAudio != null) return;
  try {
    lectureAudio = await AudioService.init(
      builder: () => LectureAudioHandler(TtsService()),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.spacelearn.lecture',
        androidNotificationChannelName: 'Lecture à voix haute',
        androidNotificationChannelDescription:
            'Commandes de la lecture en cours',
        // La notification reste tant qu'un livre est en cours : c'est elle qui
        // maintient le service en vie quand l'écran s'éteint.
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      ),
    );
  } catch (e) {
    // Un échec ici ne doit pas empêcher l'application de démarrer : la lecture
    // fonctionnera comme avant, écran allumé.
    debugPrint("Service de lecture en arrière-plan indisponible : $e");
  }
}
