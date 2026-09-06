import 'package:flutter_test/flutter_test.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/evenementModel.dart';

/// Ce que le modèle Evenement promet, et que rien n'observait.
///
/// `toJson` n'a aujourd'hui aucun appelant : le service construit ses corps de
/// requête à la main. Un sérialiseur que personne n'exerce dérive sans bruit —
/// celui-ci avait déjà perdu `categorie` — et le jour où quelqu'un le
/// rebranche, c'est en production que la faute se voit. Ces deux aller-retours
/// le tiennent : la symétrie devient observable.
///
/// Même chose pour `copyWith`, dont l'ancêtre — une recopie champ par champ
/// dans l'espace auteur — avait fait disparaître le lien de visio et la
/// mention « Terminé ».
void main() {
  group('toJson puis fromJson rendent le même événement', () {
    test("l'instant du rendez-vous survit à l'aller-retour", () {
      // Une date LOCALE, comme celle que `fromJson` produit : c'est le cas qui
      // faisait dériver l'heure. `toIso8601String()` sur une date locale ne
      // porte aucun indicateur de fuseau ; relue, elle serait prise pour de
      // l'UTC et le rendez-vous se décalerait du décalage de l'appareil, à
      // chaque enregistrement. Le suffixe « Z » de `toUtc()` ferme la boucle,
      // et ce test le vérifie sur le fuseau réel de la machine qui l'exécute.
      final rendezVous = DateTime(2027, 3, 14, 18, 30);
      final creation = DateTime(2027, 3, 1, 9, 15);

      final avant = Evenement(
        id: 'evt-1',
        typePublication: 'EVENEMENT',
        categorie: 'Séance de Dédicace',
        titre: 'Dédicace à Cotonou',
        contenu: 'Venez nombreux.',
        imageUrl: 'https://exemple.test/affiche.jpg',
        dateEvenement: rendezVous,
        auteurId: 'auteur-7',
        nomAuteur: 'Awa Diallo',
        creeLe: creation,
        lienVisio: 'https://meet.exemple.test/dedicace',
      );

      final apres = Evenement.fromJson(avant.toJson());

      expect(apres.dateEvenement, rendezVous);
      expect(apres.creeLe, creation);
      expect(apres.dateEvenement!.isAtSameMomentAs(rendezVous), isTrue);
    });

    test('aucun champ ne se perd en route', () {
      final avant = Evenement(
        id: 'evt-2',
        typePublication: 'ANNONCE',
        categorie: 'Live Q&A',
        titre: 'Rencontre en ligne',
        contenu: 'Questions et réponses.',
        imageUrl: 'https://exemple.test/live.jpg',
        // Une date que le temps ne rattrapera pas : `passe` est recalculé
        // localement en repli, et ce test doit dire la même chose dans dix ans.
        dateEvenement: DateTime(2099, 5, 2, 20, 0),
        auteurId: 'auteur-9',
        nomAuteur: 'Koffi N’Guessan',
        creeLe: DateTime(2099, 4, 20, 8, 0),
        lienVisio: 'https://meet.exemple.test/live',
      );

      final apres = Evenement.fromJson(avant.toJson());

      expect(apres.id, avant.id);
      expect(apres.typePublication, avant.typePublication);
      // Perdue par `toJson` avant ce lot : elle porte la nature réelle de la
      // publication, que `typePublication` ne dit pas.
      expect(apres.categorie, avant.categorie);
      expect(apres.titre, avant.titre);
      expect(apres.contenu, avant.contenu);
      expect(apres.imageUrl, avant.imageUrl);
      expect(apres.auteurId, avant.auteurId);
      expect(apres.nomAuteur, avant.nomAuteur);
      expect(apres.lienVisio, avant.lienVisio);
      // Un rendez-vous à venir ne revient pas « Terminé ».
      expect(apres.passe, isFalse);
    });

    test('un rendez-vous déjà tenu le reste', () {
      final avant = Evenement(
        id: 'evt-3',
        typePublication: 'EVENEMENT',
        titre: 'Atelier passé',
        contenu: 'C’était hier.',
        dateEvenement: DateTime(2020, 1, 1, 10, 0),
        auteurId: 'auteur-3',
        passe: true,
      );

      expect(Evenement.fromJson(avant.toJson()).passe, isTrue);
    });
  });

  group('copyWith ne perd rien', () {
    test('le nom change, les onze autres champs restent', () {
      final origine = Evenement(
        id: 'evt-4',
        typePublication: 'EVENEMENT',
        categorie: 'Séance de Dédicace',
        titre: 'Signature',
        contenu: 'Au salon du livre.',
        imageUrl: 'https://exemple.test/signature.jpg',
        dateEvenement: DateTime(2020, 6, 1, 15, 0),
        auteurId: 'auteur-4',
        creeLe: DateTime(2020, 5, 1, 11, 0),
        lienVisio: 'https://meet.exemple.test/signature',
        passe: true,
      );

      final complete = origine.copyWith(nomAuteur: 'Awa Diallo');

      expect(complete.nomAuteur, 'Awa Diallo');
      expect(complete.id, origine.id);
      expect(complete.typePublication, origine.typePublication);
      expect(complete.categorie, origine.categorie);
      expect(complete.titre, origine.titre);
      expect(complete.contenu, origine.contenu);
      expect(complete.imageUrl, origine.imageUrl);
      expect(complete.dateEvenement, origine.dateEvenement);
      expect(complete.auteurId, origine.auteurId);
      expect(complete.creeLe, origine.creeLe);
      // Les deux champs que la recopie champ par champ avait perdus.
      expect(complete.lienVisio, origine.lienVisio);
      expect(complete.passe, isTrue);
    });

    test('sans argument, la copie est identique champ pour champ', () {
      final origine = Evenement(
        id: 'evt-5',
        typePublication: 'ANNONCE',
        titre: 'Note',
        contenu: 'Rien de particulier.',
        auteurId: 'auteur-5',
        nomAuteur: 'Awa Diallo',
      );

      // `nomAuteur` déjà renseigné : la copie ne doit pas l'effacer.
      expect(origine.copyWith().nomAuteur, 'Awa Diallo');
    });
  });
}
