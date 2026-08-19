import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/discussionModel.dart';

/// Gérer un salon : le droit, et ce qu'une copie ne doit pas perdre.
Discussion depuis(String corps) => Discussion.fromJson(jsonDecode(corps));

void main() {
  group('Le droit de gérer vient du serveur', () {
    /// Il vaut pour qui a ouvert le sujet, mais aussi pour l'auteur du livre
    /// autour duquel le club s'est formé — un lien que seule la base connaît.
    /// Ce second titre n'existait pas : un écrivain ne pouvait pas fermer un
    /// club portant le nom de son propre ouvrage.
    test('peut_gerer est lu tel quel', () {
      final gere = depuis('''{
        "id": "d1", "titre": "Club de lecture", "peut_gerer": true
      }''');
      final simple = depuis('''{
        "id": "d2", "titre": "Club de lecture", "peut_gerer": false
      }''');

      expect(gere.peutGerer, isTrue);
      expect(simple.peutGerer, isFalse);
    });

    /// Un serveur d'une version antérieure n'envoie pas ce champ : on n'offre
    /// alors le geste à personne, plutôt qu'à tout le monde.
    test('sans le champ, le geste reste fermé', () {
      final d = depuis('{"id": "d1", "titre": "Club"}');
      expect(d.peutGerer, isFalse);
    });
  });

  group('Une copie ne perd rien', () {
    /// Le commentaire de `copyWith` décrit ce piège, et il était à l'œuvre
    /// juste au-dessus : la recopie manuelle qui ajuste le compteur de messages
    /// perdait `nomUtilisateur`, et aurait perdu `peutGerer` — le geste aurait
    /// disparu des seuls salons qui ont des messages, c'est-à-dire de tous ceux
    /// qui comptent.
    test('un salon avec des messages garde son nom et son droit', () {
      final d = depuis('''{
        "id": "d1",
        "titre": "Les Soleils des indépendances",
        "nom_utilisateur": "Stéphane",
        "peut_gerer": true,
        "messages": [
          {"id": "m1", "discussion_id": "d1", "utilisateur_id": "u1",
           "contenu": "Bonjour", "cree_le": "2026-08-18T10:00:00Z"}
        ]
      }''');

      expect(
        d.messagesCount,
        1,
        reason: 'le compteur doit suivre les messages',
      );
      expect(d.nomUtilisateur, 'Stéphane');
      expect(d.peutGerer, isTrue);
    });

    test('renommer conserve le reste', () {
      final d = depuis('''{
        "id": "d1", "titre": "Ancien titre", "description": "Une description",
        "nom_utilisateur": "Stéphane", "peut_gerer": true, "aime_par_moi": true
      }''');

      final apres = d.copyWith(titre: "Nouveau titre");

      expect(apres.titre, "Nouveau titre");
      expect(apres.description, "Une description");
      expect(apres.nomUtilisateur, "Stéphane");
      expect(apres.peutGerer, isTrue);
      expect(apres.aimeParMoi, isTrue);
      expect(apres.id, d.id);
    });

    test('corriger la description ne touche pas au titre', () {
      final d = depuis('''{
        "id": "d1", "titre": "Un titre", "description": "Ancienne"
      }''');

      final apres = d.copyWith(description: "Nouvelle");

      expect(apres.description, "Nouvelle");
      expect(apres.titre, "Un titre");
    });
  });
}
