import 'package:flutter/material.dart';

import 'package:space_learn_flutter/core/themes/layout/navBarAll.dart';
import 'package:space_learn_flutter/core/themes/layout/navBarAuteur.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/ecrivain/ecrirePage.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/ecrivain/homeContentAuteur.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/ecrivain/livrePage.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/ecrivain/statsPage.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/ecrivain/teamsPage.dart';

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

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const HomeContentAuteur(
        profileId: '',
        userName: 'Auteur',
      ), // Placeholder, will be updated
      const EcriturePage(),
      const LivresPage(),
      const StatsPage(),
      TeamsPage(
        onBackPressed: () {
          setState(() {
            _currentIndex = 0; // Go back to home page
          });
        },
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    // Pages that don't need NavBarAll (they have their own AppBars)
    final pagesWithoutNavBarAll = [
      EcriturePage,
      LivresPage,
      StatsPage,
      TeamsPage,
    ];

    // Check if current page needs NavBarAll
    final currentPage = _pages[_currentIndex];
    final showNavBarAll = !pagesWithoutNavBarAll.contains(
      currentPage.runtimeType,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: showNavBarAll
          ? PreferredSize(
              preferredSize: const Size.fromHeight(
                100,
              ), // Adjust height as needed
              child: NavBarAll(userName: widget.userName),
            )
          : null,
      body: IndexedStack(
        index: _currentIndex,
        children: _pages.map((page) {
          if (page is HomeContentAuteur) {
            return HomeContentAuteur(
              profileId: widget.profileId,
              userName: widget.userName,
            );
          }
          return page;
        }).toList(),
      ),
      bottomNavigationBar: NavBarAuteur(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}
