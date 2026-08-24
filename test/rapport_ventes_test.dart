import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/reversement_model.dart';

/// La date d'une vente dans le rapport de l'auteur.
///
/// Deux dates existent pour un même crédit, et le rapport affichait la
/// mauvaise :
///
///   - `cree_le` : quand la ligne a été inscrite au portefeuille ;
///   - `vendu_le` : quand la vente a réellement eu lieu.
///
/// Elles coïncident en marche normale. Mais les crédits rattrapés après coup
/// portent tous la date du rattrapage : une vente du 20 juillet, créditée le
/// 17 août, s'affichait « 17 août ». L'auteur ne pouvait rapprocher son
/// rapport de rien de ce qu'il savait de son activité.
ReversementModel vente(String corps) =>
    ReversementModel.fromJson(jsonDecode(corps) as Map<String, dynamic>);

void main() {
  group('La date affichée est celle de la vente', () {
    /// Le cas exact rencontré : rattrapage du 17 août pour une vente du
    /// 20 juillet.
    test('même quand le crédit a été inscrit bien plus tard', () {
      final v = vente('''{
        "id": "r1", "livre_id": "l1",
        "montant_brut": 9750, "commission": 1950, "montant_net": 7800,
        "devise": "XOF",
        "cree_le": "2026-08-17T22:09:23Z",
        "vendu_le": "2026-07-20T10:30:00Z"
      }''');

      expect(v.venduLe, isNotNull);
      expect(v.dateAAfficher, v.venduLe);
      expect(v.dateAAfficher!.month, 7);
      expect(v.dateAAfficher!.day, 20);
    });

    test('et quand les deux dates coïncident', () {
      final v = vente('''{
        "id": "r1", "livre_id": "l1",
        "montant_brut": 10000, "commission": 2000, "montant_net": 8000,
        "devise": "XOF",
        "cree_le": "2026-08-22T09:00:00Z",
        "vendu_le": "2026-08-22T09:00:00Z"
      }''');

      expect(v.dateAAfficher!.day, 22);
    });
  });

  group('Quand la vente n\'a pas de date', () {
    /// Un crédit dont le paiement a disparu — l'anomalie trouvée en base.
    /// La ligne reste visible : la masquer ferait taire le problème au lieu
    /// de le montrer.
    test('le rapport retombe sur la date du crédit', () {
      final v = vente('''{
        "id": "r2", "livre_id": "l2",
        "montant_brut": 100, "commission": 20, "montant_net": 80,
        "devise": "XOF",
        "cree_le": "2026-08-16T00:00:09Z"
      }''');

      expect(v.venduLe, isNull);
      expect(v.dateAAfficher, v.creeLe);
      expect(v.dateAAfficher, isNotNull);
    });

    /// Un serveur d'une version antérieure n'envoie pas encore `vendu_le` :
    /// le rapport garde son ancien comportement au lieu de n'afficher rien.
    test('un serveur antérieur ne casse pas l\'affichage', () {
      final v = vente('''{
        "id": "r3", "livre_id": "l3",
        "montant_net": 8000, "devise": "XOF",
        "cree_le": "2026-08-22T09:00:00Z"
      }''');

      expect(v.dateAAfficher, isNotNull);
    });

    test('sans aucune date, rien n\'est inventé', () {
      final v = vente('{"id": "r4", "livre_id": "l4", "montant_net": 0}');
      expect(v.dateAAfficher, isNull);
    });
  });
}
