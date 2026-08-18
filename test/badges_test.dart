import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/badgeModel.dart';

/// Les badges verrouillés font désormais partie de la réponse.
///
/// L'écran n'affichait que les trophées obtenus : un lecteur qui en avait deux
/// voyait deux cartes et rien d'autre, sans savoir combien il en existe ni ce
/// qu'il approchait. Le serveur renvoie le catalogue entier, `debloque_le` à
/// null pour ce qui reste à décrocher.
void main() {
  group('Lecture de la réponse serveur', () {
    test('un badge débloqué porte sa date', () {
      final badge = BadgeModel.fromJson(
        jsonDecode('''{
          "id": "11111111-1111-1111-1111-111111111111",
          "utilisateur_id": "22222222-2222-2222-2222-222222222222",
          "debloque_le": "2026-08-01T10:00:00Z",
          "progression": 1,
          "cible": 1,
          "famille": "Lecture",
          "badge": {
            "nom": "Premier de la classe",
            "description": "Vous avez terminé votre premier livre",
            "icone_url": "auto_stories",
            "code": "FIRST_BOOK"
          }
        }'''),
      );

      expect(badge.estDebloque, isTrue);
      expect(badge.name, 'Premier de la classe');
      expect(badge.famille, 'Lecture');
      expect(badge.avancement, 1.0);
    });

    test('un badge verrouillé porte sa distance', () {
      final badge = BadgeModel.fromJson(
        jsonDecode('''{
          "id": "00000000-0000-0000-0000-000000000000",
          "utilisateur_id": "22222222-2222-2222-2222-222222222222",
          "debloque_le": null,
          "progression": 24,
          "cible": 25,
          "famille": "Traces de lecture",
          "badge": {
            "nom": "Plume dans la marge",
            "description": "Vingt-cinq annotations",
            "icone_url": "edit_note",
            "code": "ANNOTATEUR"
          }
        }'''),
      );

      expect(badge.estDebloque, isFalse);
      expect(badge.progression, 24);
      expect(badge.cible, 25);
      expect(badge.avancement, closeTo(0.96, 0.001));
    });

    /// Un serveur d'une version antérieure n'envoie ni progression ni cible.
    /// L'écran doit rester lisible plutôt que de tomber.
    test('une réponse sans avancement ne casse rien', () {
      final badge = BadgeModel.fromJson(
        jsonDecode('''{
          "id": "1",
          "utilisateur_id": "2",
          "debloque_le": null,
          "badge": {"nom": "X", "description": "Y", "icone_url": "z", "code": "C"}
        }'''),
      );

      expect(badge.progression, 0);
      expect(badge.cible, 0);
      expect(badge.famille, '');
      expect(badge.avancement, 0.0);
    });

    /// Une date illisible ne doit pas faire échouer toute la collection.
    ///
    /// `DateTime.parse` lève ; l'exception remontait jusqu'au `catch` du
    /// service, qui rendait alors une liste vide — un seul champ malformé
    /// effaçait les dix-huit badges.
    test('une date illisible laisse le badge verrouillé', () {
      final badge = BadgeModel.fromJson(
        jsonDecode('''{
          "id": "1",
          "utilisateur_id": "2",
          "debloque_le": "pas-une-date",
          "badge": {"nom": "X", "description": "Y", "icone_url": "z", "code": "C"}
        }'''),
      );

      expect(badge.estDebloque, isFalse);
    });
  });

  group('Avancement', () {
    test('ne dépasse jamais un', () {
      final badge = BadgeModel(
        id: '1',
        utilisateurId: '2',
        name: 'X',
        description: 'Y',
        iconUrl: 'z',
        code: 'C',
        progression: 80,
        cible: 50,
      );
      expect(badge.avancement, 1.0);
    });

    test('une cible nulle ne divise pas par zéro', () {
      final badge = BadgeModel(
        id: '1',
        utilisateurId: '2',
        name: 'X',
        description: 'Y',
        iconUrl: 'z',
        code: 'C',
        progression: 3,
        cible: 0,
      );
      expect(badge.avancement, 0.0);
    });

    test('un badge débloqué est plein même sans cible renseignée', () {
      final badge = BadgeModel(
        id: '1',
        utilisateurId: '2',
        debloqueLe: DateTime(2026, 8, 1),
        name: 'X',
        description: 'Y',
        iconUrl: 'z',
        code: 'C',
      );
      expect(badge.avancement, 1.0);
    });
  });

  test('un aller-retour JSON conserve tout', () {
    final origine = BadgeModel(
      id: '1',
      utilisateurId: '2',
      debloqueLe: DateTime.utc(2026, 8, 1, 10),
      name: 'Semaine pleine',
      description: 'Sept jours de lecture d\'affilée',
      iconUrl: 'local_fire_department',
      code: 'SERIE_7',
      progression: 7,
      cible: 7,
      famille: 'Assiduité',
    );

    final copie = BadgeModel.fromJson(jsonDecode(jsonEncode(origine.toJson())));

    expect(copie.code, origine.code);
    expect(copie.famille, origine.famille);
    expect(copie.progression, origine.progression);
    expect(copie.cible, origine.cible);
    expect(copie.debloqueLe?.toUtc(), origine.debloqueLe);
  });
}
