import 'package:flutter_test/flutter_test.dart';
import 'package:space_learn_flutter/core/utils/parcours.dart';

/// Qui suit le parcours auteur.
///
/// La question se posait dans quatre écrans, avec quatre réponses différentes :
/// la connexion acceptait « auteur », « administrateur », « éditeur » ; le
/// démarrage y ajoutait « ecrivain » ; la barre de navigation exigeait
/// l'égalité stricte avec « auteur » — si bien qu'un éditeur ou un
/// administrateur se voyait ouvrir le guide du LECTEUR depuis son propre
/// espace.
///
/// Une seule règle, désormais, et elle est vérifiée ici.
void main() {
  group('Le parcours auteur', () {
    test('un auteur en est', () {
      expect(estParcoursAuteur('auteur'), isTrue);
      expect(estParcoursAuteur('Auteur'), isTrue);
      expect(estParcoursAuteur('  AUTEUR  '), isTrue);
    });

    /// Le cas que l'égalité stricte laissait de côté.
    test('un éditeur et un administrateur aussi', () {
      for (final role in [
        'éditeur',
        'editeur',
        'Éditeur',
        'admin',
        'Administrateur',
        'super admin',
      ]) {
        expect(estParcoursAuteur(role), isTrue, reason: role);
      }
    });

    test('un écrivain aussi, quelle que soit la graphie', () {
      expect(estParcoursAuteur('ecrivain'), isTrue);
      expect(estParcoursAuteur('écrivain'), isTrue);
    });

    /// « Lecteur » est stocké en base avec une espace finale.
    test('un lecteur n\'en est pas', () {
      for (final role in ['lecteur', 'Lecteur ', 'LECTEUR', ' lecteur ']) {
        expect(estParcoursAuteur(role), isFalse, reason: role);
      }
    });

    /// On ne présume pas de droits qu'on n'a pas lus.
    test('un rôle absent ou inconnu n\'en est pas', () {
      expect(estParcoursAuteur(null), isFalse);
      expect(estParcoursAuteur(''), isFalse);
      expect(estParcoursAuteur('   '), isFalse);
      expect(estParcoursAuteur('visiteur'), isFalse);
    });
  });

  group('Le parcours lecteur', () {
    test('reconnaît un lecteur', () {
      expect(estParcoursLecteur('Lecteur '), isTrue);
      expect(estParcoursLecteur('lecteur'), isTrue);
    });

    test('exclut les rôles d\'auteur', () {
      for (final role in ['auteur', 'éditeur', 'admin', 'super admin']) {
        expect(estParcoursLecteur(role), isFalse, reason: role);
      }
    });

    /// Ce n'est pas la négation stricte : un rôle vide n'est ni l'un ni
    /// l'autre, et l'appelant doit pouvoir le distinguer.
    test('un rôle absent n\'est ni l\'un ni l\'autre', () {
      expect(estParcoursAuteur(null), isFalse);
      expect(estParcoursLecteur(null), isFalse);
    });
  });

  /// Les deux ne peuvent jamais être vrais ensemble : c'est ce qui garantit
  /// qu'un écran ne montrera pas les deux parcours à la fois.
  test('personne ne suit les deux parcours', () {
    for (final role in [
      'auteur',
      'lecteur',
      'Lecteur ',
      'éditeur',
      'admin',
      'super admin',
      'ecrivain',
      '',
      'inconnu',
    ]) {
      expect(
        estParcoursAuteur(role) && estParcoursLecteur(role),
        isFalse,
        reason: role,
      );
    }
  });
}
