import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/evenementModel.dart';

/// Garde-fous du guide et de la communauté.
///
/// Les règles de rôle et de couleur ne se vérifient pas à l'exécution : elles se
/// lisent dans la source, comme le fait déjà `coherence_couleurs_test.dart`.
void main() {
  String lire(String chemin) {
    final f = File(chemin);
    if (!f.existsSync()) {
      fail('Fichier introuvable : $chemin — lancer le test à la racine.');
    }
    return f.readAsStringSync();
  }

  const guide =
      'lib/core/space_learn/pages/principales/settings/user_guide_page.dart';
  const visite = 'lib/core/widgets/guides/space_learn_tour.dart';
  const faq =
      'lib/core/space_learn/pages/principales/settings/help_faq_page.dart';

  // ── Chacun ne voit QUE son parcours ─────────────────────────────────────
  //
  // Trois etats successifs, chacun corrigeant le precedent :
  //
  //  1. un `initialIsAuthor` ne decidait que de l'onglet OUVERT — un lecteur
  //     n'avait qu'a toucher le second pour lire tout le parcours auteur ;
  //  2. un lecteur n'eut plus qu'un onglet, mais l'auteur en gardait deux et
  //     ouvrait sur « Decouvrir et trouver des livres » depuis ses reglages
  //     d'auteur, avec une question d'auteur ;
  //  3. plus d'onglets du tout : un seul parcours, celui de la personne.
  test("le guide ne monte qu'un seul parcours", () {
    final source = lire(guide);

    // Hors commentaires : la documentation mentionne les anciens mecanismes
    // pour expliquer pourquoi ils ont disparu, et doit pouvoir le faire.
    final codeSeul = source
        .split('\n')
        .where((l) =>
            !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
        .join('\n');

    expect(
      codeSeul.contains('initialIsAuthor'),
      isFalse,
      reason: "Le drapeau d'onglet initial a ete remplace par un vrai role.",
    );
    for (final vestige in ['TabController', 'TabBarView', 'TabBar(']) {
      expect(
        codeSeul.contains(vestige),
        isFalse,
        reason: "$vestige subsiste : le guide ne doit plus avoir d'onglets.",
      );
    }
    expect(
      codeSeul.contains('? _buildAuthorGuide(isDark)'),
      isTrue,
      reason: 'Le parcours affiche doit dependre du role, et lui seul.',
    );
  });

  // ── Le guide est atteignable depuis l'en-tête ───────────────────────────
  test("l'en-tête porte l'accès au guide, avec un point d'interrogation", () {
    final entete = lire('lib/core/themes/layout/nav_bar_all.dart');

    expect(
      entete.contains('Icons.help_outline_rounded'),
      isTrue,
      reason: "L'icône d'aide doit être un point d'interrogation.",
    );
    expect(entete.contains('UserGuidePage('), isTrue);
    expect(
      entete.contains('estAuteur: estParcoursAuteur(widget.role)'),
      isTrue,
      reason: "Le rôle de l'en-tête décide de ce qui s'ouvre, et par la règle "
          "PARTAGÉE : l'égalité stricte avec « auteur » laissait les éditeurs "
          "et les administrateurs devant le guide du lecteur.",
    );
  });

  // ── Le guide et la visite suivent la palette ────────────────────────────
  //
  // Ils portaient un système de couleurs parallèle — violet, indigo, cyan,
  // magenta — avec sa propre logique clair/sombre, étrangère à l'ambre et au
  // brun de Space Learn.
  test("le guide et la visite n'écrivent aucune couleur en dur", () {
    for (final chemin in [guide, visite, faq]) {
      final source = lire(chemin);
      final fautes = <String>[];
      final lignes = source.split('\n');

      for (var i = 0; i < lignes.length; i++) {
        final ligne = lignes[i];
        if (ligne.trimLeft().startsWith('//')) continue;
        if (RegExp(r'Color\(0x').hasMatch(ligne) ||
            RegExp(r'Colors\.(white|black)\b').hasMatch(ligne)) {
          fautes.add('${chemin.split('/').last}:${i + 1} — ${ligne.trim()}');
        }
      }

      expect(
        fautes,
        isEmpty,
        reason: 'Couleur(s) hors palette :\n${fautes.join('\n')}',
      );
    }
  });

  // ── Chaque section du guide s'écoute ────────────────────────────────────
  test("le guide se fait lire à voix haute", () {
    final source = lire(guide);

    expect(source.contains('TtsService'), isTrue);
    expect(
      source.contains('apercu: true'),
      isTrue,
      reason: "Lire une section ne doit pas tourner la page d'un livre.",
    );
    expect(
      source.contains('_tts.removeListener'),
      isTrue,
      reason: 'Le service est un singleton : son écouteur doit être retiré.',
    );
    expect(
      source.contains('_tts.stop();'),
      isTrue,
      reason: 'La voix doit se taire quand on quitte le guide.',
    );
  });

  _paliersEtSerie();

  // ── Un événement passé se voit ──────────────────────────────────────────
  group('Événements passés', () {
    Evenement depuisJson(Map<String, dynamic> json) => Evenement.fromJson(json);

    test("le serveur tranche, l'application le suit", () {
      final e = depuisJson({
        'id': 'e1',
        'titre': 'Rencontre',
        'contenu': '...',
        'type_publication': 'EVENEMENT',
        'auteur_id': 'a1',
        'passe': true,
      });
      expect(e.passe, isTrue);
    });

    test("sans réponse du serveur, la date tranche localement", () {
      final vieux = DateTime.now().subtract(const Duration(days: 5));
      final e = depuisJson({
        'id': 'e1',
        'titre': 'Rencontre passée',
        'contenu': '...',
        'type_publication': 'EVENEMENT',
        'auteur_id': 'a1',
        'date_evenement': vieux.toIso8601String(),
      });
      expect(
        e.passe,
        isTrue,
        reason:
            'Un serveur antérieur au drapeau ne doit pas tout donner '
            'pour à venir.',
      );
    });

    test("un événement du jour n'est pas passé", () {
      final e = depuisJson({
        'id': 'e1',
        'titre': "Rencontre d'aujourd'hui",
        'contenu': '...',
        'type_publication': 'EVENEMENT',
        'auteur_id': 'a1',
        'date_evenement': DateTime.now().toIso8601String(),
      });
      expect(
        e.passe,
        isFalse,
        reason:
            'La journée entière compte : sinon une rencontre en cours '
            'serait donnée pour terminée.',
      );
    });

    test("une annonce sans date n'est jamais passée", () {
      final a = depuisJson({
        'id': 'a1',
        'titre': 'Annonce',
        'contenu': '...',
        'type_publication': 'ANNONCE',
        'auteur_id': 'a1',
      });
      expect(a.passe, isFalse);
    });
  });
}

/// Les paliers de progression des objectifs.
///
/// « Cumuler 1 heure de lecture » se terminait une fois et ne disait plus rien :
/// le lecteur restait devant un objectif atteint pour toujours, à 100 %. Un
/// palier qui avance donne toujours une marche suivante.
void _paliersEtSerie() {
  test("un objectif atteint ouvre le palier suivant", () {
    final source = File(
      'lib/core/space_learn/data/dataServices/reading_time_storage.dart',
    ).readAsStringSync();

    expect(
      source.contains('_prochainPalier'),
      isTrue,
      reason: 'Les objectifs doivent progresser, pas plafonner.',
    );
    expect(
      source.contains('serieJours'),
      isTrue,
      reason: 'La série de jours doit alimenter les objectifs.',
    );
  });

  test("la série de jours est affichée au lecteur", () {
    final page = File(
      'lib/core/space_learn/pages/principales/lecteur/badges_page.dart',
    ).readAsStringSync();

    expect(
      page.contains('getReadingStreak'),
      isTrue,
      reason: 'La série était calculée et jamais lue.',
    );
    expect(
      page.contains('local_fire_department'),
      isTrue,
      reason: "La série doit avoir sa place dans l'en-tête.",
    );
  });

  test("les trois statistiques ne débordent pas sur un écran étroit", () {
    final page = File(
      'lib/core/space_learn/pages/principales/lecteur/badges_page.dart',
    ).readAsStringSync();

    // Une Row de trois colonnes non contraintes déborde en rayures jaunes sur
    // un 320 px : chaque colonne doit partager la largeur et s'ellipser.
    expect(page.contains('Widget _statistique('), isTrue);
    expect(page.contains('overflow: TextOverflow.ellipsis'), isTrue);
    expect(
      RegExp(
        r'Widget _statistique\([\s\S]{0,400}?return Expanded\(',
      ).hasMatch(page),
      isTrue,
      reason: 'Chaque statistique doit être Expanded pour partager la largeur.',
    );
  });
}
