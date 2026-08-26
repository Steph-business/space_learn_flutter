import 'package:flutter_test/flutter_test.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/book_model.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/reversement_model.dart';

/// Deux champs que le serveur émettait déjà et que l'application ne lisait pas.
///
/// Le serveur et le client se déploient séparément : une moitié peut donc
/// partir en ligne sans l'autre, et rien ne le signale — aucune erreur, aucun
/// écran cassé, simplement un chiffre qui reste faux et un mot technique
/// affiché à un auteur. Ces tests tiennent la moitié cliente.
void main() {
  Map<String, dynamic> livreBrut({String? creeLe, String? publieLe}) => {
    'id': 'b1',
    'titre': 'Le Chant des Lagunes',
    'prix': 2500,
    if (creeLe != null) 'cree_le': creeLe,
    if (publieLe != null) 'publie_le': publieLe,
  };

  group('Date de parution', () {
    test('la date de parution prime sur la date de création', () {
      final livre = BookModel.fromJson(
        livreBrut(creeLe: '2026-01-12T08:00:00Z', publieLe: '2026-08-20T14:30:00Z'),
      );

      expect(livre.publieLe, isNotNull);
      expect(livre.dateAAfficher!.month, 8,
          reason: "l'auteur a publié en août ; janvier est la date où il a "
              "ouvert une fiche vide");
      expect(livre.dateAAfficher!.year, 2026);
    });

    test('sans parution connue, on retombe sur la création', () {
      // C'est le cas de TOUT le catalogue antérieur : le serveur ne remplit
      // pas cette colonne rétroactivement, faute de savoir quand chaque livre
      // est réellement passé en vente.
      final livre = BookModel.fromJson(livreBrut(creeLe: '2025-11-03T10:00:00Z'));

      expect(livre.publieLe, isNull);
      expect(livre.dateAAfficher, isNotNull);
      expect(livre.dateAAfficher!.year, 2025);
      expect(livre.dateAAfficher!.month, 11);
    });

    test('sans aucune date, rien n’est inventé', () {
      final livre = BookModel.fromJson(livreBrut());
      expect(livre.dateAAfficher, isNull);
    });

    test('une date illisible ne fait pas disparaître le livre', () {
      // tryParse et non parse : une valeur mal formée côté serveur ferait
      // sinon échouer la désérialisation, et le livre s'évanouirait du
      // catalogue au lieu de s'afficher sans date.
      final livre = BookModel.fromJson({
        'id': 'b2',
        'titre': 'Sans date',
        'publie_le': 'pas-une-date',
      });

      expect(livre.titre, 'Sans date');
      expect(livre.publieLe, isNull);
    });

    test('la valeur survit à un aller-retour toJson / fromJson', () {
      final origine = BookModel.fromJson(
        livreBrut(creeLe: '2026-01-12T08:00:00Z', publieLe: '2026-08-20T14:30:00Z'),
      );
      final retour = BookModel.fromJson(origine.toJson());

      expect(retour.publieLe, origine.publieLe);
      expect(retour.dateAAfficher!.month, 8);
    });
  });

  group('Retrait au sort inconnu', () {
    RetraitModel retrait(String statut) => RetraitModel.fromJson({
      'id': 'r1',
      'montant': 12000,
      'statut': statut,
    });

    test('« incertain » ne s’affiche pas brut', () {
      final r = retrait('incertain');

      expect(r.estIncertain, isTrue);
      expect(r.libelleStatut, isNot('incertain'),
          reason: "l'auteur lisait le mot technique tout seul");
      expect(r.libelleStatut.length, greaterThan(15),
          reason: 'le libellé doit être une phrase, pas une étiquette');
    });

    test('le libellé dit que la somme attend une confirmation', () {
      final libelle = retrait('incertain').libelleStatut.toLowerCase();

      // Ce qui manquait à l'auteur, ce n'était pas un joli mot : c'était de
      // savoir pourquoi son solde ne remontait pas.
      expect(libelle, contains('attente'));
      expect(libelle, contains('opérateur'));
    });

    test('un virement incertain ne s’annule pas', () {
      // L'argent est peut-être déjà parti. Offrir « Annuler » laisserait croire
      // qu'on peut le rappeler.
      expect(retrait('incertain').estAnnulable, isFalse);
      expect(retrait('incertain').estPaye, isFalse);
      expect(retrait('incertain').estEnEchec, isFalse);
    });

    test('les autres statuts gardent leur libellé', () {
      expect(retrait('demandee').libelleStatut, 'En attente de traitement');
      expect(retrait('payee').libelleStatut, 'Versé');
      expect(retrait('annulee').libelleStatut, 'Annulé');
      expect(retrait('demandee').estAnnulable, isTrue);
    });

    test('un statut inconnu du client reste lisible tel quel', () {
      // Repli assumé : mieux vaut montrer une valeur inattendue que rien.
      expect(retrait('quelque_chose_de_neuf').libelleStatut,
          'quelque_chose_de_neuf');
    });
  });
}
