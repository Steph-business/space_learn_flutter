import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/messageModel.dart';

/// Modifier et retirer un propos, vus depuis l'application.
///
/// Avant, on pouvait supprimer mais jamais corriger une faute — la route
/// existait pourtant côté serveur, personne ne l'appelait. Et la suppression
/// était sèche : le propos disparaissait, laissant les réponses qu'il avait
/// suscitées suspendues dans le vide.
Message depuis(String corps) => Message.fromJson(jsonDecode(corps));

void main() {
  group('Lecture de la réponse serveur', () {
    test('un message ordinaire ne porte aucune marque', () {
      final m = depuis('''{
        "id": "m1", "discussion_id": "d1", "utilisateur_id": "u1",
        "contenu": "Ce roman m'a bouleversé.",
        "cree_le": "2026-08-18T10:00:00Z"
      }''');

      expect(m.supprime, isFalse);
      expect(m.modifie, isFalse);
      expect(m.peutModifier, isFalse);
      expect(m.texteAffiche, "Ce roman m'a bouleversé.");
    });

    test('un message réécrit porte la marque « modifié »', () {
      final m = depuis('''{
        "id": "m1", "discussion_id": "d1", "utilisateur_id": "u1",
        "contenu": "Ce roman m'a bouleversée.",
        "cree_le": "2026-08-18T10:00:00Z",
        "modifie": true, "peut_modifier": true
      }''');

      expect(m.modifie, isTrue);
      expect(m.peutModifier, isTrue);
    });

    /// Le serveur renvoie un contenu vide pour un message retiré : le texte est
    /// réellement effacé de la base. Sans le `?? ''`, la lecture plantait et
    /// c'était tout le fil qui disparaissait.
    test(
      'un message retiré revient sans contenu, sans faire échouer la lecture',
      () {
        final m = depuis('''{
        "id": "m1", "discussion_id": "d1", "utilisateur_id": "u1",
        "contenu": null,
        "cree_le": "2026-08-18T10:00:00Z",
        "supprime": true
      }''');

        expect(m.supprime, isTrue);
        expect(m.contenu, isEmpty);
        expect(m.texteAffiche, "Message retiré");
      },
    );

    /// WhatsApp ne fait pas la différence. Ici elle compte : quand le
    /// responsable d'un salon retire vos propos, vous devez le savoir.
    test(
      'un retrait par un tiers se distingue d\'un retrait par son auteur',
      () {
        final parSoi = depuis('''{
        "id": "m1", "discussion_id": "d1", "utilisateur_id": "u1",
        "contenu": "", "cree_le": "2026-08-18T10:00:00Z",
        "supprime": true, "retire_par_un_tiers": false
      }''');
        final parUnTiers = depuis('''{
        "id": "m2", "discussion_id": "d1", "utilisateur_id": "u1",
        "contenu": "", "cree_le": "2026-08-18T10:00:00Z",
        "supprime": true, "retire_par_un_tiers": true
      }''');

        expect(parSoi.texteAffiche, "Message retiré");
        expect(parUnTiers.texteAffiche, contains("modération"));
        expect(parSoi.texteAffiche, isNot(parUnTiers.texteAffiche));
      },
    );
  });

  group('Un message retiré ne se manipule plus', () {
    final retire = depuis('''{
      "id": "m1", "discussion_id": "d1", "utilisateur_id": "u1",
      "contenu": "", "cree_le": "2026-08-18T10:00:00Z",
      "supprime": true, "peut_modifier": false, "peut_supprimer": false
    }''');

    test('ni réécrit, ni retiré une seconde fois', () {
      expect(retire.peutModifier, isFalse);
      expect(retire.peutSupprimer, isFalse);
    });

    test('et il ne porte pas la marque « modifié »', () {
      expect(retire.modifie, isFalse);
    });
  });

  group('Reflet local d\'un retrait', () {
    /// Le retrait accepté par le serveur se reflète tout de suite, sans
    /// recharger le fil — et il emporte le texte, comme en base.
    test('retire() efface le contenu et ferme les gestes', () {
      final m = depuis('''{
        "id": "m1", "discussion_id": "d1", "utilisateur_id": "u1",
        "contenu": "Un propos que je regrette.",
        "cree_le": "2026-08-18T10:00:00Z",
        "peut_modifier": true, "peut_supprimer": true
      }''');

      final apres = m.retire();

      expect(apres.contenu, isEmpty);
      expect(apres.supprime, isTrue);
      expect(apres.peutModifier, isFalse);
      expect(apres.peutSupprimer, isFalse);
      expect(apres.id, m.id, reason: 'le message doit rester le même');
      expect(
        apres.creeLe,
        m.creeLe,
        reason: 'sa place dans le fil ne bouge pas',
      );
    });

    test('copyWith marque la réécriture sans toucher au reste', () {
      final m = depuis('''{
        "id": "m1", "discussion_id": "d1", "utilisateur_id": "u1",
        "contenu": "Ce roman m'a bouleversé.",
        "cree_le": "2026-08-18T10:00:00Z",
        "peut_modifier": true, "est_auteur_du_livre": true
      }''');

      final apres = m.copyWith(
        contenu: "Ce roman m'a bouleversée.",
        modifie: true,
      );

      expect(apres.contenu, "Ce roman m'a bouleversée.");
      expect(apres.modifie, isTrue);
      expect(apres.estAuteurDuLivre, isTrue);
      expect(apres.peutModifier, isTrue);
      expect(apres.supprime, isFalse);
    });
  });
}
