import 'package:flutter/material.dart';

class ChapitreEnCours extends StatelessWidget {
  const ChapitreEnCours({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              "Chapitre en cours",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              "Vous n'avez aucun chapitre en cours d'écriture. Commencez par en créer un nouveau !",
            ),
          ],
        ),
      ),
    );
  }
}
