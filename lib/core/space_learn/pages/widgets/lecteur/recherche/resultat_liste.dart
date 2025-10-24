import 'package:flutter/material.dart';
import 'livre_card.dart';

class ResultatListe extends StatelessWidget {
  const ResultatListe({super.key});

  @override
  Widget build(BuildContext context) {
    final livres = [
      {"titre": "L'importance des réseaux", "auteur": "Jean Dupont"},
      {"titre": "Créer une entreprise", "auteur": "Alice Martin"},
      {"titre": "Le futur de l’IA", "auteur": "Marie Kouadio"},
    ];

    return Column(
      children: livres
          .map((livre) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: LivreCard(
                  titre: livre["titre"]!,
                  auteur: livre["auteur"]!,
                ),
              ))
          .toList(),
    );
  }
}
