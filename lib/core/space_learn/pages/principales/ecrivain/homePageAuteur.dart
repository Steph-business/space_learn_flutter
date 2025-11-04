import 'package:flutter/material.dart';
import 'package:space_learn_flutter/core/space_learn/pages/layout/navBarAll.dart';
import 'package:space_learn_flutter/core/space_learn/pages/layout/navBarAuteur.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/ecrivain/homeContent.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/ecrivain/ecrirePage.dart';
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

  final List<Widget> _pages = [
    const HomeContent(
      profileId: '',
      userName: 'Auteur',
    ), // Placeholder, will be updated
    const EcriturePage(),
    const LivresPage(),
    const StatsPage(),
    const TeamsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          NavBarAll(userName: widget.userName),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: _pages.map((page) {
                if (page is HomeContent) {
                  return HomeContent(
                    profileId: widget.profileId,
                    userName: widget.userName,
                  );
                }
                return page;
              }).toList(),
            ),
          ),
          NavBarAuteur(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
          ),
        ],
      ),
    );
  }
}
