import 'package:flutter_test/flutter_test.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/lecteur/communaute/proximite_evenement.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/lecteur/communaute/temps_relatif.dart';

/// Ce qu'une carte de rendez-vous doit dire, et qu'elle ne disait pas.
///
/// Elle n'affichait que « 17 août 2026 ». La même chose le jour de la
/// publication et trois semaines plus tard : au lecteur de calculer si ça le
/// concerne. Personne ne calcule. Une carte figée pendant que le temps avance
/// finit par ne plus être lue du tout.
void main() {
  // Un jeudi, à midi. L'heure ne doit rien changer : un rendez-vous est une
  // journée, pas un instant.
  final maintenant = DateTime(2026, 8, 26, 12, 0);

  String pour(DateTime date) =>
      proximiteEvenement(date, maintenant: maintenant);

  group('Les trois mots qui ne se calculent pas', () {
    test('aujourd’hui', () {
      expect(pour(DateTime(2026, 8, 26, 9, 0)), "Aujourd'hui");
      expect(pour(DateTime(2026, 8, 26, 23, 30)), "Aujourd'hui");
    });

    test('demain et hier', () {
      expect(pour(DateTime(2026, 8, 27, 8, 0)), 'Demain');
      expect(pour(DateTime(2026, 8, 25, 20, 0)), 'Hier');
    });

    test('une dédicace du matin reste « aujourd’hui » tout le jour', () {
      // Le cas qui a motivé la règle du jour entier côté serveur : un
      // événement de 9 h ne doit pas basculer à « Hier » à 10 h.
      final tard = DateTime(2026, 8, 26, 23, 59);
      expect(proximiteEvenement(DateTime(2026, 8, 26, 9, 0), maintenant: tard),
          "Aujourd'hui");
    });
  });

  group('Les distances', () {
    test('à venir', () {
      expect(pour(DateTime(2026, 8, 29)), 'Dans 3 jours');
      expect(pour(DateTime(2026, 9, 2)), 'Dans une semaine');
      expect(pour(DateTime(2026, 9, 9)), 'Dans 2 semaines');
      expect(pour(DateTime(2026, 9, 25)), 'Dans un mois');
      expect(pour(DateTime(2026, 10, 26)), 'Dans 2 mois');
    });

    test('passées', () {
      expect(pour(DateTime(2026, 8, 23)), 'Il y a 3 jours');
      expect(pour(DateTime(2026, 8, 17)), 'Il y a une semaine');
      expect(pour(DateTime(2026, 7, 27)), 'Il y a un mois');
    });

    test('le cas de la capture d’écran', () {
      // « Dédicace de mon livre », 17 août, vue le 26. Elle annonçait
      // « 17 août 2026 » sans dire qu'elle était derrière nous.
      expect(pour(DateTime(2026, 8, 17)), 'Il y a une semaine');
    });
  });

  group('Ce qui ne doit jamais sortir', () {
    test('aucun nombre négatif', () {
      for (final jours in [-40, -8, -2, 2, 8, 40]) {
        final texte = pour(maintenant.add(Duration(days: jours)));
        expect(texte, isNot(contains('-')), reason: 'à $jours jours : $texte');
      }
    });

    test('jamais « Dans 0 » ni « Il y a 0 »', () {
      for (var jours = -70; jours <= 70; jours++) {
        final texte = pour(maintenant.add(Duration(days: jours)));
        expect(texte, isNot(contains(' 0 ')), reason: 'à $jours jours : $texte');
        expect(texte.trim(), isNotEmpty);
      }
    });

    test('le pluriel suit la valeur', () {
      expect(pour(DateTime(2026, 9, 2)), isNot(contains('semaines')));
      expect(pour(DateTime(2026, 9, 25)), isNot(contains('mois s')));
      expect(pour(DateTime(2026, 8, 29)), contains('jours'));
    });
  });

  // Le changement d'heure décale deux dates locales d'un multiple non entier de
  // 24 h : une différence de Duration rendrait alors 0 pour deux jours
  // distincts, et « Demain » s'afficherait le jour même.
  test('insensible au décalage horaire', () {
    final veille = DateTime(2026, 3, 28, 23, 0);
    final lendemain = DateTime(2026, 3, 29, 1, 0);
    expect(proximiteEvenement(lendemain, maintenant: veille), 'Demain');
    expect(proximiteEvenement(veille, maintenant: lendemain), 'Hier');
  });

  group('L’ancienneté d’une annonce', () {
    test('au-delà d’un mois, on cesse de compter les semaines', () {
      String depuis(int jours) => tempsRelatif(
        maintenant.subtract(Duration(days: jours)),
        maintenant: maintenant,
      );

      // « il y a 12 semaines » : une durée que personne ne se représente.
      expect(depuis(30), 'il y a 1 mois');
      expect(depuis(32), 'il y a 1 mois');
      expect(depuis(90), 'il y a 3 mois');
      // Le palier des semaines tient toujours en dessous.
      expect(depuis(21), 'il y a 3 semaines');
      expect(depuis(29), 'il y a 4 semaines');
    });

    test('le cas de la capture d’écran', () {
      // « Très bientôt pour l'édition 2 », publié le 25 juillet, lu le 26 août.
      // Le texte dit « très bientôt » ; la date ne le contredisait pas.
      expect(
        tempsRelatif(DateTime(2026, 7, 25), maintenant: maintenant),
        'il y a 1 mois',
      );
    });
  });
}
