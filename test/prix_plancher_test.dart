import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/publication_settings_service.dart';

/// Les deux seuils du métier, vus depuis le formulaire de publication.
///
/// Un livre payant se vend à deux mille francs au minimum ; le virement devient
/// gratuit à partir de cinq mille. Les deux valeurs viennent du serveur :
/// recopiées dans l'application, elles auraient fini par diverger, et l'auteur
/// aurait rempli toute sa fiche avant d'être refusé.
ParametresPublication params(String corps) =>
    ParametresPublication.fromJson(jsonDecode(corps));

const _reponseServeur = '''{
  "visibilite_par_defaut": true,
  "licence_par_defaut": "Tous droits réservés",
  "devise_par_defaut": "FCFA",
  "part_auteur_pourcent": 80,
  "commission_pourcent": 20,
  "prix_conseille_min": 2000,
  "prix_conseille_max": 5000,
  "prix_minimum": 2000,
  "retrait_minimum": 5000,
  "retrait_minimum_absolu": 1000
}''';

void main() {
  group('Les seuils viennent du serveur', () {
    test('le plancher de vente et le seuil de retrait sont lus', () {
      final p = params(_reponseServeur);
      expect(p.prixMinimum, 2000);
      // C'est le plancher de virement qui répond à « quand pourrai-je toucher
      // mon argent ? », pas l'ancien seuil de gratuité.
      expect(p.retraitMinimum, 1000);
    });

    /// Un serveur pas encore déployé n'envoie pas ces deux bornes.
    /// L'application retombe sur les mêmes valeurs, sans échouer.
    test('un serveur antérieur ne fait pas échouer la lecture', () {
      final p = params('{"part_auteur_pourcent": 80}');
      expect(p.prixMinimum, 2000);
      expect(p.retraitMinimum, 1000);
    });

    /// On ne conseille jamais un prix que le serveur refuserait : la borne
    /// basse de la fourchette ne peut pas passer sous le plancher.
    test('la fourchette conseillée ne descend pas sous le plancher', () {
      final p = params(_reponseServeur);
      expect(p.prixConseilleMin, greaterThanOrEqualTo(p.prixMinimum));
    });
  });

  group('Ce que le formulaire refuse', () {
    final p = params(_reponseServeur);

    test('un prix sous le plancher', () {
      for (final prix in [1.0, 100.0, 1000.0, 1999.0]) {
        expect(
          p.sousLePlancher(prix),
          isTrue,
          reason: '$prix FCFA aurait été envoyé au serveur pour rien',
        );
      }
    });

    test('mais pas le plancher lui-même', () {
      expect(p.sousLePlancher(2000), isFalse);
      expect(p.sousLePlancher(3500), isFalse);
    });

    /// La gratuité est un choix explicite de l'auteur, proposé par une case à
    /// cocher. Ce n'est pas un prix trop bas : elle suit un autre chemin, sans
    /// encaissement.
    test('la gratuité n\'est pas un prix trop bas', () {
      expect(p.sousLePlancher(0), isFalse);
    });
  });

  group('Combien de ventes avant de toucher', () {
    final p = params(_reponseServeur);

    /// C'est ce qui relie les deux seuils, et ce qu'un auteur veut savoir en
    /// fixant son prix : au plancher, il perçoit mille six cents francs — soit
    /// plus que le minimum de virement. Sa toute première vente lui ouvre donc
    /// le retrait.
    test('au prix plancher, une seule vente suffit', () {
      expect(p.gainPour(2000), 1600);
      expect(p.ventesAvantRetrait(2000), 1);
    });

    test('à cinq mille francs, une vente aussi', () {
      expect(p.ventesAvantRetrait(5000), 1);
    });

    /// Le compte est arrondi vers le haut : une vente et demie ne se retire pas.
    test('le compte s\'arrondit vers le haut', () {
      // Un livre à 800 F rapporte 640 : il en faut deux pour passer 1 000.
      expect(p.ventesAvantRetrait(800), 2);
    });

    test('un livre gratuit ne mène à aucun retrait', () {
      expect(p.ventesAvantRetrait(0), 0);
    });
  });
}
