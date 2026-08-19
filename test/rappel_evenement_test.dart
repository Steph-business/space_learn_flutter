import 'package:flutter_test/flutter_test.dart';
import 'package:space_learn_flutter/core/services/rappel_evenement.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Le rappel d'un rendez-vous.
///
/// C'est ce qui sépare un événement d'une annonce : une annonce se lit ou pas,
/// un rendez-vous se manque. L'application se contentait d'afficher la date, à
/// charge pour le lecteur de la retenir.
void main() {
  setUpAll(() {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Africa/Abidjan'));
  });

  group('Quand le rappel doit sonner', () {
    test('la veille, en fin d\'après-midi', () {
      final dans10Jours = DateTime.now().add(const Duration(days: 10));
      final quand = RappelEvenement.quandSonner(dans10Jours);

      expect(quand, isNotNull);
      expect(
        quand!.hour,
        18,
        reason: 'au moment où l\'on regarde son lendemain',
      );

      final veille = dans10Jours.subtract(const Duration(days: 1));
      expect(quand.day, veille.day);
      expect(quand.month, veille.month);
    });

    /// Le piège : promettre une notification qui ne partirait jamais.
    ///
    /// Un rendez-vous dont la veille est déjà passée ne peut plus être rappelé.
    /// Poser le rappel quand même laisserait un bouton « Rappel posé » sur une
    /// alarme qui ne sonnera pas.
    ///
    /// Le rendez-vous est fixé AUJOURD'HUI, et non « dans vingt heures ».
    /// Vingt heures d'avance ne veulent pas dire la même chose selon l'heure
    /// qu'il est : le matin, la veille à 18 h est encore devant nous ; le soir,
    /// elle est derrière. Le test passait donc la nuit et échouait le matin.
    /// La veille d'aujourd'hui, elle, est passée à toute heure.
    test('un rendez-vous trop proche ne se rappelle plus', () {
      final maintenant = DateTime.now();
      final plusTardAujourdhui = DateTime(
        maintenant.year,
        maintenant.month,
        maintenant.day,
        23,
        59,
      );
      expect(RappelEvenement.quandSonner(plusTardAujourdhui), isNull);
    });

    test('un rendez-vous passé non plus', () {
      final hier = DateTime.now().subtract(const Duration(days: 1));
      expect(RappelEvenement.quandSonner(hier), isNull);
    });
  });

  group('À qui le geste est proposé', () {
    test('à un rendez-vous encore devant nous', () {
      final dans3Semaines = DateTime.now().add(const Duration(days: 21));
      expect(RappelEvenement.encorePossible(dans3Semaines), isTrue);
    });

    /// Une annonce n'a pas de date : il n'y a rien à rappeler.
    test('jamais à une annonce', () {
      expect(RappelEvenement.encorePossible(null), isFalse);
    });

    test('ni à un rendez-vous déjà passé', () {
      final ilYAUneSemaine = DateTime.now().subtract(const Duration(days: 7));
      expect(RappelEvenement.encorePossible(ilYAUneSemaine), isFalse);
    });

    /// Le cas limite : la veille au soir est déjà derrière nous.
    ///
    /// Même précaution que plus haut — le rendez-vous est daté d'aujourd'hui,
    /// pas décalé d'un nombre d'heures. Un décalage relatif franchit minuit ou
    /// non selon l'heure du test, et le résultat attendu change avec lui.
    test('ni à un rendez-vous de ce soir', () {
      final maintenant = DateTime.now();
      final ceSoir = DateTime(
        maintenant.year,
        maintenant.month,
        maintenant.day,
        23,
        59,
      );
      expect(RappelEvenement.encorePossible(ceSoir), isFalse);
    });
  });

  group('Le moment choisi', () {
    /// Prévenir le jour même laisse trop peu de temps pour s'organiser ; une
    /// semaine avant, on oublie de nouveau.
    test('c\'est bien la veille, pas le jour même', () {
      final jourJ = DateTime.now().add(const Duration(days: 5));
      final quand = RappelEvenement.quandSonner(jourJ)!;

      final ecart = DateTime(
        jourJ.year,
        jourJ.month,
        jourJ.day,
      ).difference(DateTime(quand.year, quand.month, quand.day));

      expect(ecart.inDays, 1);
    });

    test('le rappel tombe toujours dans le futur', () {
      for (final jours in [2, 5, 30, 365]) {
        final date = DateTime.now().add(Duration(days: jours));
        final quand = RappelEvenement.quandSonner(date);
        expect(
          quand!.isAfter(tz.TZDateTime.now(tz.local)),
          isTrue,
          reason: 'à $jours jours, le rappel serait déjà passé',
        );
      }
    });
  });
}
