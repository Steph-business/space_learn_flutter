import 'dart:async';
import 'package:space_learn_flutter/core/utils/preferences_notifications.dart';
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
              referenceId: notification.referenceId,
              data: notification.data,
            );

            // Add new notification at the beginning
            _notifications = [taggedNotif, ..._notifications];

            // Also update grouped map if it exists
            if (assignedRole != null) {
              final list = _groupedNotifications[assignedRole] ?? [];
              _groupedNotifications[assignedRole] = [taggedNotif, ...list];
            }

            // L'alerte système, si le lecteur l'a acceptée.
            //
            // Elle partait sans condition : les interrupteurs de l'écran
            // « Notifications » enregistraient leur état sur l'appareil et
            // personne ne les relisait. Couper « Rappels de lecture »
            // n'empêchait aucun rappel d'arriver.
            //
            // La notification reste ajoutée à la liste dans tous les cas : le
            // réglage porte sur l'interruption — la bannière qui s'affiche par
            // dessus ce qu'on fait — pas sur le droit d'être informé.
            PreferencesNotifications.doitAfficher(taggedNotif.type).then((ok) {
              if (!ok) return;
              NotificationService.showLocalNotification(
                id: taggedNotif.id,
                title: taggedNotif.type,
                body: taggedNotif.contenu,
              );
            });

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
              _lastStreamError = error;
            }
          },
        );
  }

  /// Le meme modele, marque comme lu.
  ///
  /// NotificationModel n'a pas de copyWith : recopier ses neuf champs a chaque
  /// endroit qui en modifie un est un piege — le jour ou l'on en ajoute un,
  /// chaque copie oubliee le perd sans bruit. Une seule copie a tenir.
  NotificationModel _marquee(NotificationModel n) => NotificationModel(
    id: n.id,
    utilisateurId: n.utilisateurId,
    type: n.type,
    contenu: n.contenu,
    lu: true,
    creeLe: n.creeLe,
    role: n.role,
    referenceId: n.referenceId,
    data: n.data,
  );

  /// Marque une notification comme lue, dans les deux listes.
  ///
  /// Il y en a deux : `_notifications`, a plat, et `_groupedNotifications`,
  /// par role. La page des notifications lit la seconde ; cette methode ne
  /// touchait que la premiere. Une notification ouverte restait donc affichee
  /// comme non lue, et le filtre « non lues » continuait de la montrer —
  /// exactement le contraire de ce qu'on attend en la lisant.
  Future<void> markAsRead(String id, String token) async {
    try {
      await _service.markAsRead(id, token);

      final index = _notifications.indexWhere((n) => n.id == id);
      if (index != -1) {
        _notifications[index] = _marquee(_notifications[index]);
      }

      for (final role in _groupedNotifications.keys) {
        final liste = _groupedNotifications[role]!;
        final i = liste.indexWhere((n) => n.id == id);
        if (i != -1) liste[i] = _marquee(liste[i]);
      }

      notifyListeners();
    } catch (e) {}
  }

  Future<void> markAllAsRead(String token) async {
    try {
      await _service.markAllAsRead(token);
      _notifications = _notifications.map(_marquee).toList();
      _groupedNotifications = _groupedNotifications.map(
        (role, liste) => MapEntry(role, liste.map(_marquee).toList()),
      );
      notifyListeners();
    } catch (e) {}
  }

  /// Retire une notification, ici et sur le serveur.
  ///
  /// L'affichage est mis a jour avant la reponse pour que le geste reponde
  /// tout de suite ; si le serveur refuse, elle revient a sa place plutot que
  /// de disparaitre d'un ecran ou elle existe encore.
  Future<bool> supprimer(String id, String token) async {
    final avantPlat = List<NotificationModel>.from(_notifications);
    final avantGroupe = _groupedNotifications.map(
      (role, liste) => MapEntry(role, List<NotificationModel>.from(liste)),
    );

    _notifications.removeWhere((n) => n.id == id);
    for (final liste in _groupedNotifications.values) {
      liste.removeWhere((n) => n.id == id);
    }
    notifyListeners();

    try {
      await _service.deleteNotification(id, token);
      return true;
    } catch (e) {
      _notifications = avantPlat;
      _groupedNotifications = avantGroupe;
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
