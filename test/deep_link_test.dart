import 'package:flutter_test/flutter_test.dart';
import 'package:space_learn_flutter/core/services/deep_link_service.dart';

void main() {
  group('Extraction du livre depuis un lien de recommandation', () {
    test('lien web standard', () {
      expect(
        DeepLinkService.extraireLivreID(
          Uri.parse('https://api.exemple.ci/book/abc-123'),
        ),
        'abc-123',
      );
    });

    test('barre oblique finale', () {
      expect(
        DeepLinkService.extraireLivreID(
          Uri.parse('https://api.exemple.ci/book/abc-123/'),
        ),
        'abc-123',
      );
    });

    test('paramètres de campagne ajoutés au lien', () {
      expect(
        DeepLinkService.extraireLivreID(
          Uri.parse('https://api.exemple.ci/book/abc-123?utm_source=whatsapp'),
        ),
        'abc-123',
      );
    });

    test('schéma applicatif', () {
      expect(
        DeepLinkService.extraireLivreID(Uri.parse('spacelearn://book/abc-123')),
        'abc-123',
      );
    });

    test('lien sans identifiant', () {
      expect(
        DeepLinkService.extraireLivreID(
          Uri.parse('https://api.exemple.ci/book'),
        ),
        isNull,
      );
    });

    test('lien étranger à l’application', () {
      expect(
        DeepLinkService.extraireLivreID(
          Uri.parse('https://api.exemple.ci/paiement/succes'),
        ),
        isNull,
      );
    });
  });
}
