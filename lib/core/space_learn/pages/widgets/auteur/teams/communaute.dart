import 'package:flutter/material.dart';

class Communaute extends StatelessWidget {
  const Communaute({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          "Commentaires récents",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _commentCard(
          name: "Marie Dubois",
          time: "Il y a 2h",
          comment:
              "Excellent livre ! Les conseils sur le networking sont très pratiques. J'ai déjà commencé à appliquer vos méthodes.",
          title: "L'importance des réseaux",
          stars: 5,
        ),
        _commentCard(
          name: "Thomas Martin",
          time: "Il y a 5h",
          comment:
              "Merci pour ce guide de méditation. Les exercices sont parfaits pour débuter. Avez-vous prévu une suite ?",
          title: "Apprendre à méditer",
          stars: 4,
        ),
      ],
    );
  }

  Widget _commentCard({
    required String name,
    required String time,
    required String comment,
    required String title,
    required int stars,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(time, style: const TextStyle(color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 8),
          Text(comment),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.bookmark, color: Colors.deepPurple, size: 18),
              const SizedBox(width: 4),
              Text(title,
                  style: const TextStyle(
                      color: Colors.deepPurple,
                      fontWeight: FontWeight.w500)),
              const SizedBox(width: 8),
              ...List.generate(
                stars,
                (i) => const Icon(Icons.star, color: Colors.amber, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
