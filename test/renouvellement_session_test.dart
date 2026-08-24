import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:space_learn_flutter/core/services/api_client.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/tokenUser.dart';

/// Le renouvellement de session, vu depuis l'application.
///
/// Le jeton d'accès ne vit plus qu'une heure. Sans renouvellement automatique,
/// le lecteur serait renvoyé à l'écran de connexion en pleine lecture, toutes
/// les heures — l'inverse de ce qu'on cherchait.
///
/// `ApiClient` est un singleton qui parle au vrai réseau : ces tests portent
/// donc sur les règles qu'il applique, reproduites ici à l'identique, et sur la
/// lecture des réponses du serveur.
void main() {
  group('Lecture de la réponse de connexion', () {
    test('le couple de jetons est retenu', () {
      final tokenUser = TokenUser.fromJson(
        jsonDecode('''{
          "token": "jeton.acces.court",
          "refresh_token": "jeton-de-rafraichissement",
          "user": {"id": "u1", "nom_complet": "Stéphane", "email": "s@x.ci"}
        }'''),
      );

      expect(tokenUser.token, 'jeton.acces.court');
      expect(tokenUser.refreshToken, 'jeton-de-rafraichissement');
    });

    /// Un serveur pas encore déployé ne renvoie pas ce champ. L'application
    /// doit continuer de fonctionner, avec une session plus courte.
    test(
      'un serveur sans rafraîchissement ne fait pas échouer la connexion',
      () {
        final tokenUser = TokenUser.fromJson(
          jsonDecode('''{
          "token": "jeton.acces",
          "user": {"id": "u1", "nom_complet": "Stéphane", "email": "s@x.ci"}
        }'''),
        );

        expect(tokenUser.token, 'jeton.acces');
        expect(tokenUser.refreshToken, isEmpty);
      },
    );
  });

  group('Quand renouveler, et quand abandonner', () {
    /// Ces tests appellent la vraie règle, et c'est le correctif.
    ///
    /// Ils recopiaient auparavant la décision à la main — `code == 401` — et
    /// vérifiaient donc l'intention plutôt que le code. Les deux avaient
    /// divergé : le commentaire d'ApiClient promettait qu'une panne ne
    /// déconnectait personne, la fonction rendait `false` dans tous les cas,
    /// et `false` déconnectait. Aucun test ne pouvait le voir.

    test('un refus explicite du serveur ferme la session', () {
      expect(ApiClient.verdictDuServeur(401), Renouvellement.refuse);
      // Le compte lui-même est fermé : archivé, suspendu, supprimé.
      expect(ApiClient.verdictDuServeur(403), Renouvellement.refuse);
    });

    /// Le limiteur du serveur autorise cinq requêtes par minute et par adresse,
    /// et les opérateurs mobiles ivoiriens partagent une adresse entre des
    /// milliers d'abonnés. Un 429 ne doit jamais valoir déconnexion.
    test('rien de passager ne déconnecte', () {
      for (final code in [429, 500, 502, 503, 504, 408, 400, 0]) {
        expect(
          ApiClient.verdictDuServeur(code),
          Renouvellement.indisponible,
          reason: 'un $code aurait déconnecté le lecteur',
        );
      }
    });

    test('un 200 prolonge la session', () {
      expect(ApiClient.verdictDuServeur(200), Renouvellement.reussi);
    });

    /// La règle vue depuis la conséquence : qui se retrouve à l'écran de
    /// connexion, et qui reçoit seulement un échec passager.
    test('seul un refus ramène à la connexion', () {
      bool deconnecte(int code) =>
          ApiClient.sessionTerminee(ApiClient.verdictDuServeur(code));

      expect(deconnecte(401), isTrue);
      expect(deconnecte(403), isTrue);
      for (final code in [429, 500, 502, 503, 408, 400]) {
        expect(deconnecte(code), isFalse, reason: 'un $code déconnectait');
      }
    });
  });

  group('Ce qui ne ferme PAS la session', () {
    /// Le défaut qui renvoyait à l'écran de connexion juste après s'y être
    /// connecté.
    ///
    /// Une route qui répondait 401 même après un renouvellement RÉUSSI
    /// provoquait la déconnexion : on en concluait que « l'accès est
    /// réellement refusé ». Mais le serveur d'authentification venait de
    /// délivrer un jeton — la session était vivante, prouvée telle à la
    /// seconde près.
    ///
    /// Le lecteur ressortait donc quelques secondes après être entré, se
    /// reconnectait, et ressortait par la même porte.
    test('un renouvellement réussi ne ferme jamais la session', () {
      expect(ApiClient.sessionTerminee(Renouvellement.reussi), isFalse);
    });

    test('ni une panne, ni un réseau coupé', () {
      expect(ApiClient.sessionTerminee(Renouvellement.indisponible), isFalse);
    });

    /// Et le seul cas qui la ferme, pour que la règle se lise en entier.
    test('seul le refus du serveur de session la ferme', () {
      expect(ApiClient.sessionTerminee(Renouvellement.refuse), isTrue);
    });
  });

  group('Rejouer une requête', () {
    /// `StreamedRequest` — le dépôt d'un manuscrit — envoie son corps au fil de
    /// l'eau. Une fois parti, il n'est plus là : le rejouer enverrait un
    /// fichier vide, et l'auteur croirait avoir publié un livre vierge.
    bool peutEtreRejouee(http.BaseRequest requete) => requete is http.Request;

    test('une requête ordinaire se rejoue', () {
      final requete = http.Request('GET', Uri.parse('https://x.ci/api/books'));
      expect(peutEtreRejouee(requete), isTrue);
    });

    test('un envoi en flux ne se rejoue pas', () {
      final flux = http.StreamedRequest(
        'POST',
        Uri.parse('https://x.ci/upload'),
      );
      expect(peutEtreRejouee(flux), isFalse);
      flux.sink.close();
    });

    test('la copie conserve le corps et la méthode', () {
      final origine = http.Request('POST', Uri.parse('https://x.ci/api/books'))
        ..headers['Content-Type'] = 'application/json'
        ..body = jsonEncode({'titre': 'Les Soleils des indépendances'});

      final copie = http.Request(origine.method, origine.url)
        ..headers.addAll(origine.headers)
        ..bodyBytes = origine.bodyBytes;

      expect(copie.method, 'POST');
      expect(copie.bodyBytes, origine.bodyBytes);
      expect(jsonDecode(copie.body)['titre'], 'Les Soleils des indépendances');
    });
  });

  group('Les routes exemptées', () {
    /// Un 401 sur `/auth/login` veut dire « mauvais mot de passe », pas
    /// « session finie ». Déconnecter quelqu'un qui essaie justement de se
    /// connecter n'aurait aucun sens.
    bool estRouteAuth(String url) => Uri.parse(url).path.contains('/auth/');

    test('les routes de connexion sont hors du mécanisme', () {
      for (final chemin in [
        'http://x.ci:8083/auth/login',
        'http://x.ci:8083/auth/register',
        'http://x.ci:8083/auth/refresh',
        'http://x.ci:8083/auth/verify-otp',
      ]) {
        expect(estRouteAuth(chemin), isTrue, reason: chemin);
      }
    });

    test('les routes métier, elles, y sont soumises', () {
      for (final chemin in [
        'http://x.ci:8083/utilisateurs/me',
        'http://x.ci:8084/api/books',
        'http://x.ci:8084/api/gamification/badges',
      ]) {
        expect(estRouteAuth(chemin), isFalse, reason: chemin);
      }
    });
  });
}
