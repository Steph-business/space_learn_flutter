import 'package:flutter_test/flutter_test.dart';

/// Reconnaître la page de retour de CinetPay.
///
/// Après paiement, CinetPay renvoie la webview sur l'URL de retour configurée
/// côté serveur : `CINETPAY_SUCCESS_URL` et `CINETPAY_FAILED_URL`, qui valent
/// `/paiement/succes` et `/paiement/echec`.
///
/// La détection cherchait `success`, en anglais. « succes » ne contient pas
/// « success » : la condition était donc toujours fausse, la webview restait
/// sur la page de retour, et l'application ne demandait jamais le statut du
/// paiement. L'argent était débité, l'achat n'aboutissait pas.
///
/// La règle est copiée ici parce qu'elle vit dans l'état d'un widget : la
/// tester à travers un rendu complet demanderait une webview, indisponible en
/// test. Ce qu'on vérifie, c'est la règle elle-même — et le cas qui a échoué.
bool estUrlDeRetour(String url) {
  if (url.contains('cinetpay')) return false;

  final minuscules = url.toLowerCase();
  return minuscules.contains('/paiement/') ||
      minuscules.contains('succes') ||
      minuscules.contains('echec') ||
      minuscules.contains('success') ||
      minuscules.contains('failed') ||
      minuscules.contains('return') ||
      minuscules.contains('cancel') ||
      minuscules.contains('spacelearn');
}

/// L'hôte des URL d'exemple ci-dessous est une adresse réservée à la
/// documentation (RFC 5737), pas celle de la production : la règle testée ne
/// regarde que le CHEMIN et les mots de l'URL, jamais la machine. Un test qui
/// nommerait le serveur réel deviendrait faux le jour du nom de domaine, et
/// figerait cette adresse dans un dépôt public pour rien.
void main() {
  group('Les URL réellement configurées sont reconnues', () {
    test('le retour de succès en français', () {
      expect(estUrlDeRetour('http://203.0.113.10/paiement/succes'), isTrue);
    });

    test('le retour d\'échec en français', () {
      expect(estUrlDeRetour('http://203.0.113.10/paiement/echec'), isTrue);
    });

    /// Le jour où le site sera servi en HTTPS sur un domaine, l'URL changera
    /// d'hôte mais pas de chemin.
    test('la même adresse sur un domaine en https', () {
      expect(
        estUrlDeRetour('https://spacelearn.app/paiement/succes?transaction_id=ABC'),
        isTrue,
      );
    });

    test('les variantes anglaises restent acceptées', () {
      expect(estUrlDeRetour('https://exemple.com/payment/success'), isTrue);
      expect(estUrlDeRetour('https://exemple.com/payment/failed'), isTrue);
    });
  });

  group('Les pages de CinetPay ne sont pas des retours', () {
    /// Le point le plus important : tant qu'on est CHEZ CinetPay, on paie. Un
    /// faux positif ici couperait le paiement en plein milieu.
    test('la page de paiement elle-même', () {
      expect(estUrlDeRetour('https://checkout.cinetpay.com/payment/abc123'), isFalse);
    });

    test('même si son adresse contient le mot succes', () {
      expect(
        estUrlDeRetour('https://checkout.cinetpay.com/succes/etape2'),
        isFalse,
      );
    });
  });

  /// Le défaut d'origine, écrit noir sur blanc : l'ancienne règle laissait
  /// passer les deux URL réellement configurées.
  test('l\'ancienne règle échouait sur les URL françaises', () {
    bool ancienneRegle(String url) =>
        url.contains('cinetpay') == false &&
        (url.contains('success') ||
            url.contains('return') ||
            url.contains('cancel') ||
            url.contains('spacelearn'));

    expect(ancienneRegle('http://203.0.113.10/paiement/succes'), isFalse);
    expect(ancienneRegle('http://203.0.113.10/paiement/echec'), isFalse);
  });
}
