import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../utils/api_routes.dart';
import '../model/notificationModel.dart';

class NotificationService {
  final http.Client client;

  NotificationService({http.Client? client}) : client = client ?? http.Client();

  Future<List<NotificationModel>> getNotifications(String authToken) async {
    final response = await client.get(
      Uri.parse(ApiRoutes.notifications),
      headers: {'Authorization': 'Bearer $authToken'},
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      final List<dynamic> notificationsJson = data['data'] ?? [];
      return notificationsJson
          .map((json) => NotificationModel.fromJson(json))
          .toList();
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
}
