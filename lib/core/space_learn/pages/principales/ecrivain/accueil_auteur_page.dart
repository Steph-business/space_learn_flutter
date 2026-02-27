import 'package:flutter/material.dart';

import 'package:space_learn_flutter/core/themes/layout/nav_bar_all.dart';
import 'package:space_learn_flutter/core/themes/layout/nav_bar_auteur.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/ecrivain/contenu_accueil_auteur.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/ecrivain/ajouter_livre_page.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/ecrivain/livres_page.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/ecrivain/communaute_page.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/ecrivain/settings_page_auteur.dart';

class HomePageAuteur extends StatefulWidget {
  final String profileId;
  final String userName;

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

  @override
  void initState() {
    super.initState();
  }

  Widget _getPage(int index) {
    switch (index) {
      case 0:
        return HomeContentAuteur(
          profileId: widget.profileId,
          userName: widget.userName,
        );
      case 1:
        return const AjouterLivrePage();
      case 2:
        return LivresPage(
          onBackPressed: () => setState(() => _currentIndex = 0),
        );
      case 3:
        return TeamsPage(
          onBackPressed: () => setState(() => _currentIndex = 0),
        );
      case 4:
        return const SettingsPageAuteur();
      default:
        return const HomeContentAuteur(profileId: '', userName: 'Auteur');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Pages that don't need NavBarAll (they have their own AppBars)
    final pagesWithoutNavBarAll = [AjouterLivrePage, LivresPage, TeamsPage];

    // Check if current page needs NavBarAll
    final currentPageType = _getPage(_currentIndex).runtimeType;
    final showNavBarAll = !pagesWithoutNavBarAll.contains(currentPageType);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: showNavBarAll
          ? PreferredSize(
              preferredSize: const Size.fromHeight(
                100,
              ), // Adjust height as needed
              child: NavBarAll(
                userName: widget.userName,
                showCart: false,
                role: 'auteur',
              ),
            )
          : null,
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
        onTap: (index) {
          if (index == 1) {
            // "Publier" action: Open AjouterLivrePage directly
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AjouterLivrePage()),
            );
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
