import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:space_learn_flutter/core/utils/app_notifications.dart';

/// Les deux options de `showPremiumDialog` réservées aux gestes terminaux.
///
/// Elles ont été écrites pour la suppression de compte et la bascule de
/// profil — c'est-à-dire pour des gestes irréversibles — mais aucun appelant
/// ne les passait encore : leur premier usage réel aurait aussi été leur
/// premier essai, sur le seul chemin où l'on n'a pas droit à l'erreur. Ce test
/// les exerce d'ici là, et tiendra la promesse le jour où un écran migrera.
void main() {
  /// Ouvre le dialogue depuis une page ordinaire et rend la main une fois
  /// l'animation finie.
  Future<void> ouvrir(
    WidgetTester tester, {
    required bool fermerAvantConfirmation,
    required bool barrierDismissible,
    required void Function(BuildContext pageContext) onConfirm,
  }) async {
    late BuildContext pageContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            pageContext = context;
            return const Scaffold(body: SizedBox.expand());
          },
        ),
      ),
    );

    AppNotifications.showPremiumDialog(
      pageContext,
      title: 'Supprimer le compte',
      message: 'Cette action est définitive.',
      confirmText: 'Supprimer',
      cancelText: 'Annuler',
      isError: true,
      fermerAvantConfirmation: fermerAvantConfirmation,
      barrierDismissible: barrierDismissible,
      onConfirm: () => onConfirm(pageContext),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('par défaut, rien ne change : le dialogue ferme puis exécute', (
    tester,
  ) async {
    var appels = 0;

    await ouvrir(
      tester,
      fermerAvantConfirmation: true,
      barrierDismissible: true,
      onConfirm: (_) => appels++,
    );

    expect(find.text('Supprimer le compte'), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Supprimer'));
    await tester.pumpAndSettle();

    expect(appels, 1);
    // Le dialogue est parti de lui-même : les douze appelants qui ne passent
    // rien continuent de fonctionner exactement comme avant.
    expect(find.text('Supprimer le compte'), findsNothing);
  });

  testWidgets('un appui à côté ferme le dialogue ordinaire', (tester) async {
    await ouvrir(
      tester,
      fermerAvantConfirmation: true,
      barrierDismissible: true,
      onConfirm: (_) {},
    );

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.text('Supprimer le compte'), findsNothing);
  });

  group('geste terminal', () {
    testWidgets('le dialogue tient l’écran pendant la requête', (tester) async {
      var appels = 0;

      await ouvrir(
        tester,
        fermerAvantConfirmation: false,
        barrierDismissible: false,
        onConfirm: (_) => appels++,
      );

      await tester.tap(find.widgetWithText(ElevatedButton, 'Supprimer'));
      await tester.pumpAndSettle();

      expect(appels, 1);
      // C'est tout l'objet de l'option : l'écran d'origine ne reste pas
      // affiché et inerte, sans rien à quoi s'accrocher, pendant l'appel —
      // le dialogue tient l'écran jusqu'à ce que l'appelant le referme.
      expect(find.text('Supprimer le compte'), findsOneWidget);
    });

    testWidgets('un appui à côté n’annule plus en silence', (tester) async {
      var appels = 0;

      await ouvrir(
        tester,
        fermerAvantConfirmation: false,
        barrierDismissible: false,
        onConfirm: (_) => appels++,
      );

      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      // Ni fermé, ni décidé : la personne n'a rien annulé sans le savoir.
      expect(find.text('Supprimer le compte'), findsOneWidget);
      expect(appels, 0);
    });

    testWidgets('deux appuis rapprochés n’envoient pas deux fois le geste', (
      tester,
    ) async {
      var appels = 0;

      await ouvrir(
        tester,
        fermerAvantConfirmation: false,
        barrierDismissible: false,
        onConfirm: (_) => appels++,
      );

      final bouton = find.widgetWithText(ElevatedButton, 'Supprimer');
      await tester.tap(bouton);
      await tester.pump();
      await tester.tap(bouton);
      await tester.pumpAndSettle();

      // Le verrou vit hors du builder : sans lui, le dialogue restant ouvert,
      // le même geste irréversible partait deux fois.
      expect(appels, 1);
    });

    testWidgets('c’est l’appelant qui referme, et il le peut', (tester) async {
      await ouvrir(
        tester,
        fermerAvantConfirmation: false,
        barrierDismissible: false,
        // Ce que doit faire l'écran migré, dans TOUS les cas — succès comme
        // échec — sans quoi le dialogue resterait pour toujours.
        onConfirm: (pageContext) => Navigator.of(pageContext).pop(),
      );

      await tester.tap(find.widgetWithText(ElevatedButton, 'Supprimer'));
      await tester.pumpAndSettle();

      expect(find.text('Supprimer le compte'), findsNothing);
    });
  });
}
