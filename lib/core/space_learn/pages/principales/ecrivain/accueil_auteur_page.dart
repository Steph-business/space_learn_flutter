import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:flutter/material.dart';

import 'package:space_learn_flutter/core/themes/layout/nav_bar_auteur.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/ecrivain/contenu_accueil_auteur.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/ecrivain/ajouter_livre_page.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/ecrivain/livres_page.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/ecrivain/communaute_page.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/ecrivain/settings_page_auteur.dart';

class HomePageAuteur extends StatefulWidget {
  final String profileId;
  final String userName;
  static final GlobalKey<_HomePageAuteurState> navKey =
      GlobalKey<_HomePageAuteurState>();

  const HomePageAuteur({
    super.key,
    required this.profileId,
    this.userName = 'Auteur',
  });

  @override
  State<HomePageAuteur> createState() => _HomePageAuteurState();
}

class _HomePageAuteurState extends State<HomePageAuteur> {
  int _currentIndex = 0;
  Key _homeKey = UniqueKey();
  Key _livresKey = UniqueKey();

  void setIndex(int index) {
    if (mounted) {
      setState(() => _currentIndex = index);
    }
  }

  void goHome() {
    setIndex(0);
  }

  void refreshPages() {
    if (mounted) {
      setState(() {
        _homeKey = UniqueKey();
        _livresKey = UniqueKey();
      });
    }
  }

  @override
  void initState() {
    super.initState();
  }

  Widget _getPage(int index) {
    switch (index) {
      case 0:
        return HomeContentAuteur(
          key: _homeKey,
          profileId: widget.profileId,
          userName: widget.userName,
        );
      case 1:
        return LivresPage(
          key: _livresKey,
          onBackPressed: () => setState(() => _currentIndex = 0),
        );
      case 2:
        return AjouterLivrePage();
      case 3:
        return TeamsPage(
          onBackPressed: () => setState(() => _currentIndex = 0),
        );
      case 4:
        return SettingsPageAuteur();
      default:
        return HomeContentAuteur(
          key: _homeKey,
          profileId: '',
          userName: 'Auteur',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    AppColors.suivreLeTheme(context);
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _getPage(0),
          _getPage(1),
          _getPage(2),
          _getPage(3),
          _getPage(4),
        ],
      ),
      bottomNavigationBar: NavBarAuteur(
        currentIndex: _currentIndex,
        onTap: (index) async {
          if (index == 2) {
            // "Publier" action: Open AjouterLivrePage directly
            final result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AjouterLivrePage()),
            );
            if (result == true) {
              refreshPages();
            }
          } else {
            // Normal navigation
            setState(() {
              _currentIndex = index;
            });
          }
        },
      ),
    );
  }
}
