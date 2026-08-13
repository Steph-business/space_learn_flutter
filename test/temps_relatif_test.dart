import 'package:flutter_test/flutter_test.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/lecteur/communaute/temps_relatif.dart';

/// La fonction existait en double, recopiee a l'identique dans les deux pages
/// du forum. Deux copies d'une meme regle finissent par diverger — l'une gagne
/// un pluriel, l'autre un seuil — sans que rien ne le signale.
void main() {
  final maintenant = DateTime(2026, 8, 13, 12, 0);

  String depuis(Duration d) =>
      tempsRelatif(maintenant.subtract(d), maintenant: maintenant);

  test('les seuils', () {
    expect(depuis(const Duration(seconds: 5)), "à l'instant");
    expect(depuis(const Duration(minutes: 1)), 'il y a 1 min');
    expect(depuis(const Duration(minutes: 59)), 'il y a 59 min');
    expect(depuis(const Duration(hours: 1)), 'il y a 1 heure');
    expect(depuis(const Duration(hours: 23)), 'il y a 23 heures');
    expect(depuis(const Duration(days: 1)), 'il y a 1 jour');
    expect(depuis(const Duration(days: 6)), 'il y a 6 jours');
    expect(depuis(const Duration(days: 7)), 'il y a 1 semaine');
    expect(depuis(const Duration(days: 21)), 'il y a 3 semaines');
  });

  test('le pluriel suit la valeur', () {
    expect(depuis(const Duration(hours: 1)), isNot(contains('heures')));
    expect(depuis(const Duration(days: 1)), isNot(contains('jours')));
    expect(depuis(const Duration(days: 7)), isNot(contains('semaines')));
  });

  test("une date a venir ne donne pas d'ancienneté négative", () {
    // L'horloge d'un telephone et celle d'un serveur ne sont jamais tout a
    // fait d'accord : sans ce cas, un message tout juste envoye pouvait
    // s'afficher « il y a -1 min ».
    final futur = maintenant.add(const Duration(minutes: 3));
    expect(tempsRelatif(futur, maintenant: maintenant), "à l'instant");
  });
}
