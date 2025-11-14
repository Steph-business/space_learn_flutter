import 'package:flutter/material.dart';

import 'publication_card.dart';

class PublicationsList extends StatelessWidget {
  const PublicationsList({super.key});

  @override
  Widget build(BuildContext context) {
    final publications = [
      {
        "titre": "L'importance des réseaux",
        "statut": "Publié",
        "vues": "245 vues",
        "downloads": "56 téléchargements",
        "revenu": "127€",
        "note": "4.8",
        "image": "assets/images/book1.png",
      },
      {
        "titre": "Guide Python Avancé",
        "statut": "Brouillon",
        "progression": "85% terminé",
        "revenu": "0€",
        "note": "4.2",
        "image": "assets/images/book2.png",
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Publications",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        ...publications.map((p) => PublicationCard(data: p)).toList(),
      ],
    );
  }
}
