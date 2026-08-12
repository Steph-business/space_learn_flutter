// Une page déjà à l'écran doit suivre un changement de thème.
//
// AppColors.isDark est une variable globale. La lire ne crée aucune
// dépendance : Flutter ne reconstruit un widget que s'il dépend d'un
// InheritedWidget modifié. Une page empilée gardait donc les couleurs qu'elle
// avait au moment de sa construction — d'où un en-tête clair au-dessus d'une
// page sombre, chacun figé sur le thème actif quand il a été bâti.
//
// AppColors.suivreLeTheme établit cette dépendance. Ce test vérifie qu'elle
// tient, et qu'elle ne coûte pas la pile de navigation.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/themes/app_theme.dart';

/// Une page bâtie comme celles de l'application : elle lit la palette globale.
class _PageDeLApplication extends StatelessWidget {
  final String nom;
  const _PageDeLApplication(this.nom);

  @override
  Widget build(BuildContext context) {
    AppColors.suivreLeTheme(context);
    return Container(
      key: ValueKey('fond-$nom'),
      color: AppColors.scaffoldBackground,
      child: Text(nom, textDirection: TextDirection.ltr),
    );
  }
}

/// La même, mais qui a oublié de s'abonner — le défaut d'origine.
class _PageSansAbonnement extends StatelessWidget {
  const _PageSansAbonnement();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('fond-sans-abonnement'),
      color: AppColors.scaffoldBackground,
      child: const Text('sans', textDirection: TextDirection.ltr),
    );
  }
}

class _Application extends StatefulWidget {
  const _Application();

  @override
  State<_Application> createState() => _ApplicationState();
}

class _ApplicationState extends State<_Application> {
  bool sombre = false;
  static late void Function() basculer;

  @override
  Widget build(BuildContext context) {
    basculer = () => setState(() => sombre = !sombre);
    // Même point de synchronisation que dans main.dart.
    AppColors.isDark = sombre;
    return MaterialApp(
      theme: AppTheme.clair,
      darkTheme: AppTheme.sombre,
      themeMode: sombre ? ThemeMode.dark : ThemeMode.light,
      home: const _PageDeLApplication('accueil'),
    );
  }
}

Color _fond(WidgetTester tester, String cle) =>
    tester.widget<Container>(find.byKey(ValueKey('fond-$cle'))).color!;

void main() {
  testWidgets('une page empilée suit le changement de thème', (tester) async {
    final etatInitial = AppColors.isDark;
    addTearDown(() => AppColors.isDark = etatInitial);

    await tester.pumpWidget(const _Application());

    // Une page est empilée, comme après une connexion.
    Navigator.of(tester.element(find.text('accueil'))).push(
      MaterialPageRoute(builder: (_) => const _PageDeLApplication('empilee')),
    );
    await tester.pumpAndSettle();

    expect(_fond(tester, 'empilee'), AppColors.scaffoldLight);

    _ApplicationState.basculer();
    await tester.pumpAndSettle();

    expect(_fond(tester, 'empilee'), AppColors.scaffoldDark,
        reason: 'la page empilée est restée sur son ancienne palette');

    // Le correctif ne doit pas se payer en navigation perdue.
    expect(find.text('empilee'), findsOneWidget,
        reason: 'la pile de navigation a été détruite');

    // La page racine suit aussi.
    _ApplicationState.basculer();
    await tester.pumpAndSettle();
    expect(_fond(tester, 'empilee'), AppColors.scaffoldLight);
  });

  testWidgets('sans abonnement, la page reste sur son ancienne palette', (
    tester,
  ) async {
    final etatInitial = AppColors.isDark;
    addTearDown(() => AppColors.isDark = etatInitial);

    await tester.pumpWidget(const _Application());
    Navigator.of(tester.element(find.text('accueil'))).push(
      MaterialPageRoute(builder: (_) => const _PageSansAbonnement()),
    );
    await tester.pumpAndSettle();

    _ApplicationState.basculer();
    await tester.pumpAndSettle();

    // C'est le défaut d'origine, conservé ici pour que le test précédent
    // prouve quelque chose : sans l'abonnement, rien ne change.
    expect(_fond(tester, 'sans-abonnement'), AppColors.scaffoldLight);
  });
}
