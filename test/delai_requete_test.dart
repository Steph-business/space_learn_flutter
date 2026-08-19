import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:space_learn_flutter/core/services/api_client.dart';
import 'package:space_learn_flutter/core/utils/message_erreur.dart';

/// Le délai des requêtes, et ce qu'il change à l'écran.
///
/// Sur les cent trente-six requêtes de l'application, cinq portaient un délai.
/// Une requête qui n'aboutit jamais ne lève rien : aucun `catch` ne se
/// déclenche, aucun message n'est affiché, et l'écran reste sur son indicateur
/// de chargement — indéfiniment, sans bouton et sans recours. C'est la même
/// panne que celle qui figeait l'écran de lancement, à cent trente-six
/// endroits.
///
/// `ApiClient` est un singleton qui parle au vrai réseau : ces tests portent
/// donc sur la règle qu'il applique, appelée ici telle quelle, et sur la
/// phrase que l'écran en tire.
void main() {
  group('Quelles requêtes sont bornées', () {
    test('une requête ordinaire l\'est', () {
      final requete = http.Request(
        'GET',
        Uri.parse('https://exemple.ci/livres'),
      );

      expect(ApiClient.estBornee(requete), isTrue);
    });

    /// Un manuscrit de plusieurs dizaines de méga-octets, sur un réseau lent,
    /// dépasse largement les trente secondes. Le borner comme une lecture
    /// couperait l'envoi en cours de route : l'auteur perdrait son dépôt à
    /// chaque tentative, et d'autant plus sûrement que sa connexion est
    /// mauvaise.
    test('un dépôt de fichier ne l\'est pas', () {
      final envoi = http.StreamedRequest(
        'POST',
        Uri.parse('https://exemple.ci/livres/upload'),
      );

      expect(ApiClient.estBornee(envoi), isFalse);
    });

    test('un envoi multipart non plus', () {
      final envoi = http.MultipartRequest(
        'POST',
        Uri.parse('https://exemple.ci/livres/upload'),
      );

      expect(ApiClient.estBornee(envoi), isFalse);
    });

    /// Trente secondes : assez pour une réponse qui traîne sur un réseau
    /// mobile, trop peu pour qu'on croie l'application bloquée.
    test('le délai reste dans la fourchette utile', () {
      expect(ApiClient.delaiRequete.inSeconds, greaterThanOrEqualTo(15));
      expect(ApiClient.delaiRequete.inSeconds, lessThanOrEqualTo(60));
    });
  });

  group('Ce que la personne lit quand le délai tombe', () {
    /// La phrase existait déjà dans messageLisible. Ce qui manquait, c'était
    /// une requête capable de la déclencher.
    test('un délai dépassé se dit en français, et dit quoi vérifier', () {
      final phrase = messageLisible(TimeoutException('délai'));

      expect(phrase, contains('trop de temps'));
      expect(phrase, contains('connexion'));
      expect(phrase, isNot(contains('TimeoutException')));
    });
  });
}
