import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Garde-fous de la lecture à voix haute.
///
/// Le moteur de synthèse n'existe pas dans l'environnement de test : on ne peut
/// pas faire parler `TtsService` ici. Ces règles lisent donc le code source,
/// comme le fait déjà `coherence_couleurs_test.dart`. Chacune correspond à un
/// défaut constaté, pas à une préférence.
void main() {
  String lire(String chemin) {
    final f = File(chemin);
    if (!f.existsSync()) fail('Fichier introuvable : $chemin — le test doit tourner à la racine du projet.');
    return f.readAsStringSync();
  }

  // ── Le panneau ne mélange plus deux systèmes de couleurs ────────────────
  //
  // Son encre venait de la luminance de `_backgroundColor`, le fond du LIVRE,
  // réglé séparément du thème de l'application. Thème sombre avec le fond
  // parchemin — le réglage par défaut — donnait readingBrown #4A3728 sur
  // cardDark #1A1A1A, soit 1,42:1. Thème clair avec le fond « Nuit » donnait
  // du blanc sur #FFFFFF, soit 1:1. Le panneau s'affichait, illisible.
  test("le panneau audio ne tire pas son encre du fond de page", () {
    final source = lire(
      'lib/core/space_learn/pages/widgets/details/reading_page.dart',
    );

    final debut = source.indexOf('Widget _buildTtsPlayerPanel()');
    expect(debut, greaterThan(0), reason: '_buildTtsPlayerPanel introuvable');

    final fin = source.indexOf('/// Paliers de vitesse', debut);
    final corps = source.substring(debut, fin > debut ? fin : source.length);

    expect(
      corps.contains('_backgroundColor.computeLuminance()'),
      isFalse,
      reason:
          'Le panneau flotte au-dessus de la page : son encre doit venir de sa '
          'propre surface (AppColors.textPrimary sur cardBackground), pas de la '
          'luminance du fond de lecture, qui est réglé indépendamment.',
    );
  });

  // ── Une seule boucle de lecture à la fois ───────────────────────────────
  //
  // `_dire()` était relancé par le changement de voix, le saut de segment et la
  // reprise alors qu'une boucle tournait déjà. Comme chaque boucle commence par
  // remettre `_arretDemande` à faux, l'ancienne ne voyait plus de raison de
  // s'arrêter : deux voix se coupaient l'une l'autre indéfiniment.
  test("_dire() congédie la boucle précédente", () {
    final source = lire('lib/core/services/tts_service.dart');

    expect(
      source.contains('final moi = ++_generation;'),
      isTrue,
      reason: '_dire() doit prendre un numéro de génération en entrant.',
    );

    final debut = source.indexOf('Future<void> _dire() async {');
    final fin = source.indexOf('Future<void> pause()', debut);
    final corps = source.substring(debut, fin);

    // Trois sorties : avant l'énoncé, après l'énoncé, et avant la complétion.
    expect(
      'moi != _generation'.allMatches(corps).length,
      greaterThanOrEqualTo(3),
      reason:
          'Chaque point de contrôle de la boucle doit vérifier qu\'une autre '
          'boucle n\'a pas pris la suite.',
    );
  });

  // ── Un échantillon de voix n'est pas une page lue ───────────────────────
  //
  // La fin d'une lecture tourne la page. L'échantillon empruntait le même
  // chemin : écouter quatre voix dans les réglages faisait avancer le livre de
  // quatre pages, et la position partait vers le serveur.
  test("l'échantillon de voix ne déclenche pas la page suivante", () {
    final service = lire('lib/core/services/tts_service.dart');

    expect(
      service.contains('speak(String text, {bool apercu = false})'),
      isTrue,
      reason: 'speak() doit pouvoir distinguer un échantillon d\'une lecture.',
    );
    expect(
      service.contains('if (!cetaitUnApercu) onCompletion?.call();'),
      isTrue,
      reason: 'La complétion ne doit être signalée que pour une vraie lecture.',
    );

    final ecran = lire(
      'lib/core/space_learn/pages/widgets/details/reading_page.dart',
    );
    expect(
      ecran.contains('apercu: true'),
      isTrue,
      reason: 'Le sélecteur de voix doit demander un aperçu.',
    );
  });

  // ── La lecture suivie enchaîne vraiment ─────────────────────────────────
  //
  // `_dire()` remet l'état à `stopped` AVANT d'appeler `onCompletion`. La page
  // tournait donc, puis `_onPageChanged` demandait « le service lit-il ? »,
  // s'entendait répondre non, et la voix se taisait. Il fallait rappuyer sur
  // lecture à chaque page — c'est-à-dire renoncer à écouter sans toucher.
  test("la lecture automatique reprend sur la page suivante", () {
    final ecran = lire(
      'lib/core/space_learn/pages/widgets/details/reading_page.dart',
    );

    expect(
      ecran.contains('_enchainerSurLaPageSuivante = true;'),
      isTrue,
      reason: 'La fin d\'une page doit annoncer qu\'elle enchaîne.',
    );
    expect(
      ecran.contains(
        'if (_ttsService.isPlaying || _enchainerSurLaPageSuivante)',
      ),
      isTrue,
      reason:
          '_onPageChanged ne peut pas se fier au seul état du service : il est '
          'déjà repassé à « arrêté » quand la complétion est signalée.',
    );
  });

  // ── Choisir une voix débloque la lecture ────────────────────────────────
  test("choisirVoix rétablit l'état de la voix", () {
    final source = lire('lib/core/services/tts_service.dart');
    final debut = source.indexOf('Future<bool> choisirVoix(');
    final fin = source.indexOf('Future<void> reexaminerLesVoix()', debut);
    final corps = source.substring(debut, fin);

    expect(
      corps.contains('_etatVoix = EtatVoix.ok;'),
      isTrue,
      reason:
          'Sans cela, le lecteur choisissait une voix, entendait son '
          'échantillon, et le bouton lecture continuait de refuser.',
    );
  });

  // ── La vitesse est retenue, comme la voix ───────────────────────────────
  test("la vitesse de lecture est mémorisée", () {
    final source = lire('lib/core/services/tts_service.dart');

    expect(source.contains("_cleVitesse = 'tts_vitesse'"), isTrue);
    expect(
      source.contains('prefs.setDouble(_cleVitesse, _speechRate)'),
      isTrue,
      reason: 'setRate doit persister le choix.',
    );
    expect(
      source.contains('await _relireLaVitesse();'),
      isTrue,
      reason: 'L\'initialisation doit relire le choix mémorisé.',
    );
  });

  // ── Les voix peuvent être réexaminées ───────────────────────────────────
  //
  // La résolution n'avait lieu qu'une fois, dans le constructeur du singleton.
  // Le lecteur à qui l'on conseillait d'installer une voix française
  // l'installait, revenait, et lisait le même message.
  test("l'état des voix peut être réexaminé sans redémarrer", () {
    final source = lire('lib/core/services/tts_service.dart');
    expect(source.contains('Future<void> reexaminerLesVoix() async'), isTrue);
  });

  // ── Le panneau survit à la disparition de la barre d'outils ─────────────
  test("le panneau reste visible tant qu'une voix parle", () {
    final ecran = lire(
      'lib/core/space_learn/pages/widgets/details/reading_page.dart',
    );
    expect(
      ecran.contains('(_showControls || !_ttsService.isStopped)'),
      isTrue,
      reason:
          'Une tape sur la page effaçait la barre d\'outils et, avec elle, le '
          'seul bouton pause disponible pendant que la voix continuait.',
    );
  });

  // ── L'écran se détache du service en partant ────────────────────────────
  test("l'écran de lecture débranche son rappel de complétion", () {
    final ecran = lire(
      'lib/core/space_learn/pages/widgets/details/reading_page.dart',
    );
    expect(
      ecran.contains('_ttsService.onCompletion = null;'),
      isTrue,
      reason:
          'Le service est un singleton : un rappel laissé en place pilote le '
          'contrôleur de PDF d\'un écran déjà détruit.',
    );
  });

  // ── Android peut afficher la notification de lecture ────────────────────
  test("POST_NOTIFICATIONS est déclarée", () {
    final manifeste = lire('android/app/src/main/AndroidManifest.xml');
    expect(
      manifeste.contains('android.permission.POST_NOTIFICATIONS'),
      isTrue,
      reason:
          'Depuis Android 13, sans cette permission la notification ne '
          's\'affiche pas — donc plus de commandes sur l\'écran verrouillé, '
          'qui est tout l\'intérêt de la lecture en arrière-plan.',
    );
  });
}
