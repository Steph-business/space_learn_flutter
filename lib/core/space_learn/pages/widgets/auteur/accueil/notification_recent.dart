import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import 'package:space_learn_flutter/core/utils/token_storage.dart';
import '../../../../data/dataServices/authServices.dart';
import 'dart:async';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/notificationService.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/notificationModel.dart';

class RecentNotificationsPage extends StatefulWidget {
  final VoidCallback? onTapOpenNotifications;

  const RecentNotificationsPage({super.key, this.onTapOpenNotifications});

  @override
  State<RecentNotificationsPage> createState() =>
      _RecentNotificationsPageState();
}

class _RecentNotificationsPageState extends State<RecentNotificationsPage> {
  final NotificationService _service = NotificationService();
  List<NotificationModel> _notifications = [];
  bool _loading = true;
  String? _error;
  bool _sseConnected = false;
  String? _sseError;
  String? _currentUserId;
  // filter: 0 = Tous, 1 = Auteur (paiement/achat), 2 = Lecteur (autres)
  int _selectedFilter = 0;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _startSse();
  }

  StreamSubscription? _sseSub;

  Future<void> _startSse() async {
    try {
      final token = await TokenStorage.getToken();
      if (token == null || token.isEmpty) return;
      // cancel existing subscription if any
      await _sseSub?.cancel();
      _sseError = null;
      _sseConnected = false;
      _sseSub = _service
          .streamNotifications(token)
          .listen(
            (notif) {
              setState(() {
                // prepend new notifications
                _notifications.insert(0, notif);
                _sseConnected = true;
                _sseError = null;
              });
            },
            onError: (e) {
              setState(() {
                _sseConnected = false;
                _sseError = e?.toString();
              });
            },
          );
    } catch (e) {
      setState(() {
        _sseError = e.toString();
        _sseConnected = false;
      });
    }
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
      // Load current user id for filtering decisions
      try {
        final auth = AuthService();
        final user = await auth.getUser(token);
        _currentUserId = user?.id;
      } catch (_) {
        _currentUserId = null;
      }

      final list = await _service.getNotifications(token);
      setState(() {
        // Sort by creation date descending
        list.sort((a, b) {
          final da = a.creeLe ?? DateTime.fromMillisecondsSinceEpoch(0);
          final db = b.creeLe ?? DateTime.fromMillisecondsSinceEpoch(0);
          return db.compareTo(da);
        });
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
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(2),
        ),
        child: Column(
          children: [
            // Header: responsive layout to avoid horizontal overflow
            Padding(
              padding: const EdgeInsets.all(16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Wide layout: title + status + filters on one line
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
                                Row(
                                  children: [
                                    Icon(
                                      Icons.circle,
                                      color: _sseConnected
                                          ? Colors.green
                                          : Colors.red,
                                      size: 12,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _sseConnected
                                          ? 'Connecté'
                                          : (_sseError == null
                                                ? 'Déconnecté'
                                                : 'Erreur'),
                                      style: TextStyle(
                                        color: _sseConnected
                                            ? Colors.green
                                            : Colors.red,
                                      ),
                                    ),
                                    if (!_sseConnected)
                                      ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxWidth: 120,
                                        ),
                                        child: TextButton(
                                          onPressed: _startSse,
                                          child: const Text('Reconnecter'),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(width: 8),
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

                  // Narrow layout: stack title and status/filters
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
                            Icon(
                              Icons.circle,
                              color: _sseConnected ? Colors.green : Colors.red,
                              size: 12,
                            ),
                            Text(
                              _sseConnected
                                  ? 'Connecté'
                                  : (_sseError == null
                                        ? 'Déconnecté'
                                        : 'Erreur'),
                              style: TextStyle(
                                color: _sseConnected
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                            if (!_sseConnected)
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 120,
                                ),
                                child: TextButton(
                                  onPressed: _startSse,
                                  child: const Text('Reconnecter'),
                                ),
                              ),
                            const SizedBox(width: 8),
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

            if (_loading) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
            ] else if (_error != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 24,
                ),
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
                child: Text(
                  'Aucune notification pour le moment.',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ] else ...[
              // List filtered according to selected filter
              ..._applyFilter(_notifications).map(
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

  @override
  void dispose() {
    _sseSub?.cancel();
    super.dispose();
  }

  List<NotificationModel> _applyFilter(List<NotificationModel> items) {
    if (_selectedFilter == 0) return items;

    if (_selectedFilter == 1) {
      // Auteur: types that represent purchases/payments concerning an author's book
      final authorTypes = <String>{'paiement', 'achat', 'payment'};
      return items
          .where((n) => authorTypes.contains(n.type.toLowerCase()))
          .toList();
    }

    // Lecteur: everything else (messages, reviews, recommendations, etc.)
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
      selectedColor: const Color(0xFF06B6D4), // Cyan
      backgroundColor: const Color(0xFF1E293B),
      side: BorderSide(
        color: _selectedFilter == index
            ? Colors.transparent
            : Colors.grey[700]!,
      ),
      onSelected: (v) => setState(() => _selectedFilter = index),
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
