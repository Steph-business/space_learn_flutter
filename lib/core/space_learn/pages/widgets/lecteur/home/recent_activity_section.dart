import 'package:flutter/material.dart';

import '../../../../../themes/layout/navBarLecteur.dart';

class RecentActivitySection extends StatelessWidget {
  const RecentActivitySection({super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () {
        // Navigation vers la page Bibliothèque via la barre de navigation
        final navBarState = MainNavBar.of(context);
        if (navBarState != null) {
          navBarState.navigateToBibliotheque();
        }
      },
      leading: const CircleAvatar(
        backgroundColor: Colors.amber,
        child: Icon(Icons.comment, color: Colors.white),
      ),
      title: const Text("Vous avez commenté 'Sapiens'"),
      subtitle: const Text("Il y a 2 heures"),
      trailing: IconButton(
        icon: const Icon(Icons.more_vert),
        onPressed: () {
          // Action pour plus d'options
        },
      ),
    );
  }
}
