import 'package:flutter/material.dart';

import 'package:iconsax/iconsax.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/notificationPage.dart';

class RecentNotificationsPage extends StatelessWidget {
  const RecentNotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final notifications = [
      NotificationItem(
        title: "Nouveau paiement reçu",
        description: "Vente de \"L'importance des réseaux\" - €12.99",
        timeAgo: "Il y a 2 heures",
        icon: Iconsax.coin,
        borderColor: Colors.greenAccent,
      ),
      NotificationItem(
        title: "Nouvel avis",
        description: "Marie K. a donné 5 étoiles à votre livre",
        timeAgo: "Il y a 4 heures",
        icon: Iconsax.star5,
        borderColor: Colors.blueAccent,
      ),
      NotificationItem(
        title: "Rapport mensuel",
        description: "Vos statistiques mensuelles sont disponibles",
        timeAgo: "Il y a 1 jour",
        icon: Iconsax.graph,
        borderColor: Colors.orangeAccent,
      ),
    ];

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const NotificationPage()),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.notifications, color: Colors.black87),
                  const SizedBox(width: 8),
                  Text(
                    'Notifications récentes',
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
            ...notifications.map(
              (notif) => Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: NotificationCard(item: notif),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class NotificationItem {
  final String title;
  final String description;
  final String timeAgo;
  final IconData icon;
  final Color borderColor;

  NotificationItem({
    required this.title,
    required this.description,
    required this.timeAgo,
    required this.icon,
    required this.borderColor,
  });
}

class NotificationCard extends StatelessWidget {
  final NotificationItem item;

  const NotificationCard({super.key, required this.item});

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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Notification : ${item.title}")),
          );
        },
      ),
    );
  }
}
