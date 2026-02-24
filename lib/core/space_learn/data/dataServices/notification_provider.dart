import 'dart:async';
import 'package:flutter/foundation.dart';
import 'notificationService.dart';
import '../model/notificationModel.dart';

class NotificationProvider extends ChangeNotifier {
  final NotificationService _service = NotificationService();
  List<NotificationModel> _notifications = [];
  bool _isLoading = false;
  StreamSubscription? _subscription;

  List<NotificationModel> get notifications =>
      List.unmodifiable(_notifications);
  bool get isLoading => _isLoading;
  int get unreadCount => _notifications.where((n) => !n.lu).length;

  Future<void> loadNotifications(String token) async {
    _isLoading = true;
    notifyListeners();

    try {
      _notifications = await _service.getNotifications(token);
      _isLoading = false;
      notifyListeners();

      // Start streaming for real-time updates
      _startStreaming(token);
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  void _startStreaming(String token) {
    _subscription?.cancel();
    _subscription = _service
        .streamNotifications(token)
        .listen(
          (notification) {
            // Add new notification at the beginning
            _notifications = [notification, ..._notifications];
            notifyListeners();
          },
          onError: (error) {
            debugPrint("Notification Stream Error: $error");
          },
        );
  }

  Future<void> markAsRead(String id, String token) async {
    try {
      await _service.markAsRead(id, token);
      final index = _notifications.indexWhere((n) => n.id == id);
      if (index != -1) {
        final old = _notifications[index];
        _notifications[index] = NotificationModel(
          id: old.id,
          utilisateurId: old.utilisateurId,
          type: old.type,
          contenu: old.contenu,
          lu: true,
          creeLe: old.creeLe,
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error marking notification as read: $e");
    }
  }

  Future<void> markAllAsRead(String token) async {
    try {
      await _service.markAllAsRead(token);
      _notifications = _notifications
          .map(
            (n) => NotificationModel(
              id: n.id,
              utilisateurId: n.utilisateurId,
              type: n.type,
              contenu: n.contenu,
              lu: true,
              creeLe: n.creeLe,
            ),
          )
          .toList();
      notifyListeners();
    } catch (e) {
      debugPrint("Error marking all notifications as read: $e");
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
