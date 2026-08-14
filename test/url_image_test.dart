import 'package:flutter_test/flutter_test.dart';
import 'package:space_learn_flutter/core/utils/api_routes.dart';

/// Le client ne peut pas savoir où le serveur a rangé un fichier.
///
/// Il construisait pourtant une URL vers un seau nommé « books » dès qu'il
/// recevait un chemin relatif. Ce seau n'existe pas — les couvertures vivent
/// dans « book_covers » et « covers » — si bien que chaque chemin relatif
/// produisait une adresse en « Bucket not found », une requête réseau inutile
/// et une exception dans la console, pour un fichier qu'on n'aurait de toute
/// façon pas trouvé.
void main() {
  group('URL absolue', () {
    test('une URL Supabase passe telle quelle', () {
      const url =
          'https://uqmydsydlkwxcfcdtsbu.supabase.co/storage/v1/object/public/book_covers/x.png';
      expect(ApiRoutes.sanitizeImageUrl(url, useGin: true), url);
    });

    test('une image en ligne passe telle quelle', () {
      const url = 'data:image/png;base64,iVBORw0KGgo=';
      expect(ApiRoutes.sanitizeImageUrl(url, useGin: true), url);
    });
  });

  group('Chemin relatif', () {
    test('un chemin relatif ne devient pas une URL inventée', () {
      // C'est le cas exact qui échouait : la valeur enregistrée pour
      // « PLUS MALIN QUE LE DIABLE » est un chemin, pas une adresse.
      const chemin =
          'books/d92bfd67-a440-407d-a75f-5a5f141c3fbd/cover_35c6eb96.png';
      expect(ApiRoutes.sanitizeImageUrl(chemin, useGin: true), isNull);
    });

    test('un chemin commençant par une barre non plus', () {
      expect(ApiRoutes.sanitizeImageUrl('/covers/x.png', useGin: true), isNull);
    });

    test('aucune URL construite ne mentionne le seau inexistant', () {
      for (final entree in [
        'books/a/b.png',
        '/books/a/b.png',
        'covers/x.png',
        'a.png',
      ]) {
        final resultat = ApiRoutes.sanitizeImageUrl(entree, useGin: true);
        expect(
          resultat,
          isNull,
          reason: '$entree a produit $resultat au lieu de rien',
        );
      }
    });
  });

  group('Rien', () {
    test('nul et vide donnent nul', () {
      expect(ApiRoutes.sanitizeImageUrl(null, useGin: true), isNull);
      expect(ApiRoutes.sanitizeImageUrl('', useGin: true), isNull);
    });
  });
}
