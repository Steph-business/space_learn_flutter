// Ce que /auth/verification répond, et ce que le mobile en dit.
//
// TROIS DÉPÔTS SE SONT CONTREDITS ICI, ET C'EST LE MOBILE QUI PORTAIT LA PIRE
// PHRASE. Le serveur rendait 500 APRÈS avoir consommé le code et posé
// `email_verified` : le compte était validé, le code mort, et l'application
// affichait « votre code n'a pas été utilisé et reste valable » sous un bouton
// « Réessayer ». Trois affirmations fausses d'un coup, à quelqu'un qui n'avait
// plus qu'à se connecter.
//
// Le serveur a fermé la cause — la session s'ouvre AVANT toute écriture
// irréversible, et ce qui reste est un vrai 503 — puis ouvert la porte à ceux
// que la version déployée avait enfermés : 400 avec `deja_verifie`. Ces tests
// tiennent les deux moitiés côté mobile, et surtout la troisième : un 5xx qui
// n'est PAS 503 ne doit plus rien affirmer sur le sort du code.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:space_learn_flutter/core/space_learn/data/dataServices/authServices.dart';
import 'package:space_learn_flutter/core/utils/message_erreur.dart';

void main() {
  /// Une réponse en UTF-8, en-tête compris.
  ///
  /// `http.Response` encode ET redécode en latin1 par défaut : le tiret cadratin
  /// des phrases du serveur y fait lever « Contains invalid characters », et un
  /// « é » y reviendrait abîmé. Le serveur, lui, répond en UTF-8 ; le test doit
  /// donc lui ressembler, sans quoi il mesurerait autre chose que la réalité.
  http.Response reponseJson(String corps, int code) => http.Response.bytes(
    utf8.encode(corps),
    code,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  AuthService serviceQuiRepond(http.Response reponse) =>
      AuthService(client: MockClient((_) async => reponse));

  group('Un compte déjà validé', () {
    const phraseDuServeur =
        "Votre compte est déjà validé : ce code n'a plus d'usage. "
        "Connectez-vous — par mot de passe ou avec Google, selon la façon dont "
        "vous vous êtes inscrit.";

    test('mène à la connexion, et non à un refus de plus', () async {
      final service = serviceQuiRepond(
        reponseJson(
          '{"error":"$phraseDuServeur","deja_verifie":true}',
          400,
        ),
      );

      await expectLater(
        () => service.verifyRegistration('a@b.c', '123456'),
        throwsA(isA<CompteDejaValide>()),
      );
    });

    /// C'est un refus de DROIT : aucun « Réessayer ». Le type le dit une fois
    /// pour toutes, pour que l'écran n'ait pas à le deviner dans la phrase.
    test('est un refus de droit, pas une panne', () async {
      final service = serviceQuiRepond(
        reponseJson(
          '{"error":"$phraseDuServeur","deja_verifie":true}',
          400,
        ),
      );

      await expectLater(
        () => service.verifyRegistration('a@b.c', '123456'),
        throwsA(
          allOf(isA<AccesRefuse>(), isNot(isA<PanneServeur>())),
        ),
      );
    });

    test('affiche la phrase du serveur telle quelle', () async {
      final service = serviceQuiRepond(
        reponseJson(
          '{"error":"$phraseDuServeur","deja_verifie":true}',
          400,
        ),
      );

      try {
        await service.verifyRegistration('a@b.c', '123456');
        fail('un refus était attendu');
      } catch (e) {
        expect(messageLisible(e), phraseDuServeur);
      }
    });

    /// Un 400 ordinaire — code faux — reste un refus ordinaire : il n'emmène
    /// personne vers la connexion.
    test('ne se confond pas avec un code refusé', () async {
      final service = serviceQuiRepond(
        reponseJson('{"error":"Code OTP invalide"}', 400),
      );

      await expectLater(
        () => service.verifyRegistration('a@b.c', '123456'),
        throwsA(isNot(isA<CompteDejaValide>())),
      );
    });
  });

  group('Une panne de vérification', () {
    const phraseDePanne =
        "La vérification du code est momentanément impossible. "
        "Réessayez dans un instant.";

    /// LE 503 EST LE SEUL À DIRE « votre code est intact ». Le serveur n'a rien
    /// écrit, aucun essai n'a été compté, et réessayer peut aboutir.
    test('le 503 vaut PanneServeur', () async {
      final service = serviceQuiRepond(
        reponseJson('{"error":"$phraseDePanne"}', 503),
      );

      await expectLater(
        () => service.verifyRegistration('a@b.c', '123456'),
        throwsA(isA<PanneServeur>()),
      );
    });

    /// LA RÉGRESSION QUE CE TEST EXISTE POUR TENIR. La ligne testait `>= 500` :
    /// le 500 tardif de la version déployée — rendu APRÈS la consommation du
    /// code et la validation du compte — devenait donc une « panne », et
    /// l'écran affirmait un code intact qui ne l'était pas.
    test('un 5xx qui n\'est pas 503 n\'affirme rien sur le code', () async {
      final service = serviceQuiRepond(
        reponseJson('{"error":"Erreur lors de la génération du token"}', 500),
      );

      await expectLater(
        () => service.verifyRegistration('a@b.c', '123456'),
        throwsA(isNot(isA<PanneServeur>())),
      );
    });

    test('le 503 de /auth/verify-otp aussi', () async {
      final service = serviceQuiRepond(
        reponseJson('{"error":"$phraseDePanne"}', 503),
      );

      await expectLater(
        () => service.verifyOtp('a@b.c', '123456'),
        throwsA(isA<PanneServeur>()),
      );
    });
  });

  group('Les deux envois de code', () {
    /// LA PHRASE NEUTRE EST CELLE DU SERVEUR, ET ELLE A CHANGÉ. Elle se termine
    /// désormais par « redemandez-en un dans une minute », parce qu'il existe
    /// un cas où la personne n'a rien d'utilisable en main. Une copie figée
    /// dans un écran la laisserait attendre sans savoir quoi faire.
    test('sendOtp rend le message du serveur', () async {
      const neutre =
          "Si un compte est associé à cet e-mail, un code de vérification a "
          "été envoyé. Si vous ne le recevez pas, redemandez-en un dans une "
          "minute.";
      final service = serviceQuiRepond(
        reponseJson('{"message":"$neutre"}', 200),
      );

      expect(await service.sendOtp('a@b.c'), neutre);
    });

    test('forgotPassword rend le message du serveur', () async {
      const neutre =
          "Si un compte est associé à cet e-mail, un code de réinitialisation "
          "a été envoyé. Si vous ne le recevez pas, redemandez-en un dans une "
          "minute.";
      final service = serviceQuiRepond(
        reponseJson('{"message":"$neutre"}', 200),
      );

      expect(await service.forgotPassword('a@b.c'), neutre);
    });

    /// Sur une panne, ces deux routes rendaient 200 « un code a été envoyé »
    /// sans que rien ne parte. Elles rendent 503 : l'envoi ne s'annonce plus.
    test('un 503 d\'émission lève au lieu d\'annoncer un envoi', () async {
      final service = serviceQuiRepond(
        reponseJson(
          '{"error":"L\'envoi du code est momentanément impossible. '
          'Réessayez dans un instant."}',
          503,
        ),
      );

      await expectLater(
        () => service.forgotPassword('a@b.c'),
        throwsA(isA<Exception>()),
      );
    });
  });
}
