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
    return Discussion(
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
      messages: json['Messages'] != null
          ? List<Message>.from(json['Messages'].map((x) => Message.fromJson(x)))
          : (json['messages'] != null
                ? List<Message>.from(
                    json['messages'].map((x) => Message.fromJson(x)),
                  )
                : []),
      messagesCount: json['messages_count'],
    );
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
