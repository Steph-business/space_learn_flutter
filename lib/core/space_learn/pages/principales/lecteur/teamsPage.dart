import 'package:flutter/material.dart';

import 'package:space_learn_flutter/core/space_learn/pages/widgets/auteur/teams/communaute.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/auteur/teams/message.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/auteur/teams/reseau.dart';

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
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.deepPurpleAccent,
          elevation: 0,
          title: const Text(
            "COMMUNAUTÉ",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          actions: const [
            Padding(
              padding: EdgeInsets.only(right: 16),
              child: Icon(Icons.mail_outline, color: Colors.white),
            ),
          ],
          leading: const Padding(
            padding: EdgeInsets.only(left: 12),
            child: Icon(Icons.menu, color: Colors.white),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: Container(
              alignment: Alignment.center,
              color: Colors.white,
              child: TabBar(
                labelColor: Colors.deepPurple,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Colors.deepPurple,
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
    );
  }
}
