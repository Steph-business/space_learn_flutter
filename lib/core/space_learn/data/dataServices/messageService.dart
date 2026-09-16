import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../services/api_client.dart';
import '../model/messageModel.dart';
import '../../../utils/api_routes.dart';
import 'package:space_learn_flutter/core/utils/message_erreur.dart';

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
    } else if (response.statusCode == 403) {
      // MÊME REFUS QUE LA LECTURE, ET IL MANQUAIT ICI.
      //
      // `message.Service.PeutEcrire` refuse en 403 l'écriture dans le salon
      // d'un livre qu'on n'a plus en bibliothèque — exactement comme
      // `PeutVoir` refuse la lecture. Seul `getMessages` connaissait ce cas :
      // l'envoi, lui, rendait une `Exception` ordinaire, indiscernable d'une
      // panne. L'écran désarmait donc son verrou dans un `finally` commenté
      // « un échec ne doit pas empêcher de réessayer », et la requête refusée
      // repartait autant de fois qu'on appuyait — sur un refus qui, par
      // construction, ne peut jamais aboutir.
      throw AccesRefuse(
        messageDeLaReponse(
          response,
          repli: "Vous ne pouvez plus écrire dans ce salon.",
        ),
      );
    } else {
      throw Exception(
        messageDeLaReponse(
          response,
          repli: "Ce message n'a pas pu être envoyé.",
        ),
      );
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

      // Une boucle plutôt qu'un `map`, comme dans `DmService` : `map` propage
      // l'échec du premier élément mal formé à toute la liste, et le fil
      // entier s'affiche alors en panne pour un seul message abîmé. Ici
      // l'élément illisible est SAUTÉ et les autres s'affichent.
      final messages = <Message>[];
      for (final element in list) {
        try {
          messages.add(Message.fromJson(Map<String, dynamic>.from(element)));
        } catch (e) {
          // Sauté, mais pas en silence complet : une trace pour le journal,
          // rien à l'écran — la personne qui lit n'a rien à faire de cette
          // information, et un fil amputé d'un message reste utile.
          debugPrint('Message illisible ignoré dans $discussionId : $e');
          continue;
        }
      }
      return messages;
    } else if (response.statusCode == 403) {
      // UN REFUS DE DROIT N'EST PAS UNE PANNE, ET L'ÉCRAN NE PEUT PAS LE VOIR.
      //
      // Le serveur ne rend plus le fil d'un club à qui n'a pas le livre en
      // bibliothèque et n'en est pas l'auteur (message.Service.PeutVoir) : il
      // répond 403 avec sa raison en français. Cette phrase-là ne se distingue
      // d'un message de panne par aucun mot ; seul le code HTTP le dit, et il
      // s'arrête ici. Sans ce type, l'écran affichait la bonne phrase sous un
      // bouton « Réessayer » qui rejouait indéfiniment la requête refusée.
      throw AccesRefuse(
        messageDeLaReponse(
          response,
          repli: "Ce salon est réservé aux lecteurs de ce livre.",
        ),
      );
    } else {
      throw Exception(
        messageDeLaReponse(
          response,
          repli: "Impossible de charger les messages.",
        ),
      );
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
      throw Exception(
        messageDeLaReponse(
          response,
          repli: "Ce message n'a pas pu être supprimé.",
        ),
      );
    }
  }

  /// Réécrit un message.
  ///
  /// La route existait côté serveur depuis toujours, correctement protégée —
  /// mais rien ne l'appelait : on pouvait effacer un propos, jamais corriger
  /// une faute. Le serveur refuse au-delà de vingt-quatre heures, et à tout
  /// autre que l'auteur du texte.
  Future<Message> updateMessage(
    String messageId,
    String contenu,
    String token,
  ) async {
    final url = ApiRoutes.messageById.replaceFirst(':id', messageId);
    final response = await client.put(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'contenu': contenu}),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return Message.fromJson(data['data'] ?? data);
    }

    throw Exception(
      messageDeLaReponse(
        response,
        repli: "Ce message n'a pas pu être modifié.",
      ),
    );
  }
}
