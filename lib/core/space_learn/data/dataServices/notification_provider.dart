import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/authServices.dart';
import 'notificationService.dart';
import '../model/notificationModel.dart';

class NotificationProvider extends ChangeNotifier {
  final NotificationService _service = NotificationService();
  final AuthService _authService = AuthService();
  List<NotificationModel> _notifications = [];
  Map<String, List<NotificationModel>> _groupedNotifications = {};
  bool _isLoading = false;
  StreamSubscription? _subscription;
  dynamic _lastStreamError;

  List<NotificationModel> get notifications =>
      List.unmodifiable(_notifications);
  Map<String, List<NotificationModel>> get groupedNotifications =>
      _groupedNotifications;
  bool get isLoading => _isLoading;
  int get unreadCount => _notifications.where((n) => !n.lu).length;

  int getUnreadCountByRole(String role) {
    return _notifications
        .where((n) => !n.lu && (n.role == null || n.role == role))
        .length;
  }

  Future<void> loadNotifications(
    String token, {
    bool onlyUnread = false,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final user = await _authService.getUser(token);
      final userId = user?.id;

      final result = await _service.getNotifications(
        token,
        onlyUnread: onlyUnread,
      );
      List<NotificationModel> allNotifications = [];
      if (result is List<NotificationModel>) {
        allNotifications = result;
      }

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

  Future<void> loadGroupedNotifications(String token) async {
    _isLoading = true;
    notifyListeners();

    try {
      final user = await _authService.getUser(token);
      final userId = user?.id;

      final result = await _service.getNotifications(token, groupByRole: true);

      if (result is Map<String, List<NotificationModel>>) {
        _groupedNotifications = result;
        // Also update the flat list for unread count and backward compatibility
        _notifications = result.values.expand((element) => element).toList();
        // Server already sorts by DESC, but we can ensure it
        _notifications.sort(
          (a, b) => (b.creeLe ?? DateTime.now()).compareTo(
            a.creeLe ?? DateTime.now(),
          ),
        );
      }

      _isLoading = false;
      notifyListeners();

      if (userId != null) _startStreaming(token, userId);
    } catch (e) {
      _isLoading = false;
      notifyListeners();
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

            // Heuristic to assign role if missing
            String? assignedRole = notification.role;
            if (assignedRole == null) {
              final type = notification.type.toLowerCase();
              if (type.contains('vente') ||
                  type.contains('abonné') ||
                  type.contains('payment')) {
                assignedRole = 'auteur';
              } else if (type.contains('chapitre') ||
                  type.contains('message') ||
                  type.contains('reponse')) {
                assignedRole = 'lecteur';
              }
            }

            final taggedNotif = NotificationModel(
              id: notification.id,
              utilisateurId: notification.utilisateurId,
              type: notification.type,
              contenu: notification.contenu,
              lu: notification.lu,
              creeLe: notification.creeLe,
              role: assignedRole,
            );

            // Add new notification at the beginning
            _notifications = [taggedNotif, ..._notifications];

            // Also update grouped map if it exists
            if (assignedRole != null) {
              final list = _groupedNotifications[assignedRole] ?? [];
              _groupedNotifications[assignedRole] = [taggedNotif, ...list];
            }

            notifyListeners();
          },
          onError: (error) {
            final errorStr = error.toString();
            // Don't flood logs with connection issues if server is down
            if (errorStr.contains("SocketException") ||
                errorStr.contains("HttpException") ||
                errorStr.contains("Connection refused") ||
                errorStr.contains("Connection closed")) {
              return;
            }
            if (errorStr != _lastStreamError?.toString()) {
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
