import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:space_learn_flutter/core/utils/message_erreur.dart';

import '../../../services/api_client.dart';
import '../../../utils/api_routes.dart';
import '../model/conversation_model.dart';

/// La messagerie privée.
///
/// Elle n'existait pas côté application : l'écran « Messages » affichait un
/// vide écrit en dur, alors que les quatre routes étaient servies depuis le
/// début. Ce service est le seul point qui les appelle.
class DmService {
  final http.Client client;

  DmService({http.Client? client}) : client = client ?? ApiClient.instance;

  Map<String, String> _entetes(String token, {bool avecCorps = false}) => {
    if (avecCorps) 'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  /// Le contenu utile d'une réponse, quelle que soit son enveloppe.
  ///
  /// Le serveur répond `{"success":…,"data":…}`, mais `data` porte
  /// `omitempty` : une liste vide peut donc revenir absente ou à `null`. C'est
  /// exactement le cas qu'il ne faut PAS confondre avec une panne — il veut
  /// dire « le serveur a répondu, il n'y a rien », et c'est le seul cas où
  /// l'écran a le droit d'écrire « Aucune conversation ».
  dynamic _contenu(String corps) {
    if (corps.trim().isEmpty) return null;
    final decode = json.decode(corps);
    if (decode is Map && decode.containsKey('data')) return decode['data'];
    return decode;
  }

  List<Map<String, dynamic>> _elements(String corps) {
    final contenu = _contenu(corps);
    if (contenu is! List) return const [];
    return contenu
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  /// Les conversations, la plus récente d'abord.
  ///
  /// L'ordre vient du serveur (`dernier_message_le` décroissant) : on ne
  /// retrie pas ici, sinon deux règles de tri cohabiteraient et finiraient par
  /// diverger.
  Future<List<Conversation>> getConversations(String token) async {
    final reponse = await client.get(
      Uri.parse(ApiRoutes.dmConversations),
      headers: _entetes(token),
    );

    if (reponse.statusCode != 200) {
      throw Exception(
        messageDeLaReponse(
          reponse,
          repli: "Vos conversations n'ont pas pu être chargées.",
        ),
      );
    }

    final conversations = <Conversation>[];
    for (final element in _elements(reponse.body)) {
      // Un élément mal formé coûte cet élément-là, pas la liste entière.
      try {
        conversations.add(Conversation.fromJson(element));
      } catch (_) {
        continue;
      }
    }
    return conversations;
  }

  /// La conversation avec quelqu'un, créée par le serveur si elle n'existe pas.
  ///
  /// Le client ne fabrique jamais d'identifiant de conversation : il donne
  /// celui de la personne et reçoit le fil qui va avec.
  Future<Conversation> ouvrirConversationAvec(
    String utilisateurId,
    String token,
  ) async {
    final url = ApiRoutes.dmConversationAvecUtilisateur.replaceFirst(
      ':user_id',
      utilisateurId,
    );
    final reponse = await client.get(Uri.parse(url), headers: _entetes(token));

    if (reponse.statusCode != 200) {
      throw Exception(
        messageDeLaReponse(
          reponse,
          repli: "Cette conversation n'a pas pu être ouverte.",
        ),
      );
    }

    final contenu = _contenu(reponse.body);
    if (contenu is! Map) {
      throw Exception("Cette conversation n'a pas pu être ouverte.");
    }
    return Conversation.fromJson(Map<String, dynamic>.from(contenu));
  }

  /// Le fil d'une conversation.
  ///
  /// Cette lecture marque au passage comme lus les messages REÇUS : il n'y a
  /// donc pas d'appel séparé pour éteindre la pastille de non-lus.
  ///
  /// [moiId] n'est qu'un filet : le serveur transmet `de_moi`, et c'est lui qui
  /// fait foi. Il sert au cas où le champ manquerait.
  Future<List<MessagePrive>> getMessages(
    String conversationId,
    String token, {
    String? moiId,
  }) async {
    final url = ApiRoutes.dmMessagesDeConversation.replaceFirst(
      ':id',
      conversationId,
    );
    final reponse = await client.get(Uri.parse(url), headers: _entetes(token));

    if (reponse.statusCode != 200) {
      throw Exception(
        messageDeLaReponse(
          reponse,
          repli: "Les messages n'ont pas pu être chargés.",
        ),
      );
    }

    final messages = <MessagePrive>[];
    for (final element in _elements(reponse.body)) {
      try {
        messages.add(MessagePrive.fromJson(element, moiId: moiId));
      } catch (_) {
        continue;
      }
    }
    return messages;
  }

  /// Envoie un message dans une conversation.
  ///
  /// Le serveur refuse un contenu vide après nettoyage, ou au-delà de cinq
  /// mille caractères, et prévient le destinataire.
  Future<MessagePrive> envoyerMessage(
    String conversationId,
    String contenu,
    String token, {
    String? moiId,
  }) async {
    final reponse = await client.post(
      Uri.parse(ApiRoutes.dmMessages),
      headers: _entetes(token, avecCorps: true),
      body: json.encode({
        'conversation_id': conversationId,
        'contenu': contenu,
      }),
    );

    if (reponse.statusCode != 201 && reponse.statusCode != 200) {
      throw Exception(
        messageDeLaReponse(
          reponse,
          repli: "Ce message n'a pas pu être envoyé.",
        ),
      );
    }

    final contenuReponse = _contenu(reponse.body);
    if (contenuReponse is! Map) {
      throw Exception("Ce message n'a pas pu être envoyé.");
    }

    // Un message qu'on vient d'écrire est le sien : le côté de la bulle ne
    // dépend pas de ce que la réponse de création a pensé à transporter.
    final message = MessagePrive.fromJson(
      Map<String, dynamic>.from(contenuReponse),
      moiId: moiId,
    );
    return MessagePrive(
      id: message.id,
      expediteurId: message.expediteurId,
      contenu: message.contenu.isEmpty ? contenu : message.contenu,
      lu: message.lu,
      creeLe: message.creeLe ?? DateTime.now(),
      deMoi: true,
    );
  }
}
