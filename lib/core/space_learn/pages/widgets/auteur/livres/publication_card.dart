import 'package:flutter/material.dart';

class PublicationCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const PublicationCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    bool isPublished = data["statut"] == "Publié";

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
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
      child: Row(
        children: [
          Container(
            width: 60,
            height: 70,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: [Colors.pinkAccent.shade100, Colors.purpleAccent],
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data["titre"],
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isPublished
                      ? "${data["statut"]} • ${data["vues"]} • ${data["downloads"]}"
                      : "${data["statut"]} • ${data["progression"]}",
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      "💰 ${data["revenu"]}",
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.star, color: Colors.amber, size: 16),
                    Text(data["note"]),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isPublished
                            ? Colors.green.shade100
                            : Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        data["statut"],
                        style: TextStyle(
                          color: isPublished
                              ? Colors.green.shade800
                              : Colors.orange.shade800,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
