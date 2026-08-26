import 'package:flutter_test/flutter_test.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/discussionModel.dart';

/// La liste des salons paraissait mal triée. Elle ne l'était pas.
///
/// Relevé en production le 26 août 2026, dans l'ordre exact rendu par le
/// serveur :
///
///	SALON                             AFFICHÉ         RÉEL            MSG
///	Crea                              il y a 6 mois   il y a 5 j       3
///	La vie est belle lorsqu'elle…     il y a 1 sem.   aucun message    0
///	Le parcours de ma vie             il y a 1 mois   aucun message    0
///	Coment choisir son chemin         il y a 5 mois   il y a 5 mois    3
///
/// La colonne RÉEL décroît parfaitement : le serveur trie par `triParActivite`,
/// c'est-à-dire la date du dernier message, avec repli sur l'ouverture du salon.
/// La colonne AFFICHÉE, elle, montrait `creeLe` — une autre date. « Crea »,
/// ouvert il y a six mois mais animé il y a cinq jours, arrivait donc en tête
/// en s'annonçant comme le plus vieux de la liste.
///
/// Le désordre n'était pas dans l'ordre. Il était dans ce qu'on lisait.
void main() {
  Discussion salon({DateTime? ouvert, DateTime? dernierMessage}) => Discussion(
    id: 'd1',
    titre: 'Crea',
    creeLe: ouvert,
    dernierMessageLe: dernierMessage,
  );

  test('un salon animé porte la date de sa dernière activité', () {
    final d = salon(
      ouvert: DateTime(2026, 2, 20),
      dernierMessage: DateTime(2026, 8, 21),
    );

    expect(d.dateAAfficher, DateTime(2026, 8, 21));
    expect(
      d.dateAAfficher,
      isNot(d.creeLe),
      reason:
          "un salon ouvert il y a six mois et animé hier est vivant ; "
          "le dater de son ouverture le fait passer pour mort",
    );
  });

  test('un salon muet retombe sur sa date d’ouverture', () {
    // Sans ce repli, un salon sans message n'aurait aucune date à montrer —
    // et le serveur, lui, le range déjà par sa date d'ouverture.
    final d = salon(ouvert: DateTime(2026, 8, 19));

    expect(d.dernierMessageLe, isNull);
    expect(d.dateAAfficher, DateTime(2026, 8, 19));
  });

  test('sans aucune date, rien n’est inventé', () {
    expect(salon().dateAAfficher, isNull);
  });

  test('la date se lit depuis la réponse du serveur', () {
    final d = Discussion.fromJson({
      'id': 'd1',
      'titre': 'Crea',
      'cree_le': '2026-02-20T10:00:00Z',
      'dernier_message_le': '2026-08-21T14:00:00Z',
    });

    expect(d.dateAAfficher!.month, 8);
  });

  // Le cas complet : trier sur la date affichée doit rendre l'ordre que le
  // serveur a déjà choisi. Si les deux divergent, la liste paraît mélangée.
  test('l’ordre affiché suit l’ordre du serveur', () {
    final rendus = [
      Discussion(
        id: 'a',
        titre: 'Crea',
        creeLe: DateTime(2026, 2, 20),
        dernierMessageLe: DateTime(2026, 8, 21),
      ),
      Discussion(
        id: 'b',
        titre: "La vie est belle",
        creeLe: DateTime(2026, 8, 19),
      ),
      Discussion(
        id: 'c',
        titre: 'Le parcours de ma vie',
        creeLe: DateTime(2026, 7, 26),
      ),
      Discussion(
        id: 'd',
        titre: 'Coment choisir son chemin',
        creeLe: DateTime(2026, 3, 26),
        dernierMessageLe: DateTime(2026, 3, 28),
      ),
    ];

    // Trié comme le ferait quelqu'un qui lit les dates à l'écran.
    final parDateAffichee = [...rendus]
      ..sort((x, y) => y.dateAAfficher!.compareTo(x.dateAAfficher!));

    expect(
      parDateAffichee.map((d) => d.id).toList(),
      rendus.map((d) => d.id).toList(),
      reason: "les dates lues doivent expliquer l'ordre, pas le contredire",
    );

    // Et avec l'ancienne date, elles le contredisaient.
    final parDateDOuverture = [...rendus]
      ..sort((x, y) => y.creeLe!.compareTo(x.creeLe!));
    expect(
      parDateDOuverture.map((d) => d.id).toList(),
      isNot(rendus.map((d) => d.id).toList()),
    );
  });
}
