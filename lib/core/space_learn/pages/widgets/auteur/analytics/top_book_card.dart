import 'package:flutter/material.dart';

class TopBookCard extends StatelessWidget {
  final int rank;
  final String title;
  final String revenue;
  final String views;
  final String downloads;
  final double rating;
  final Color color;

  const TopBookCard({
    super.key,
    required this.rank,
    required this.title,
    required this.revenue,
    required this.views,
    required this.downloads,
    required this.rating,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Text(rank.toString(), style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("$views • $downloads"),
        trailing: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(revenue, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 16),
                Text(rating.toString()),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
