// Les deux écrans de messagerie répondent-ils la MÊME chose à la même
// question ?
//
// LA QUESTION : « quand l'écran d'erreur occupe toute la page, offre-t-on
// quand même d'écrire juste dessous ? » Les deux écrans y ont répondu en sens
// contraire, dans le même tour, au nom de la même doctrine — l'un retirait le
// compositeur sur une session morte, y compris quand le fil était lisible et
// qu'un brouillon y dormait ; l'autre le rendait sous un bouton
// « Se reconnecter », c'est-à-dire proposait d'écrire dans un fil qu'il venait
// de déclarer inaccessible.
//
// LA RÉPONSE, LA MÊME DES DEUX CÔTÉS : on ne retire le compositeur que
// lorsqu'il n'y a plus rien à quoi l'attacher. Rien à montrer — l'erreur prend
// l'écran, pas de champ dessous. Fil lisible — le champ reste avec ce qu'on y a
// tapé, une saisie ne se perd que lorsqu'elle n'a plus aucune destination.
//
// Ces tests tiennent la première moitié, celle qui se rejoue sans réseau : sans
// jeton, les deux écrans montrent leur erreur en grand ET AUCUN CHAMP DE
// SAISIE.
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:space_learn_flutter/core/space_learn/data/model/conversation_model.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/discussionModel.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/conversation_page.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/lecteur/communaute/forum_messages_page.dart';
import 'package:space_learn_flutter/core/themes/app_theme.dart';

void main() {
  setUp(() {
    // Aucun jeton nulle part : c'est la session morte, telle que les deux
    // écrans la rencontrent réellement — `TokenStorage.getToken()` rend null
    // avant qu'aucune requête ne parte.
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  Future<void> rendre(WidgetTester tester, Widget ecran) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(theme: AppTheme.clair, home: ecran));
    // Deux images : la lecture du coffre, puis le premier rendu du corps.
    await tester.pump();
    await tester.pump();
  }

  testWidgets(
    'Conversation privée sans jeton : une sortie, et aucun champ de saisie',
    (tester) async {
      await rendre(
        tester,
        ConversationPage(
          conversation: Conversation.fromJson(const {
            'id': 'c1',
            'correspondant': {'id': 'u2', 'nom': 'Bob'},
            'non_lus': 0,
          }),
        ),
      );

      // La sortie qui peut aboutir, et elle seule.
      expect(find.text('Se reconnecter'), findsOneWidget);
      expect(find.text('Réessayer'), findsNothing);

      // LE POINT DU TEST : rien à écrire sous un écran qui dit que la session
      // est finie.
      expect(find.byType(TextField), findsNothing);
    },
  );

  testWidgets('Salon de forum sans jeton : même réponse, même écran', (
    tester,
  ) async {
    await rendre(
      tester,
      ForumMessagesPage(
        discussion: Discussion(id: 'd1', titre: 'Les théories du chapitre 3'),
      ),
    );

    expect(find.text('Se reconnecter'), findsOneWidget);
    expect(find.text('Réessayer'), findsNothing);

    // C'est la ligne que ce test existe pour tenir : le compositeur se rendait
    // ici sous l'écran d'erreur, `else if (!_refusDAcces)` ne regardant que le
    // refus de droit.
    expect(find.byType(TextField), findsNothing);
  });

  // ET L'AUTRE MOITIÉ N'EST PAS TENUE ICI, ET LE DIRE VAUT MIEUX QUE DE
  // FAIRE SEMBLANT.
  //
  // « Rien à montrer » recouvrait DEUX situations que rien ne distingue à
  // l'écran et que tout sépare : la session morte — écrire exige un jeton, cela
  // ne peut pas aboutir — et la simple panne de LECTURE, où l'envoi part par
  // une autre requête qui, elle, peut très bien passer. Les deux écrans
  // retiraient le champ dans les deux cas, en contradiction avec la note qui
  // introduit le compositeur de `conversation_page` : « PANNE DE LECTURE — rien
  // ne change : écrire est une autre requête, et elle peut aboutir. » C'est
  // corrigé — `_ecrireNePeutPasAboutir`, des deux côtés.
  //
  // POURQUOI AUCUN TEST NE LE GARDE : la panne de lecture demande qu'une
  // requête PARTE et ÉCHOUE. Sous `flutter_test`, la requête de ces deux écrans
  // ne se résout jamais — trente-six secondes d'horloge simulée plus tard,
  // `_erreur` est toujours nulle et l'écran est encore en attente. Un test écrit
  // là-dessus passe avec la correction ET SANS ELLE : il ne mesure rien. Un
  // test vide qui rassure est pire que pas de test, et cette campagne a passé
  // six tours à le vérifier. Ce qu'il faudrait pour le tenir : une couche HTTP
  // injectable dans ces deux écrans, ou un test d'intégration contre un serveur
  // qui refuse. Tant que ce n'est pas fait, la garde est le commentaire de
  // `_ecrireNePeutPasAboutir`, dans les deux fichiers.
}
