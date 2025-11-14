import 'package:flutter/material.dart';

import 'package:space_learn_flutter/core/space_learn/pages/widgets/auteur/teams/communaute.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/auteur/teams/message.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/auteur/teams/reseau.dart';

class TeamsPage extends StatelessWidget {
  final VoidCallback? onBackPressed;

  TeamsPage({super.key, this.onBackPressed});

  final List<Tab> _tabs = const [
    Tab(text: "Commentaires"),
    Tab(text: "Messages"),
    Tab(text: "Réseau"),
  ];

  final List<Widget> _pages = const [Communaute(), Messages(), Reseau()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.deepPurpleAccent,
        title: const Text(
          "COMMUNAUTÉ",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: onBackPressed ?? () => Navigator.of(context).pop(),
        ),
      ),
      body: DefaultTabController(
        length: _tabs.length,
        child: Column(
          children: [
            Container(
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
            Expanded(child: TabBarView(children: _pages)),
          ],
        ),
      ),
    );
  }
}
