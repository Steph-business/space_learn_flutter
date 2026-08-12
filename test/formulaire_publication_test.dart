// Le bouton « Continuer » du formulaire de publication.
//
// Il ne réagissait pas : les deux étapes restant montées, valider le
// formulaire passait aussi par l'argumentaire — annoncé facultatif, mais
// porteur du validateur « Ce champ est requis » commun à tous les champs. La
// validation échouait, et son message s'affichait sur l'étape masquée. Rien
// ne bougeait, rien ne l'expliquait.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:space_learn_flutter/core/space_learn/pages/principales/ecrivain/ajouter_livre_page.dart';
import 'package:space_learn_flutter/core/themes/app_theme.dart';

Future<void> _ouvrir(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(theme: AppTheme.clair, home: const AjouterLivrePage()),
  );
  // La page charge ses catégories : on laisse la première frame passer sans
  // attendre le réseau, qui n'existe pas ici.
  await tester.pump();
}

/// Remplit un champ désigné par son libellé.
Future<void> _saisir(WidgetTester tester, String libelle, String valeur) async {
  final champ = find.ancestor(
    of: find.text(libelle),
    matching: find.byType(TextFormField),
  );
  expect(champ, findsOneWidget, reason: 'champ « $libelle » introuvable');
  await tester.enterText(champ, valeur);
  await tester.pump();
}

void main() {
  testWidgets('l\'argumentaire vide ne bloque pas le passage à l\'étape 2', (
    tester,
  ) async {
    await _ouvrir(tester);

    // On est bien à l'étape 1.
    expect(find.text('Votre œuvre'), findsOneWidget);
    expect(find.text('Votre argumentaire'), findsNothing);

    await _saisir(tester, 'Titre du livre', 'Les secrets de la Web 3');
    await _saisir(tester, 'Description/Synopsis', 'Un guide pratique.');
    await _saisir(tester, 'Prix (FCFA)', '5220');

    // L'argumentaire reste vide : c'est le cas qui bloquait.
    final formulaire = tester.state<FormState>(find.byType(Form));
    expect(
      formulaire.validate(),
      isTrue,
      reason: "un argumentaire vide ne doit pas invalider le formulaire : "
          "le champ est annoncé facultatif",
    );
  });

  testWidgets('un titre vide invalide bien le formulaire', (tester) async {
    await _ouvrir(tester);

    await _saisir(tester, 'Description/Synopsis', 'Un guide pratique.');
    await _saisir(tester, 'Prix (FCFA)', '5220');
    // Titre laissé vide.

    final formulaire = tester.state<FormState>(find.byType(Form));
    expect(
      formulaire.validate(),
      isFalse,
      reason: 'le test précédent ne prouverait rien si tout passait',
    );
  });
}
