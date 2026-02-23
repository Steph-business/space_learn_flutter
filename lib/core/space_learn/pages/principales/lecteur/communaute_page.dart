import 'package:flutter/material.dart';

import 'package:space_learn_flutter/core/space_learn/pages/widgets/auteur/communaute/communaute.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/auteur/communaute/message.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/auteur/communaute/reseau.dart';

class TeamsPageLecteur extends StatelessWidget {
  const TeamsPageLecteur({super.key});

  final List<Tab> _tabs = const [
    Tab(text: "Commentaires"),
    Tab(text: "Messages"),
    Tab(text: "Réseau"),
  ];

  final List<Widget> _pages = const [Communaute(), Messages(), Reseau()];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _tabs.length,
      child: Stack(
        children: [
          Container(color: const Color(0xFF0F172A)),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.45,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF475569), // Lighter slate gray
                    Color(0xFF0F172A), // Dark background matching Scaffold
                  ],
                ),
              ),
            ),
          ),
          Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: const Text(
                "COMMUNAUTÉ",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              centerTitle: true,
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(60),
                child: Container(
                  alignment: Alignment.center,
                  color: Colors.transparent, // Let gradient show through
                  child: TabBar(
                    labelColor: const Color(0xFF06B6D4), // Cyan
                    unselectedLabelColor: Colors.grey[400],
                    indicatorColor: const Color(0xFF06B6D4),
                    indicatorWeight: 3,
                    tabs: _tabs,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
            body: TabBarView(children: _pages),
          ),
        ],
      ),
    );
  }
}
