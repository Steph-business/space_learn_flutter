import 'package:flutter_test/flutter_test.dart';
import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/notificationModel.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/auteur/accueil/notification_recent.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/notification_provider.dart';

/// Deux défauts vus sur un même écran, sur une capture d'un vrai téléphone.
///
/// L'acheteur avait payé deux fois le livre « Allo » : la première tentative
/// avait échoué, la seconde abouti. Son écran de notifications montrait donc
/// l'échec EN HAUT — au-dessus de la réussite qui l'avait suivi — et le
/// présentait en VERT, la même couleur que le succès juste en dessous.
///
/// Les deux erreurs se renforçaient : la couleur disait « tout va bien », la
/// position disait « c'est le dernier état ». Un acheteur qui lit une pastille
/// verte et un mot en tête de liste n'a aucune raison d'aller lire le texte.
void main() {
  group('La couleur ne doit pas démentir le texte', () {
    test('un paiement échoué n’est pas vert', () {
      // « paiement_echoue » CONTIENT « paiement » : c'est cette inclusion qui
      // le faisait tomber dans le cas du succès.
      expect(
        couleurDuTypeDeNotification('paiement_echoue'),
        isNot(AppColors.success),
      );
      expect(couleurDuTypeDeNotification('paiement_echoue'), AppColors.error);
    });

    test('un paiement réussi reste vert', () {
      expect(couleurDuTypeDeNotification('paiement'), AppColors.success);
      expect(couleurDuTypeDeNotification('achat'), AppColors.success);
      expect(couleurDuTypeDeNotification('vente'), AppColors.success);
    });

    test('l’icône suit la couleur', () {
      // Une pastille rouge sous une icône de portefeuille serait pire que le
      // défaut d'origine : deux signaux qui se contredisent.
      expect(
        iconeDuTypeDeNotification('paiement_echoue'),
        isNot(iconeDuTypeDeNotification('paiement')),
      );
    });

    test('les autres formes d’échec sont couvertes', () {
      for (final type in [
        'paiement_echoue',
        'commande_annulee',
        'virement_refuse',
        'payment_failed',
      ]) {
        expect(notificationEstUnEchec(type), isTrue, reason: type);
        expect(
          couleurDuTypeDeNotification(type),
          AppColors.error,
          reason: type,
        );
      }
    });

    test('un succès n’est jamais pris pour un échec', () {
      for (final type in ['paiement', 'achat', 'vente', 'avis', 'message']) {
        expect(notificationEstUnEchec(type), isFalse, reason: type);
      }
    });

    test('le libellé porte ses accents', () {
      expect(libelleTypeNotification('paiement_echoue'), 'PAIEMENT ÉCHOUÉ');
    });
  });

  group('L’ordre de la liste', () {
    NotificationModel notif(String id, DateTime? date) => NotificationModel(
      id: id,
      utilisateurId: 'u1',
      type: 'paiement',
      contenu: 'm',
      lu: false,
      creeLe: date,
    );

    test('la plus récente vient en tête', () {
      final liste = [
        notif('a', DateTime(2026, 8, 25, 10, 0)),
        notif('b', DateTime(2026, 8, 25, 12, 0)),
        notif('c', DateTime(2026, 8, 25, 11, 0)),
      ];

      final triee = trierDuPlusRecent(liste);

      expect(triee.map((n) => n.id).toList(), ['b', 'c', 'a']);
    });

    test('deux notifications de la même seconde gardent un ordre stable', () {
      // C'est le cas réel : l'échec et la réussite écrits dans la même seconde.
      // Sans départage, compareTo rend zéro et l'ordre dépend de celui où la
      // base a rendu les lignes — c'est-à-dire de rien.
      final memeInstant = DateTime(2026, 8, 25, 14, 30, 0);
      final ordreUn = trierDuPlusRecent([
        notif('aaa', memeInstant),
        notif('zzz', memeInstant),
      ]).map((n) => n.id).toList();
      final ordreDeux = trierDuPlusRecent([
        notif('zzz', memeInstant),
        notif('aaa', memeInstant),
      ]).map((n) => n.id).toList();

      expect(
        ordreUn,
        ordreDeux,
        reason: "l'ordre d'arrivée ne doit pas changer le résultat",
      );
    });

    test('une notification sans date ne remonte pas en tête', () {
      // Le tri précédent remplaçait une date absente par DateTime.now() : elle
      // devenait donc la plus récente de toutes.
      final triee = trierDuPlusRecent([
        notif('sans_date', null),
        notif('datee', DateTime(2026, 8, 25, 9, 0)),
      ]);

      expect(triee.first.id, 'datee');
      expect(triee.last.id, 'sans_date');
    });

    test('une liste vide ou d’un seul élément ne casse pas', () {
      expect(trierDuPlusRecent([]), isEmpty);
      expect(trierDuPlusRecent([notif('seule', null)]).length, 1);
    });

    test('la liste d’origine n’est pas modifiée', () {
      final origine = [
        notif('a', DateTime(2026, 8, 25, 10, 0)),
        notif('b', DateTime(2026, 8, 25, 12, 0)),
      ];
      trierDuPlusRecent(origine);
      expect(origine.first.id, 'a', reason: 'le tri doit rendre une copie');
    });
  });
}
