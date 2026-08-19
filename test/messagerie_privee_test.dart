import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/conversation_model.dart';

/// La messagerie privée, côté lecture des réponses.
///
/// Elle n'existait pas dans l'application : le serveur l'exposait — mal monté,
/// mais écrit — et l'écran affichait un « Aucun message » codé en dur, sans
/// jamais rien demander.
Conversation conv(String corps) => Conversation.fromJson(jsonDecode(corps));

void main() {
  group('Une conversation telle que le serveur la rend', () {
    test('le correspondant, l\'aperçu et les non-lus sont lus', () {
      final c = conv('''{
        "id": "c1",
        "correspondant": {"id": "u2", "nom": "Bob Kouassi", "photo": "p.jpg"},
        "dernier_message": {
          "contenu": "Votre livre m'a beaucoup plu.",
          "cree_le": "2026-08-18T10:00:00Z",
          "de_moi": false
        },
        "non_lus": 3
      }''');

      expect(c.id, 'c1');
      expect(c.correspondant.nom, 'Bob Kouassi');
      expect(c.dernierMessage!.contenu, "Votre livre m'a beaucoup plu.");
      expect(c.dernierMessage!.deMoi, isFalse);
      expect(c.nonLus, 3);
    });

    /// Un fil qu'on vient d'ouvrir n'a pas encore de message : les colonnes du
    /// dernier message sont nulles côté serveur, et l'aperçu doit rester nul
    /// plutôt que d'afficher une ligne vide.
    test('un fil sans message se lit sans aperçu', () {
      final c = conv('''{
        "id": "c1",
        "correspondant": {"id": "u2", "nom": "Bob", "photo": null},
        "dernier_message": null,
        "non_lus": 0
      }''');

      expect(c.dernierMessage, isNull);
      expect(c.nonLus, 0);
    });

    /// Un compte supprimé côté auth laisse un correspondant sans nom : le fil
    /// doit rester lisible plutôt que de faire échouer toute la liste.
    test('un correspondant incomplet ne fait pas échouer la lecture', () {
      final c = conv('''{
        "id": "c1",
        "correspondant": {"id": "u2"},
        "non_lus": 0
      }''');

      expect(c.correspondant.id, 'u2');
      expect(c.correspondant.nom, isEmpty);
      expect(c.dernierMessage, isNull);
    });
  });

  group('De quel côté se range une bulle', () {
    /// Le serveur calcule `de_moi` : lui seul connaît avec certitude l'identité
    /// derrière le jeton.
    test('le serveur fait foi', () {
      final mien = MessagePrive.fromJson(
        jsonDecode('''{
          "id": "m1", "expediteur_id": "u1", "contenu": "Bonjour",
          "cree_le": "2026-08-18T10:00:00Z", "de_moi": true
        }'''),
      );
      expect(mien.deMoi, isTrue);
    });

    /// Quand il ne l'envoie pas, on compare — et à défaut d'identifiant, la
    /// bulle part à gauche : se tromper de côté est moins grave qu'attribuer
    /// un propos à quelqu'un d'autre.
    test('à défaut, la comparaison, puis la prudence', () {
      const brut = '''{
        "id": "m1", "expediteur_id": "u1", "contenu": "Bonjour",
        "cree_le": "2026-08-18T10:00:00Z"
      }''';

      expect(
        MessagePrive.fromJson(jsonDecode(brut), moiId: 'u1').deMoi,
        isTrue,
      );
      expect(
        MessagePrive.fromJson(jsonDecode(brut), moiId: 'u2').deMoi,
        isFalse,
      );
      expect(MessagePrive.fromJson(jsonDecode(brut)).deMoi, isFalse);
    });
  });

  group('L\'heure affichée', () {
    final maintenant = DateTime(2026, 8, 18, 15, 30);

    test('aujourd\'hui, l\'heure', () {
      final h = heureCourte(
        DateTime(2026, 8, 18, 9, 5),
        maintenant: maintenant,
      );
      expect(h, '09:05');
    });

    test('hier se dit « Hier »', () {
      expect(
        heureCourte(DateTime(2026, 8, 17, 9, 5), maintenant: maintenant),
        'Hier',
      );
    });

    test('au-delà de la semaine, la date', () {
      final h = heureCourte(DateTime(2026, 7, 1, 9, 5), maintenant: maintenant);
      expect(h, '01/07/2026');
    });

    /// L'horloge d'un téléphone et celle d'un serveur ne sont jamais tout à
    /// fait d'accord : une date légèrement à venir ne doit pas produire
    /// d'affichage absurde.
    test('une date à venir se lit comme maintenant', () {
      final h = heureCourte(
        DateTime(2026, 8, 18, 15, 35),
        maintenant: maintenant,
      );
      expect(h, '15:35');
    });
  });
}
