import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import '../../../utils/api_routes.dart';
import '../model/notificationModel.dart';

class NotificationService {
  final http.Client client;

  NotificationService({http.Client? client}) : client = client ?? http.Client();

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
        // Handle grouped response: { "auteur": [...], "lecteur": [...] }
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
        // Handle standard list response
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

  /// Stream notifications from server using Server-Sent Events (SSE).
  /// Returns a broadcast stream of NotificationModel.
  Stream<NotificationModel> streamNotifications(String authToken) {
    final controller = StreamController<NotificationModel>.broadcast();

    bool cancelled = false;
    controller.onCancel = () {
      cancelled = true;
    };

    // Run a connection loop with simple backoff. This keeps the controller
    // open while reconnect attempts happen. The loop stops when the stream
    // subscription is cancelled (controller.onCancel sets `cancelled`).
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

          final response = await request.close();
          if (response.statusCode != 200) {
            // propagate error to consumer and retry
            if (!controller.isClosed)
              controller.addError(
                Exception(
                  'SSE connection failed with status ${response.statusCode}',
                ),
              );
            attempt = math.min(attempt + 1, 6);
            final wait = math.min(30, 1 << attempt);
            await Future.delayed(Duration(seconds: wait));
            continue;
          }

          // Connected successfully
          attempt = 0;

          final utf8Stream = response.transform(utf8.decoder);
          final lineStream = utf8Stream.transform(const LineSplitter());

          StringBuffer buffer = StringBuffer();

          await for (final rawLine in lineStream) {
            if (cancelled) break;
            final line = rawLine.trimRight();
            if (line.isEmpty) {
              if (buffer.isNotEmpty) {
                final dataStr = buffer.toString();
                try {
                  final decoded = jsonDecode(dataStr);

                  Map<String, dynamic>? payload;

                  // Handle several possible envelopes:
                  // 1) decoded is a Map and contains 'data' => use decoded['data']
                  // 2) decoded is a Map and directly represents the notification
                  if (decoded is Map<String, dynamic>) {
                    if (decoded.containsKey('data')) {
                      final d = decoded['data'];
                      if (d is Map) {
                        payload = Map<String, dynamic>.from(d);
                      } else if (d is String) {
                        // sometimes data is a stringified JSON
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
                  if (!controller.isClosed) controller.addError(e);
                }
                buffer.clear();
              }
            } else if (line.startsWith(':')) {
              // comment / keepalive; ignore
              continue;
            } else if (line.startsWith('data:')) {
              buffer.write(line.substring(5).trim());
            } else if (line.startsWith('event:')) {
              // ignore event type for now
              continue;
            } else {
              buffer.write(line);
            }
          }
        } catch (e) {
          // Reduce noise for common connection issues when server is down
          if (e is SocketException || e is HttpException) {
            if (attempt == 0) {
              debugPrint(
                "📡 Notification Server unreachable (Gin @ ${ApiRoutes.host}:8082). Retrying in background...",
              );
            }
          } else {
            if (!controller.isClosed) controller.addError(e);
          }
        } finally {
          try {
            request?.abort();
          } catch (_) {}
          try {
            httpClient?.close(force: true);
          } catch (_) {}
        }

        // Exponential backoff: 2s, 4s, 8s, 16s, 30s
        if (!cancelled) {
          attempt = math.min(attempt + 1, 6);
          final wait = math.min(30, 1 << attempt);
          await Future.delayed(Duration(seconds: wait));
        }
      }

      if (!controller.isClosed) await controller.close();
    }();

    return controller.stream;
  }
}
