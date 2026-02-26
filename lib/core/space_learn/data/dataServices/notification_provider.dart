import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/authServices.dart';
import 'notificationService.dart';
import '../model/notificationModel.dart';

class NotificationProvider extends ChangeNotifier {
  final NotificationService _service = NotificationService();
  final AuthService _authService = AuthService();
  List<NotificationModel> _notifications = [];
  bool _isLoading = false;
  StreamSubscription? _subscription;
  dynamic _lastStreamError;

  List<NotificationModel> get notifications =>
      List.unmodifiable(_notifications);
  bool get isLoading => _isLoading;
  int get unreadCount => _notifications.where((n) => !n.lu).length;

  Future<void> loadNotifications(String token) async {
    _isLoading = true;
    notifyListeners();

    try {
      final user = await _authService.getUser(token);
      final userId = user?.id;

      final allNotifications = await _service.getNotifications(token);

      if (userId != null && userId.isNotEmpty) {
        _notifications = allNotifications
            .where((n) => n.utilisateurId == userId)
            .toList();
      } else {
        // Si on ne connaît pas l'utilisateur, on ne montre rien par sécurité
        _notifications = [];
        debugPrint(
          "⚠️ NotificationProvider: userId est null ou vide, liste vidée.",
        );
      }

      _isLoading = false;
      notifyListeners();

      // Start streaming for real-time updates
      _startStreaming(token, userId);
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  void _startStreaming(String token, String? userId) {
    _subscription?.cancel();
    _subscription = _service
        .streamNotifications(token)
        .listen(
          (notification) {
            if (userId == null ||
                userId.isEmpty ||
                notification.utilisateurId != userId) {
              return; // Ignorer les notifications qui ne nous concernent pas
            }
            // Add new notification at the beginning
            _notifications = [notification, ..._notifications];
            notifyListeners();
          },
          onError: (error) {
            // Only log if it's a new or different error to avoid flooding
            if (error.toString() != _lastStreamError?.toString()) {
              debugPrint("Notification Stream Error: $error");
              _lastStreamError = error;
            }
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
