import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/reversement_model.dart';

/// Ce que l'auteur voit avant de confirmer un virement.
///
/// Cinq mille francs n'était pas un seuil mais une porte : en dessous, rien ne
/// sortait, et le bouton restait grisé. Un auteur qui n'a qu'un seul livre —
/// c'est-à-dire presque tous au lancement — voyait son portefeuille monter de
/// 800 F en 800 F sans jamais pouvoir y toucher.
///
/// Le virement reste offert au-dessus du seuil. En dessous, il est possible dès
/// le plancher absolu, frais retenus — et ces tests fixent la règle du calcul,
/// qui doit rendre exactement la même chose que `DecomposerRetrait` côté
/// serveur : deux réponses différentes sur de l'argent, ce serait pire que pas
/// d'aperçu du tout.

Portefeuille porte(String corps) =>
    Portefeuille.fromJson(jsonDecode(corps) as Map<String, dynamic>);

const _reponse = '''{
  "solde": {"total_gagne": 4000, "total_retire": 0, "en_cours": 0,
            "disponible": 4000, "devise": "XOF"},
  "taux_commission": 0.20,
  "minimum_retrait": 5000,
  "minimum_retrait_absolu": 1000,
  "frais_retrait": 100,
  "reversements": [],
  "retraits": []
}''';

void main() {
  group('Les deux seuils viennent du serveur', () {
    test('le seuil gratuit et le plancher absolu sont lus', () {
      final p = porte(_reponse);
      expect(p.minimumRetrait, 5000);
      expect(p.minimumRetraitAbsolu, 1000);
      expect(p.fraisRetrait, 100);
    });

    /// Un serveur pas encore déployé n'envoie pas le plancher absolu : on
    /// retombe alors sur l'ancien comportement, où le seuil de gratuité était
    /// aussi le plancher. Prudent plutôt que permissif.
    test('un serveur antérieur garde l\'ancien comportement', () {
      final p = porte('''{
        "solde": {"disponible": 4000, "devise": "XOF"},
        "minimum_retrait": 5000, "reversements": [], "retraits": []
      }''');
      expect(p.minimumRetraitAbsolu, 5000);
    });
  });

  group('Le bouton de retrait', () {
    test('s\'ouvre dès le plancher absolu, pas au seuil gratuit', () {
      final p = porte(_reponse);
      // 4 000 F disponibles : sous le seuil gratuit, au-dessus du plancher.
      expect(p.retraitPossible, isTrue);
    });

    test('reste fermé sous le plancher absolu', () {
      final p = porte('''{
        "solde": {"disponible": 800, "devise": "XOF"},
        "minimum_retrait": 5000, "minimum_retrait_absolu": 1000,
        "frais_retrait": 100, "reversements": [], "retraits": []
      }''');
      expect(p.retraitPossible, isFalse);
    });
  });

  group('Ce que l\'auteur recevra', () {
    final p = porte(_reponse);

    test('au-dessus du seuil, le virement est offert', () {
      expect(p.fraisPour(5000), 0);
      expect(p.versePour(5000), 5000);
      expect(p.versePour(12000), 12000);
    });

    test('en dessous, les frais sont retenus', () {
      expect(p.fraisPour(2000), 100);
      expect(p.versePour(2000), 1900);
    });

    /// L'invariant : ce qui quitte le portefeuille est exactement ce qui est
    /// versé plus ce qui est retenu. Un écart, c'est de l'argent créé ou perdu.
    test('rien ne se perd entre le solde et l\'opérateur', () {
      for (final montant in [1000.0, 1234.0, 2500.0, 4999.0, 5000.0]) {
        final aligne = (montant / 5).floor() * 5.0;
        expect(
          p.versePour(montant) + p.fraisPour(montant),
          aligne,
          reason: '$montant F : la décomposition ne redonne pas le montant',
        );
      }
    });

    /// Les opérateurs Mobile Money de la zone XOF n'acceptent que des
    /// multiples de cinq : un montant versé qui n'en est pas un serait refusé.
    test('le montant versé respecte le palier de l\'opérateur', () {
      for (final montant in [1234.0, 2001.0, 4999.0, 3333.0]) {
        final verse = p.versePour(montant);
        expect(
          verse % 5,
          0,
          reason: '$montant F donne $verse, qui n\'est pas un multiple de 5',
        );
      }
    });

    test('un montant nul ne produit rien', () {
      expect(p.versePour(0), 0);
      expect(p.fraisPour(0), 0);
    });
  });

  /// La politique en vigueur : la plateforme prend les frais de transfert à sa
  /// charge. L'auteur touche exactement ce qu'il a gagné, dès sa première
  /// vente. Les tests ci-dessus activent des frais pour vérifier que le
  /// mécanisme reste juste s'il fallait le rallumer un jour.
  group('Quand la plateforme prend les frais à sa charge', () {
    final p = porte('''{
      "solde": {"disponible": 1600, "devise": "XOF"},
      "taux_commission": 0.20,
      "minimum_retrait": 5000,
      "minimum_retrait_absolu": 1000,
      "frais_retrait": 0,
      "reversements": [], "retraits": []
    }''');

    test('aucun frais n\'existe', () {
      expect(p.desFraisExistent, isFalse);
    });

    /// Le gain d'une seule vente au prix plancher — 2 000 F moins 20 % de
    /// commission — dépasse le minimum de virement.
    test('une vente au prix plancher ouvre le retrait', () {
      expect(p.retraitPossible, isTrue);
    });

    test('l\'auteur touche l\'intégralité de ce qu\'il a gagné', () {
      expect(p.fraisPour(1600), 0);
      expect(p.versePour(1600), 1600);
    });

    /// Y compris sous l'ancien seuil de 5 000 F, où des frais s'appliquaient.
    test('même sous l\'ancien seuil de gratuité', () {
      for (final montant in [1000.0, 2500.0, 4995.0]) {
        expect(p.fraisPour(montant), 0, reason: '$montant F');
        expect(p.versePour(montant), montant, reason: '$montant F');
      }
    });
  });
}
