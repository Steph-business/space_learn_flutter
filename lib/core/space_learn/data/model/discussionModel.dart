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

    if (json['titre'] != null && json['titre'].toString().contains('Crea')) {
      print(
        '💬 DEBUG (Crea): keys=${json.keys.toList()}, count field=${json['nombre_messages']}, calculated=$calculatedCount',
      );
    }

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
    );

    // If explicit counts are 0, but we have messages loaded, trust the messages list
    if (d.messagesCount == 0 && d.messages.isNotEmpty) {
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
    };
  }
}
