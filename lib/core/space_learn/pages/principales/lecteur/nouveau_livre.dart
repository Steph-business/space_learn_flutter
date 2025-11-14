import 'package:flutter/material.dart';

class NouveauLivreWidget extends StatelessWidget {
  const NouveauLivreWidget({super.key});

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
              "Créer un nouveau livre",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            TextField(decoration: InputDecoration(labelText: "Titre du livre")),
          ],
        ),
      ),
    );
  }
}
