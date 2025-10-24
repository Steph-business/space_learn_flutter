import 'package:flutter/material.dart';

class RecentActivitySection extends StatelessWidget {
  const RecentActivitySection({super.key});

  @override
  Widget build(BuildContext context) {
    final activities = [
      {
        'icon': Icons.menu_book_outlined,
        'color': const Color(0xFF9C27B0),
        'title': 'Lecture de 45 minutes',
        'time': 'Il y a 2 heures',
      },
      {
        'icon': Icons.pause_circle_outline,
        'color': const Color(0xFFFF9800),
        'title': 'Marque-page ajouté',
        'time': 'Il y a 1 heure',
      },
      {
        'icon': Icons.check_circle_outline,
        'color': Colors.green,
        'title': 'Livre terminé: "Crée une"',
        'time': 'Il y a 30 minutes',
      },
    ];

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: activities.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final activity = activities[index];
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: (activity['color'] as Color).withOpacity(0.1),
              child: Icon(
                activity['icon'] as IconData,
                color: activity['color'] as Color,
                size: 24,
              ),
            ),
            title: Text(
              activity['title'] as String,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            subtitle: Text(
              activity['time'] as String,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ),
        );
      },
    );
  }
}
