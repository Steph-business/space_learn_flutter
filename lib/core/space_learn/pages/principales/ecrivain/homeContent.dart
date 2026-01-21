import 'package:flutter/material.dart';

import 'package:space_learn_flutter/core/space_learn/pages/widgets/auteur/home/action_rapide.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/auteur/home/livre_recent.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/auteur/home/notification_recent.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/auteur/home/revenus.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/auteur/home/statistique.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/lecteur/markeplace/section_titre.dart';

class HomeContent extends StatelessWidget {
  final String profileId;
  final String userName;

  const HomeContent({
    super.key,
    required this.profileId,
    required this.userName,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Statistique(),
          const SizedBox(height: 20),
          const SectionTitle(title: "Action rapides"),
          const AuteurActionsRapide(),
          const SizedBox(height: 50),
          const SectionTitle(title: "Revenus mensuels"),
          const SizedBox(height: 20),
          const Revenus(),
          const SizedBox(height: 50),
          const SectionTitle(title: "Mes livres récents"),
          const SizedBox(height: 20),
          const AuteurLivresRecents(),
          const SizedBox(height: 50),
          const SectionTitle(title: "Notifications récentes"),
          const SizedBox(height: 20),
          const RecentNotificationsPage(),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}
