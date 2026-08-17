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
  const faq = 'lib/core/space_learn/pages/principales/settings/help_faq_page.dart';

  // ── Un lecteur ne voit pas le mode d'emploi de l'auteur ─────────────────
  //
  // La page avait deux onglets et un `initialIsAuthor` qui ne décidait que du
  // premier affiché : un lecteur n'avait qu'à toucher le second pour lire tout
  // le parcours auteur — déposer un manuscrit, fixer un prix, suivre ses ventes.
  test("le guide ne monte le parcours auteur que pour un auteur", () {
    final source = lire(guide);

    // Hors commentaires : la documentation mentionne l'ancien nom pour
    // expliquer pourquoi il a disparu, et cette explication doit pouvoir rester.
    final codeSeul = source
        .split('\n')
        .where((l) => !l.trimLeft().startsWith('//'))
        .join('\n');
    expect(
      codeSeul.contains('initialIsAuthor'),
      isFalse,
      reason: "Le drapeau d'onglet initial a été remplacé par un vrai rôle.",
    );
    expect(source.contains('length: widget.estAuteur ? 2 : 1'), isTrue,
        reason: 'Un lecteur n\'a qu\'un onglet.');
    expect(source.contains('if (widget.estAuteur) _buildAuthorGuide'), isTrue,
        reason: 'Le parcours auteur ne doit pas être construit pour un lecteur.');
  });

  // ── Le guide est atteignable depuis l'en-tête ───────────────────────────
  test("l'en-tête porte l'accès au guide, avec un point d'interrogation", () {
    final entete = lire('lib/core/themes/layout/nav_bar_all.dart');

    expect(entete.contains('Icons.help_outline_rounded'), isTrue,
        reason: "L'icône d'aide doit être un point d'interrogation.");
    expect(entete.contains('UserGuidePage('), isTrue);
    expect(entete.contains("estAuteur: widget.role == 'auteur'"), isTrue,
        reason: "Le rôle de l'en-tête décide de ce qui s'ouvre.");
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
    expect(source.contains('apercu: true'), isTrue,
        reason: "Lire une section ne doit pas tourner la page d'un livre.");
    expect(source.contains('_tts.removeListener'), isTrue,
        reason: 'Le service est un singleton : son écouteur doit être retiré.');
    expect(source.contains('_tts.stop();'), isTrue,
        reason: 'La voix doit se taire quand on quitte le guide.');
  });

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
      expect(e.passe, isTrue,
          reason: 'Un serveur antérieur au drapeau ne doit pas tout donner '
              'pour à venir.');
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
      expect(e.passe, isFalse,
          reason: 'La journée entière compte : sinon une rencontre en cours '
              'serait donnée pour terminée.');
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
