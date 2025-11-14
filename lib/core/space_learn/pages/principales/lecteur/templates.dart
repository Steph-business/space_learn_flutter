import 'package:flutter/material.dart';

class TemplatesWidget extends StatelessWidget {
  const TemplatesWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: const [
            Text(
              "Modèles d'écriture",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              "Parcourez les modèles pour structurer votre histoire, créer des personnages, etc.",
            ),
          ],
        ),
      ),
    );
  }
}
