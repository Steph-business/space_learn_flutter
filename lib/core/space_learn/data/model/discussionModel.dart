import 'book_model.dart';
import 'messageModel.dart';

class Discussion {
  final String id;
  final String? creePar;
  final String? type;
  final String? description;
  final String? imageBanniere;
  final String? auteurId;
  final String? livreId;
  final String titre;
  final DateTime? creeLe;
  final BookModel? livre;
  final List<Message> messages;
  final int? messagesCount;
  final int? likesCount;
  final DateTime? dernierMessageLe;

  Discussion({
    required this.id,
    this.creePar,
    this.type,
    this.description,
    this.imageBanniere,
    this.auteurId,
    this.livreId,
    required this.titre,
    this.creeLe,
    this.livre,
    this.messages = const [],
    this.messagesCount,
    this.likesCount,
    this.dernierMessageLe,
  });

  factory Discussion.fromJson(Map<String, dynamic> json) {
    int parseCount(dynamic data) {
      if (data == null) return 0;
      if (data is num) return data.toInt();
      if (data is String) return int.tryParse(data) ?? 0;
      if (data is List) return data.length;
      return 0;
    }

    final int calculatedCount = (() {
      final possibleKeys = [
        'nombre_messages',
        'NombreMessages',
        'nombreMessages',
        'messages_count',
        'messagesCount',
        'nbr_messages',
        'nb_messages',
        'nbrMessages',
        'nbMessages',
        'total_messages',
        'totalMessages',
        'count',
      ];
      for (final key in possibleKeys) {
        final val = parseCount(json[key]);
        if (val > 0) return val;
      }
      if (json['_count'] != null) {
        return parseCount(
          json['_count']['Messages'] ?? json['_count']['messages'],
        );
      }
      return parseCount(json['messages']);
    })();

    final int calculatedLikes = (() {
      final possibleKeys = [
        'likes_count',
        'likesCount',
        'nb_likes',
        'nbr_likes',
      ];
      for (final key in possibleKeys) {
        final val = parseCount(json[key]);
        if (val > 0) return val;
      }
      return 0;
    })();

    final d = Discussion(
      id: json['id'] ?? '',
      creePar: json['cree_par'],
      type: json['type'],
      description: json['description'],
      imageBanniere: json['image_banniere'],
      auteurId: json['auteur_id'],
      livreId: json['livre_id'],
      titre: json['titre'] ?? '',
      creeLe: json['cree_le'] != null
          ? DateTime.tryParse(json['cree_le'])
          : null,
      livre: json['Livre'] != null ? BookModel.fromJson(json['Livre']) : null,
      messages: (json['Messages'] is List)
          ? List<Message>.from(json['Messages'].map((x) => Message.fromJson(x)))
          : (json['messages'] is List)
          ? List<Message>.from(
              (json['messages'] as List).map((x) => Message.fromJson(x)),
            )
          : [],
      messagesCount: calculatedCount,
      likesCount: calculatedLikes,
      dernierMessageLe: json['dernier_message_le'] != null
          ? DateTime.tryParse(json['dernier_message_le'])
          : null,
    );

    // Ensure messagesCount is at least messages.length
    if ((d.messagesCount == null || d.messagesCount == 0) &&
        d.messages.isNotEmpty) {
      return Discussion(
        id: d.id,
        creePar: d.creePar,
        type: d.type,
        description: d.description,
        imageBanniere: d.imageBanniere,
        auteurId: d.auteurId,
        livreId: d.livreId,
        titre: d.titre,
        creeLe: d.creeLe,
        livre: d.livre,
        messages: d.messages,
        messagesCount: d.messages.length,
        likesCount: d.likesCount,
        dernierMessageLe: d.dernierMessageLe,
      );
    }

    return d;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'cree_par': creePar,
      'type': type,
      'description': description,
      'image_banniere': imageBanniere,
      'auteur_id': auteurId,
      'livre_id': livreId,
      'titre': titre,
      'cree_le': creeLe?.toIso8601String(),
      'Livre': livre?.toJson(),
      'Messages': messages.isNotEmpty
          ? messages.map((e) => e.toJson()).toList()
          : [],
      'messages_count': messagesCount,
      'likes_count': likesCount,
    };
  }
}
