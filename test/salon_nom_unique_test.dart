import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Une salle, un nom.
///
/// Le salon global est une seule salle cote serveur — `type = 'GLOBAL'`, sans
/// aucun filtre de role — mais elle portait quatre noms selon la porte par
/// laquelle on y entrait : « SALON DE L'AUTEUR » depuis l'onglet Communaute
/// d'un auteur, « LE CAFE DES LECTEURS » depuis celui d'un lecteur, « Le Café
/// des Lecteurs » quand une notification y menait. Le meme auteur voyait la
/// meme salle sous deux noms au cours d'une meme session.
///
/// Ces regles sont statiques : elles lisent le code source. Un test d'ecran ne
/// les attraperait pas, puisque chaque ecran est juste separement — c'est leur
/// desaccord qui est le defaut.
void main() {
  final racine = Directory('lib');

  List<File> fichiersDart() => racine
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  test('aucun ecran ne nomme un salon lui-meme', () {
    // Les noms n'existent qu'a un seul endroit. Partout ailleurs, une chaine
    // litterale qui nomme un salon est une divergence en puissance.
    final interdits = RegExp(
      r'''(["'])[^"']*?(SALON DE L|Salon Officiel|CAFE DES LECTEURS|Café des Lecteurs|CLUB DE LECTURE)[^"']*?\1''',
    );

    final fautes = <String>[];
    for (final f in fichiersDart()) {
      if (f.path.replaceAll(r'\', '/').endsWith('communaute/salon_noms.dart')) {
        continue;
      }
      final lignes = f.readAsLinesSync();
      for (var i = 0; i < lignes.length; i++) {
        final ligne = lignes[i];
        if (ligne.trimLeft().startsWith('//')) continue;
        if (interdits.hasMatch(ligne)) {
          fautes.add('${f.path}:${i + 1}  ${ligne.trim()}');
        }
      }
    }

    expect(
      fautes,
      isEmpty,
      reason:
          'Un salon est nomme en dur hors de SalonNoms. Deux ecrans peuvent '
          'alors designer la meme salle par deux noms differents :\n'
          '${fautes.join('\n')}',
    );
  });

  test('ForumDiscussionPage ne prend ni titre ni sous-titre', () {
    // Rendre ces parametres optionnels ne suffirait pas : un parametre
    // optionnel accepte toujours un litteral, et le prochain ecran pourrait
    // inventer un cinquieme nom sans que rien ne le signale. Leur absence
    // rend la divergence impossible a ecrire.
    final source = File(
      'lib/core/space_learn/pages/widgets/lecteur/communaute/forum_discussion_page.dart',
    ).readAsStringSync();

    final constructeur = RegExp(
      r'const ForumDiscussionPage\(([^)]*)\)',
    ).firstMatch(source);

    expect(
      constructeur,
      isNotNull,
      reason: 'constructeur de ForumDiscussionPage introuvable',
    );

    final parametres = constructeur!.group(1)!;
    expect(
      parametres.contains('title'),
      isFalse,
      reason:
          'Le parametre title est revenu : chaque appelant pourra de nouveau '
          'nommer la salle a sa facon.',
    );
    expect(
      parametres.contains('subtitle'),
      isFalse,
      reason: 'Le parametre subtitle est revenu.',
    );
  });
}
