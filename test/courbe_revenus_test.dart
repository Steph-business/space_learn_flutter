import 'package:flutter_test/flutter_test.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/auteur/accueil/revenus.dart';

/// Les étiquettes de la courbe de l'accueil auteur.
///
/// Elles étaient écrites en dur, de « Jan » à « Déc ». Or le serveur renvoie
/// les douze derniers mois GLISSANTS : du mois M-11 au mois courant. En août,
/// le premier point est celui de septembre de l'année précédente — et il
/// s'affichait sous « Jan ».
///
/// Toute la courbe était donc décalée, d'autant de mois que l'année était
/// avancée, et rien ne le signalait : l'auteur lisait une vente de décembre
/// sous le mois d'avril sans pouvoir s'en douter.
void main() {
  group('La fenêtre suit ce que le serveur annonce', () {
    test('elle commence au mois indiqué', () {
      final mois = moisDeLaFenetre('2025-09');

      expect(mois.first, 'Sep');
      expect(mois.length, 12);
      // Douze mois plus tard : août de l'année suivante.
      expect(mois.last, 'Août');
    });

    /// Le repère qui manquait le plus : une fenêtre à cheval sur deux années
    /// se lisait comme si tout s'était passé dans la même.
    test('janvier porte son année', () {
      final mois = moisDeLaFenetre('2025-09');
      expect(mois[4], 'Jan 26');
    });

    test('une fenêtre qui commence en janvier reste lisible', () {
      final mois = moisDeLaFenetre('2026-01');
      expect(mois.first, 'Jan 26');
      expect(mois.last, 'Déc');
    });
  });

  group('Quand le serveur ne dit rien', () {
    /// Un serveur d'une version antérieure n'envoie pas ce champ : la fenêtre
    /// se recompose depuis la date du jour, ce qui donne le même résultat tant
    /// que les deux horloges s'accordent sur le mois.
    test('la fenêtre se recompose depuis aujourd\'hui', () {
      final mois = moisDeLaFenetre(
        null,
        maintenant: DateTime(2026, 8, 19),
      );
      expect(mois.first, 'Sep');
      expect(mois.last, 'Août');
    });

    test('une valeur illisible ne fabrique pas de mois absurde', () {
      for (final brut in ['', 'n/importe/quoi', '2026-13', '2026-00', 'abc-de']) {
        final mois = moisDeLaFenetre(brut, maintenant: DateTime(2026, 8, 19));
        expect(mois.length, 12, reason: brut);
        expect(mois.first, 'Sep', reason: brut);
      }
    });
  });

  group('Les douze points couvrent douze mois consécutifs', () {
    test('sans trou ni répétition', () {
      final mois = moisDeLaFenetre('2026-03');
      // Chaque abréviation de mois n'apparaît qu'une fois sur douze mois.
      final sansAnnee = mois.map((m) => m.split(' ').first).toList();
      expect(sansAnnee.toSet().length, 12);
    });

    test('le dernier point est le mois courant', () {
      final mois = moisDeLaFenetre(
        null,
        maintenant: DateTime(2026, 2, 5),
      );
      expect(mois.last, 'Fév');
    });
  });
}
