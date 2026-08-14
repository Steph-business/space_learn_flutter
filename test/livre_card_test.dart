import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/book_model.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/lecteur/boutique/livre_card.dart';

/// Une carte trop courte rogne la couverture ou fait déborder le texte, et
/// rien ne le signale à la compilation : un débordement ne se voit qu'à
/// l'écran, en rayures jaunes, sur l'appareil de quelqu'un.
///
/// C'est arrivé : les carrousels de l'accueil posaient la carte dans une bande
/// de 250 px alors qu'il lui en faut 344 à cette largeur. Ces tests fixent le
/// contrat entre la carte et ceux qui la posent.
void main() {
  BookModel livre({
    String titre = 'Un titre',
    int prix = 5000,
    String? couverture,
  }) {
    return BookModel(
      id: 'l1',
      auteurId: 'a1',
      titre: titre,
      description: 'Une description.',
      format: 'PDF',
      prix: prix,
      stock: 0,
      statut: 'publie',
      imageCouverture: couverture,
    );
  }

  Future<void> poser(
    WidgetTester tester,
    BookModel book, {
    required double largeur,
    double? hauteur,
    bool isOwned = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: largeur,
              height: hauteur ?? LivreCard.hauteurPour(largeur),
              child: LivreCard(book: book, isOwned: isOwned),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('la hauteur annoncée suffit, à toutes les largeurs', (
    tester,
  ) async {
    // Un débordement fait échouer le test de lui-même : pumpWidget lève.
    for (final largeur in [120.0, 140.0, 160.0, 180.0, 200.0]) {
      await poser(tester, livre(), largeur: largeur);
      expect(tester.takeException(), isNull, reason: 'largeur $largeur');
    }
  });

  testWidgets('un titre très long ne fait pas déborder la carte', (
    tester,
  ) async {
    await poser(
      tester,
      livre(titre: 'Un titre exagérément long ' * 6),
      largeur: 160,
    );
    expect(tester.takeException(), isNull);
  });

  test('la hauteur suit la largeur', () {
    // La couverture garde les proportions d'un livre : élargir la carte doit
    // la rendre plus haute, sinon l'image serait rognée.
    expect(LivreCard.hauteurPour(200), greaterThan(LivreCard.hauteurPour(160)));
    // Deux tiers de large pour trois de haut.
    expect(
      LivreCard.hauteurPour(160),
      closeTo(160 / LivreCard.rapportCouverture, 0.01),
    );
  });

  testWidgets('un livre gratuit porte son étiquette et son prix', (
    tester,
  ) async {
    await poser(tester, livre(prix: 0), largeur: 160);
    expect(find.text('GRATUIT'), findsOneWidget);
    expect(find.text('Gratuit'), findsOneWidget);
    // Surtout pas « 0 FCFA », qui se lit comme un prix oublié.
    expect(find.textContaining('FCFA'), findsNothing);
  });

  testWidgets('un livre payant affiche son prix, sans étiquette', (
    tester,
  ) async {
    await poser(tester, livre(prix: 5000), largeur: 160);
    expect(find.text('GRATUIT'), findsNothing);
    expect(find.text('5000 FCFA'), findsOneWidget);
  });
}
