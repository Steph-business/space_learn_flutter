import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:space_learn_flutter/main.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/notificationModel.dart';
import 'package:space_learn_flutter/core/themes/layout/nav_bar_lecteur.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/ecrivain/livres_page.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/lecteur/bibliotheque_page.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/lecteur/communaute/forum_discussion_page.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/ecrivain/communaute_page.dart'
    as ecrivainTeams;
import 'package:space_learn_flutter/core/utils/api_routes.dart';

class NotificationService {
  final http.Client client;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  NotificationService({http.Client? client}) : client = client ?? http.Client();

  static void initializeLocalNotifications() {
    debugPrint("🔔 Initializing Local Notifications...");
    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );

    _localNotifications.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint("🔔 System Notification clicked: ${response.payload}");
        if (response.payload != null) {
          try {
            final Map<String, dynamic> data = jsonDecode(response.payload!);
            final notif = NotificationModel.fromJson(data);
            handleNotificationTap(notif);
          } catch (e) {
            debugPrint("❌ Error parsing notification payload: $e");
          }
        }
      },
    );
  }

  /// Centralized logic to handle notification redirection
  static void handleNotificationTap(NotificationModel notif) {
    debugPrint("🔔 Handling Notification: ${notif.type} (role: ${notif.role})");

    final context = navigatorKey.currentContext;
    if (context == null) {
      debugPrint("❌ No context available for navigation");
      return;
    }

    final type = notif.type.toLowerCase();

    // Helper to clear nav stack until root shell
    void popToRoot() {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }

    // Role check (normalization)
    final isLecteur = (notif.role == 'lecteur' || notif.role == null);

    if (type.contains('message') || type.contains('reponse')) {
      if (isLecteur) {
        popToRoot();
        MainNavBar.mainNavBarKey.currentState?.navigateToCommunaute();
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ForumDiscussionPage(
              title: "Le Café des Lecteurs",
              subtitle: "Discussions générales",
            ),
          ),
        );
      }
    } else if (type.contains('annonce') || type.contains('evenement')) {
      if (!isLecteur) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ecrivainTeams.TeamsPage(),
          ),
        );
      } else {
        popToRoot();
        MainNavBar.mainNavBarKey.currentState?.navigateToCommunaute();
      }
    } else if (type.contains('paiement') ||
        type.contains('achat') ||
        type.contains('vente') ||
        type.contains('rappel_lecture') ||
        type.contains('livre') ||
        type.contains('chapitre')) {
      if (isLecteur) {
        popToRoot();
        MainNavBar.mainNavBarKey.currentState?.navigateToBibliotheque();
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                LivresPage(onBackPressed: () => Navigator.of(context).pop()),
          ),
        );
      }
    } else {
      // Default fallback
      if (isLecteur) {
        popToRoot();
        MainNavBar.mainNavBarKey.currentState?.navigateToBibliotheque();
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const BibliothequePage()),
        );
      }
    }
  }

  static Future<void> showLocalNotification({
    required String id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'high_importance_channel',
        'Notifications Importantes',
        channelDescription: 'Canal pour les notifications de l\'application',
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );

    await _localNotifications.show(
      id: id.hashCode,
      title: title.toUpperCase(),
      body: body,
      notificationDetails: notificationDetails,
      payload: payload,
    );
  }

  Future<dynamic> getNotifications(
    String authToken, {
    bool onlyUnread = false,
    bool groupByRole = false,
  }) async {
    String url = ApiRoutes.notifications;
    List<String> queryParams = [];
    if (onlyUnread) queryParams.add("lu=false");
    if (groupByRole) queryParams.add("group_by_role=true");

    if (queryParams.isNotEmpty) {
      url += "?${queryParams.join("&")}";
    }

    final response = await client.get(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $authToken'},
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      final rawData = data['data'] ?? data;

      if (groupByRole && rawData is Map<String, dynamic>) {
        final Map<String, List<NotificationModel>> grouped = {};
        rawData.forEach((key, value) {
          if (value is List) {
            grouped[key] = value
                .map((json) => NotificationModel.fromJson(json, role: key))
                .toList();
          }
        });
        return grouped;
      } else if (rawData is List) {
        return rawData.map((json) => NotificationModel.fromJson(json)).toList();
      }
      return <NotificationModel>[];
    } else {
      throw Exception('Failed to fetch notifications');
    }
  }

  Future<NotificationModel> createNotification(
    Map<String, dynamic> notificationData,
    String authToken,
  ) async {
    final response = await client.post(
      Uri.parse(ApiRoutes.notifications),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $authToken',
      },
      body: jsonEncode(notificationData),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      return NotificationModel.fromJson(data['data'] ?? data);
    } else {
      throw Exception('Failed to create notification');
    }
  }

  Future<void> markAsRead(String id, String authToken) async {
    final url = ApiRoutes.markNotificationAsRead.replaceFirst(':id', id);
    final response = await client.put(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $authToken'},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to mark notification as read');
    }
  }

  Future<void> markAllAsRead(String authToken) async {
    final response = await client.put(
      Uri.parse(ApiRoutes.markAllNotificationsAsRead),
      headers: {'Authorization': 'Bearer $authToken'},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to mark all notifications as read');
    }
  }

  Future<void> deleteNotification(String id, String authToken) async {
    final url = ApiRoutes.notificationById.replaceFirst(':id', id);
    final response = await client.delete(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $authToken'},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete notification');
    }
  }

  Stream<NotificationModel> streamNotifications(String authToken) {
    final controller = StreamController<NotificationModel>.broadcast();

    bool cancelled = false;
    controller.onCancel = () {
      cancelled = true;
    };

    () async {
      int attempt = 0;

      while (!cancelled) {
        HttpClient? httpClient;
        HttpClientRequest? request;
        try {
          final uri = Uri.parse(ApiRoutes.notificationsStream);
          httpClient = HttpClient();
          request = await httpClient.getUrl(uri);
          request.headers.set('Authorization', 'Bearer $authToken');
          request.headers.set('Accept', 'text/event-stream');
          request.headers.set('Cache-Control', 'no-cache');

          final response = await request.close();
          if (response.statusCode != 200) {
            attempt = math.min(attempt + 1, 6);
            final wait = math.min(30, 1 << attempt);
            await Future.delayed(Duration(seconds: wait));
            continue;
          }

          attempt = 0;

          final utf8Stream = response.transform(utf8.decoder);
          final lineStream = utf8Stream.transform(const LineSplitter());

          StringBuffer buffer = StringBuffer();

          await for (final rawLine in lineStream) {
            if (cancelled) break;
            final line = rawLine.trim();
            if (line.isEmpty) {
              if (buffer.isNotEmpty) {
                final dataStr = buffer.toString();
                try {
                  final decoded = jsonDecode(dataStr);
                  Map<String, dynamic>? payload;

                  if (decoded is Map<String, dynamic>) {
                    if (decoded.containsKey('data')) {
                      final d = decoded['data'];
                      if (d is Map) {
                        payload = Map<String, dynamic>.from(d);
                      } else if (d is String) {
                        try {
                          final inner = jsonDecode(d);
                          if (inner is Map)
                            payload = Map<String, dynamic>.from(inner);
                        } catch (_) {}
                      }
                    } else {
                      payload = decoded;
                    }
                  }

                  if (payload != null) {
                    final model = NotificationModel.fromJson(payload);
                    if (!controller.isClosed) controller.add(model);
                  }
                } catch (e) {
                  debugPrint("📡 SSE Parsing Error: $e");
                }
                buffer.clear();
              }
            } else if (line.startsWith('data:')) {
              buffer.write(line.substring(5).trim());
            } else if (!line.startsWith(':') && !line.startsWith('event:')) {
              buffer.write(line);
            }
          }
        } catch (e) {
          if (e is! SocketException && e is! HttpException) {
            debugPrint("📡 SSE Stream Connection Error: $e");
          }
        } finally {
          try {
            request?.abort();
          } catch (_) {}
          try {
            httpClient?.close(force: true);
          } catch (_) {}
        }

        if (!cancelled) {
          attempt = math.min(attempt + 1, 6);
          final wait = math.min(10, 1 << attempt);
          await Future.delayed(Duration(seconds: wait));
        }
      }

      if (!controller.isClosed) await controller.close();
    }();

    return controller.stream;
  }
}
