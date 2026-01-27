import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import 'package:space_learn_flutter/core/utils/tokenStorage.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/notificationService.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/notificationModel.dart';

class RecentNotificationsPage extends StatefulWidget {
  final VoidCallback? onTapOpenNotifications;

  const RecentNotificationsPage({super.key, this.onTapOpenNotifications});

  @override
  State<RecentNotificationsPage> createState() => _RecentNotificationsPageState();
}

class _RecentNotificationsPageState extends State<RecentNotificationsPage> {
  final NotificationService _service = NotificationService();
  List<NotificationModel> _notifications = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final token = await TokenStorage.getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Utilisateur non authentifié');
      }

      final list = await _service.getNotifications(token);
      setState(() {
        _notifications = list;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  String _formatTimeAgo(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} minutes';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours} heures';
    return 'Il y a ${diff.inDays} jours';
  }

  IconData _iconForType(String type) {
    switch (type.toLowerCase()) {
      case 'payment':
      case 'paiement':
        return Iconsax.coin;
      case 'review':
      case 'avis':
        return Iconsax.star5;
      case 'report':
      case 'rapport':
        return Iconsax.graph;
      default:
        return Iconsax.notification;
    }
  }

  Color _colorForRead(bool lu) => lu ? Colors.grey : Colors.blueAccent;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTapOpenNotifications,
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
                  const Icon(Icons.notifications, color: Colors.black87),
                  const SizedBox(width: 8),
                  const Text(
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

            if (_loading) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
            ] else if (_error != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                child: Column(
                  children: [
                    Text('Erreur: $_error'),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _loadNotifications,
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
            ] else if (_notifications.isEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('Aucune notification pour le moment.'),
              ),
            ] else ...[
              // List
              ..._notifications.map(
                (notif) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: _NotificationCardFromModel(
                    model: notif,
                    icon: _iconForType(notif.type),
                    borderColor: _colorForRead(notif.lu),
                    timeAgo: _formatTimeAgo(notif.creeLe),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }
}

class _NotificationCardFromModel extends StatelessWidget {
  final NotificationModel model;
  final IconData icon;
  final Color borderColor;
  final String timeAgo;

  const _NotificationCardFromModel({
    Key? key,
    required this.model,
    required this.icon,
    required this.borderColor,
    required this.timeAgo,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(width: 5, color: borderColor)),
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
          backgroundColor: borderColor.withOpacity(0.15),
          child: Icon(icon, color: borderColor, size: 22),
        ),
        title: Text(
          model.type,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              model.contenu,
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              timeAgo,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Notification : ${model.contenu}")),
          );
        },
      ),
    );
  }
}
