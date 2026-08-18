import 'package:flutter_test/flutter_test.dart';
import 'package:space_learn_flutter/core/services/rappels_lecture.dart';

/// Les créneaux de lecture.
///
/// Le réglage précédent n'offrait qu'une heure unique, la même sept jours sur
/// sept — et surtout, il ne programmait rien : `flutter_local_notifications`
/// était présent mais le code n'appelait que `show()`, un affichage immédiat.
/// Le lecteur croyait recevoir un rappel à 20 h 30 ; rien ne partait, jamais.
void main() {
  group('Libellé des jours', () {
    test('sept jours se disent « Tous les jours »', () {
      const c = CreneauLecture(
        heure: 20,
        minute: 30,
        jours: {1, 2, 3, 4, 5, 6, 7},
      );
      expect(c.libelleJours, 'Tous les jours');
    });

    test('du lundi au vendredi se dit « En semaine »', () {
      const c = CreneauLecture(heure: 7, minute: 0, jours: {1, 2, 3, 4, 5});
      expect(c.libelleJours, 'En semaine');
    });

    test('samedi et dimanche se disent « Le week-end »', () {
      const c = CreneauLecture(heure: 10, minute: 0, jours: {6, 7});
      expect(c.libelleJours, 'Le week-end');
    });

    test('une sélection quelconque se liste dans l\'ordre', () {
      const c = CreneauLecture(heure: 18, minute: 15, jours: {5, 1, 3});
      expect(c.libelleJours, 'Lun, Mer, Ven');
    });

    test("l'heure est toujours sur deux chiffres", () {
      const c = CreneauLecture(heure: 7, minute: 5, jours: {1});
      expect(c.libelleHeure, '07:05');
    });
  });

  group('Sérialisation', () {
    test('un créneau survit à un aller-retour', () {
      const avant = CreneauLecture(
        heure: 21,
        minute: 45,
        jours: {2, 4, 6},
        actif: false,
      );
      final apres = CreneauLecture.fromJson(avant.toJson());

      expect(apres.heure, 21);
      expect(apres.minute, 45);
      expect(apres.jours, {2, 4, 6});
      expect(apres.actif, isFalse);
    });

    test('des valeurs manquantes donnent un créneau utilisable', () {
      final c = CreneauLecture.fromJson({});
      expect(c.heure, 20);
      expect(c.minute, 30);
      expect(c.jours, isEmpty);
      // Un créneau sans jour ne programme rien ; il ne doit pas faire échouer
      // la lecture des préférences pour autant.
      expect(c.actif, isTrue);
    });
  });
}
