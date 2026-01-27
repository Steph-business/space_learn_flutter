import 'package:flutter/material.dart';

import 'package:iconsax/iconsax.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/ecrivain/teamsPage.dart';

class CommunityEventsPage extends StatelessWidget {
  const CommunityEventsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final events = [
      CommunityEventItem(
        title: "Nouveau membre d'équipe",
        description: "Sarah L. a rejoint votre équipe \"Écrivains Fantasy\"",
        timeAgo: "Il y a 1 heure",
        icon: Iconsax.user_add,
        borderColor: Colors.blueAccent,
      ),
      CommunityEventItem(
        title: "Invitation reçue",
        description:
            "Pierre M. vous invite à collaborer sur \"Les Mystères de Paris\"",
        timeAgo: "Il y a 3 heures",
        icon: Iconsax.user_tick,
        borderColor: Colors.greenAccent,
      ),
      CommunityEventItem(
        title: "Événement d'équipe",
        description: "Session d'écriture collaborative programmée pour demain",
        timeAgo: "Il y a 5 heures",
        icon: Iconsax.calendar,
        borderColor: Colors.purpleAccent,
      ),
    ];

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => TeamsPage()),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(2),
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Iconsax.people, color: Colors.black87),
                  const SizedBox(width: 8),
                  Text(
                    'Événements communautaires',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            // List
            ...events.map(
              (event) => Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: CommunityEventCard(item: event),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class CommunityEventItem {
  final String title;
  final String description;
  final String timeAgo;
  final IconData icon;
  final Color borderColor;

  CommunityEventItem({
    required this.title,
    required this.description,
    required this.timeAgo,
    required this.icon,
    required this.borderColor,
  });
}

class CommunityEventCard extends StatelessWidget {
  final CommunityEventItem item;

  const CommunityEventCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(width: 5, color: item.borderColor)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 6,
            offset: const Offset(2, 3),
          ),
        ],
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: item.borderColor.withOpacity(0.15),
          child: Icon(item.icon, color: item.borderColor, size: 22),
        ),
        title: Text(
          item.title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              item.description,
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              item.timeAgo,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        onTap: () {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Événement : ${item.title}")));
        },
      ),
    );
  }
}
