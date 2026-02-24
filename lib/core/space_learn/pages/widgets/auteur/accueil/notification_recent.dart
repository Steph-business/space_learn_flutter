import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/notification_provider.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/notificationModel.dart';

class RecentNotificationsPage extends StatefulWidget {
  final VoidCallback? onTapOpenNotifications;

  const RecentNotificationsPage({super.key, this.onTapOpenNotifications});

  @override
  State<RecentNotificationsPage> createState() =>
      _RecentNotificationsPageState();
}

class _RecentNotificationsPageState extends State<RecentNotificationsPage> {
  int _selectedFilter = 0;

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

  List<NotificationModel> _applyFilter(List<NotificationModel> items) {
    if (_selectedFilter == 0) return items;

    if (_selectedFilter == 1) {
      final authorTypes = <String>{'paiement', 'achat', 'payment'};
      return items
          .where((n) => authorTypes.contains(n.type.toLowerCase()))
          .toList();
    }

    final authorTypes = <String>{'paiement', 'achat', 'payment'};
    return items
        .where((n) => !authorTypes.contains(n.type.toLowerCase()))
        .toList();
  }

  Widget _buildChoiceChip(String label, int index) {
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: _selectedFilter == index ? Colors.white : Colors.grey[400],
        ),
      ),
      selected: _selectedFilter == index,
      selectedColor: const Color(0xFF06B6D4),
      backgroundColor: const Color(0xFF1E293B),
      side: BorderSide(
        color: _selectedFilter == index
            ? Colors.transparent
            : Colors.grey[700]!,
      ),
      onSelected: (v) => setState(() => _selectedFilter = index),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notificationProvider = context.watch<NotificationProvider>();
    final notifications = notificationProvider.notifications;
    final loading = notificationProvider.isLoading;

    return GestureDetector(
      onTap: widget.onTapOpenNotifications,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(2),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth > 300) {
                    return Row(
                      children: [
                        const Icon(Icons.notifications, color: Colors.white),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Notifications récentes',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Flexible(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: Row(
                              children: [
                                _buildChoiceChip('Tous', 0),
                                const SizedBox(width: 6),
                                _buildChoiceChip('Auteur', 1),
                                const SizedBox(width: 6),
                                _buildChoiceChip('Lecteur', 2),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.notifications, color: Colors.white),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Notifications récentes',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: constraints.maxWidth * 0.95,
                        ),
                        child: Wrap(
                          alignment: WrapAlignment.end,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            _buildChoiceChip('Tous', 0),
                            const SizedBox(width: 6),
                            _buildChoiceChip('Auteur', 1),
                            const SizedBox(width: 6),
                            _buildChoiceChip('Lecteur', 2),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            if (loading && notifications.isEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
            ] else if (notifications.isEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Aucune notification pour le moment.',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ] else ...[
              ..._applyFilter(notifications).map(
                (notif) => Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
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
    required this.model,
    required this.icon,
    required this.borderColor,
    required this.timeAgo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
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
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: Colors.white,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              model.contenu,
              style: TextStyle(color: Colors.grey[400], fontSize: 13),
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
