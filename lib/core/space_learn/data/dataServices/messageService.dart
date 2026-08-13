import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../services/api_client.dart';
import '../model/messageModel.dart';
import '../../../utils/api_routes.dart';

class MessageService {
  final http.Client client;

  MessageService({http.Client? client}) : client = client ?? ApiClient.instance;

  Future<Message> createMessage(
    String discussionId,
    String contenu,
    String token,
  ) async {
    final response = await client.post(
      Uri.parse(ApiRoutes.messages),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({'discussion_id': discussionId, 'contenu': contenu}),
    );

    if (response.statusCode == 201) {
      final Map<String, dynamic> data = json.decode(response.body);
      return Message.fromJson(data['data'] ?? data);
    } else {
      throw Exception('Failed to create message');
    }
  }

  Future<List<Message>> getMessagesByDiscussion(
    String discussionId,
    String token,
  ) async {
    final url = ApiRoutes.messagesByDiscussion.replaceFirst(
      ':discussion_id',
      discussionId,
    );
    final response = await client.get(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = json.decode(response.body);
      final List<dynamic> list = responseData['data'] ?? [];
      return list.map((json) => Message.fromJson(json)).toList();
    } else {
      throw Exception('Failed to fetch messages');
    }
  }

  /// Retire un message.
  ///
  /// Le serveur decide qui en a le droit : son auteur, celui qui a ouvert le
  /// sujet, ou l'auteur du livre autour duquel le club s'est forme.
  Future<void> deleteMessage(String messageId, String token) async {
    final url = ApiRoutes.messageById.replaceFirst(':id', messageId);
    final response = await client.delete(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to delete message');
    }
  }
}
