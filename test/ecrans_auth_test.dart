// Mise en page des écrans d'authentification.
//
// Ces écrans combinent Spacer, zones défilantes et boutons pleine largeur —
// un assemblage qui déborde silencieusement sur les petits écrans. Le test les
// rend à trois tailles et échoue au moindre débordement.
//
// Il n'est pas théorique : il a trouvé un rembourrage horizontal ajouté au
// thème des boutons qui retirait 48 px au libellé de chaque bouton pleine
// largeur, faisant déborder « Continuer avec Google » de 64 px.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:space_learn_flutter/core/space_learn/pages/principales/auth/bienvenue.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/auth/login.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/auth/register.dart';
import 'package:space_learn_flutter/core/themes/app_theme.dart';

/// Du petit Android courant au grand format.
const _tailles = <String, Size>{
  'petit (320 × 568)': Size(320, 568),
  'courant (390 × 844)': Size(390, 844),
  'grand (430 × 932)': Size(430, 932),
};

Future<void> _rendre(WidgetTester tester, Widget ecran, Size taille) async {
  tester.view.physicalSize = taille;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(theme: AppTheme.clair, home: ecran));
  await tester.pump();
}

void main() {
  final ecrans = <String, Widget Function()>{
    'bienvenue': () => const BienvenuePage(),
    'connexion': () => const LoginPage(),
    'inscription': () => const RegisterPage(profilChoisi: 'Auteur'),
  };

  for (final ecran in ecrans.entries) {
    for (final taille in _tailles.entries) {
      testWidgets('${ecran.key} tient sur un écran ${taille.key}', (
        tester,
      ) async {
        await _rendre(tester, ecran.value(), taille.value);
        expect(
          tester.takeException(),
          isNull,
          reason: 'débordement de mise en page sur ${taille.key}',
        );
      });
    }
  }

  testWidgets('la bienvenue propose les deux chemins', (tester) async {
    await _rendre(tester, const BienvenuePage(), const Size(390, 844));
    expect(find.text('Se connecter'), findsOneWidget);
    expect(find.textContaining('Inscrivez-vous'), findsOneWidget);

    // Un seul bouton plein. Deux actions de même poids obligeraient à choisir
    // entre deux inconnues : celui qui a un compte cherche son bouton, celui
    // qui n'en a pas cherche sa phrase.
    expect(find.byType(ElevatedButton), findsOneWidget);
    expect(find.byType(OutlinedButton), findsNothing);
    // Le choix du profil n'est plus la porte d'entrée : c'est la première
    // étape de la création de compte, pas un péage avant la connexion.
    expect(find.text('Qui êtes-vous ?'), findsNothing);
  });

  testWidgets("l'inscription annonce le profil retenu", (tester) async {
    await _rendre(
      tester,
      const RegisterPage(profilChoisi: 'Auteur'),
      const Size(390, 844),
    );
    // Le bandeau « Profil sélectionné » a été supprimé : l'information vit
    // désormais dans l'en-tête, visible pendant tout le remplissage.
    expect(find.text("Vous créez un compte d'Auteur"), findsOneWidget);
  });

  testWidgets("sans profil, l'inscription garde son accroche générique", (
    tester,
  ) async {
    await _rendre(tester, const RegisterPage(), const Size(390, 844));
    expect(find.text('Créez votre compte pour commencer'), findsOneWidget);
  });
}
