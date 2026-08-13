import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Le forum ne doit rien inventer sur ses participants, ni les faire attendre
/// devant une roue qui tourne sans fin.
///
/// Ces regles lisent le code source. Elles ne remplacent pas des tests d'ecran,
/// elles attrapent ce qu'un test d'ecran ne verrait pas : une valeur fabriquee
/// paraitra toujours plausible a l'affichage, et une roue qui tourne ressemble
/// a un chargement en cours.
void main() {
  final pagesForum = [
    'lib/core/space_learn/pages/widgets/lecteur/communaute/forum_discussion_page.dart',
    'lib/core/space_learn/pages/widgets/lecteur/communaute/forum_messages_page.dart',
  ];

  test('aucun rang de participant n\'est calcule sur le nom', () {
    // Le rang etait tire de `username.hashCode % 100`, et le commentaire
    // l'assumait : « Simulation d'un rang base sur le nom pour la demo ». Des
    // lecteurs portaient publiquement un titre de « Maitre » ou d'« Erudit »
    // tire de l'orthographe de leur nom.
    for (final chemin in pagesForum) {
      // Les commentaires sont ignores : ils expliquent justement pourquoi la
      // regle existe, et les compter serait s'interdire de la documenter.
      final fautives = File(chemin)
          .readAsLinesSync()
          .asMap()
          .entries
          .where((e) => !e.value.trimLeft().startsWith('//'))
          .where((e) => e.value.contains('hashCode'))
          .map((e) => '$chemin:${e.key + 1}')
          .toList();

      expect(
        fautives,
        isEmpty,
        reason:
            'Une valeur est fabriquee a partir du nom. Ce que le serveur ne '
            'transmet pas ne doit pas etre devine :\n${fautives.join('\n')}',
      );
    }
  });

  test('aucun visage ne vient d\'un service tiers', () {
    // La pastille chargeait « i.pravatar.cc/150?u=<nom> » : un service qui
    // renvoie la photo d'une personne reelle prise au hasard. Chaque
    // participant portait le visage d'un inconnu, et le nom des lecteurs
    // partait chez un tiers a chaque affichage de la liste.
    final servicesInterdits = ['pravatar', 'randomuser.me', 'ui-avatars.com'];
    final fautes = <String>[];

    for (final f in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final lignes = f.readAsLinesSync();
      for (var i = 0; i < lignes.length; i++) {
        if (lignes[i].trimLeft().startsWith('//')) continue;
        for (final service in servicesInterdits) {
          if (lignes[i].contains(service)) {
            fautes.add('${f.path}:${i + 1}');
          }
        }
      }
    }

    expect(
      fautes,
      isEmpty,
      reason:
          'Un portrait est charge chez un tiers, a qui le nom du lecteur est '
          'transmis :\n${fautes.join('\n')}',
    );
  });

  test('un jeton absent ne laisse pas la roue tourner', () {
    // Le motif fautif etait `if (token == null) return;` : la fonction sortait
    // avant de toucher a _isLoading, qui restait vrai pour toujours. Rien a
    // lire, rien a faire, aucune explication.
    final motif = RegExp(r'if\s*\(\s*token\s*==\s*null\s*\)\s*return\s*;');

    for (final chemin in pagesForum) {
      final source = File(chemin).readAsStringSync();
      expect(
        motif.hasMatch(source),
        isFalse,
        reason:
            '$chemin sort silencieusement quand la session manque. '
            'Il faut le dire a l\'utilisateur et arreter le chargement.',
      );
    }
  });

  test('l\'etiquette Hero du bouton flottant est bien interpolee', () {
    // Elle etait ecrite avec un « \$ » echappe dans une chaine simple : tous
    // les forums partageaient donc la meme etiquette, et deux forums empiles
    // dans la navigation levaient un conflit de Hero.
    final source = File(pagesForum.first).readAsStringSync();
    expect(
      source.contains(r'\${widget.book'),
      isFalse,
      reason:
          'Le heroTag contient une interpolation echappee : elle est inerte, '
          'et tous les forums portent la meme etiquette.',
    );
  });
}
