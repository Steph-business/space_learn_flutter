import 'package:flutter/material.dart';

class ChapitreEnCours extends StatelessWidget {
  const ChapitreEnCours({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Guide Python Avancé - Chapitre 3",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          SizedBox(height: 8),
          Text(
            "Les fonctions avancées en Python permettent de créer des programmes plus efficaces et maintenables...",
            style: TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }
}
