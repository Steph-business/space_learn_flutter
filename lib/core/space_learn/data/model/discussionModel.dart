import 'bookModel.dart';
import 'messageModel.dart';

class Discussion {
  final String id;
  final String creePar;
  final String livreId;
  final String titre;
  final DateTime creeLe;
  final BookModel? livre;
  final List<Message> messages;

  Discussion({
    required this.id,
    required this.creePar,
    required this.livreId,
    required this.titre,
    required this.creeLe,
    this.livre,
    required this.messages,
  });

  factory Discussion.fromJson(Map<String, dynamic> json) {
    return Discussion(
      id: json['id'],
      creePar: json['cree_par'],
      livreId: json['livre_id'],
      titre: json['titre'],
      creeLe: DateTime.parse(json['cree_le']),
      livre: json['Livre'] != null ? BookModel.fromJson(json['Livre']) : null,
      messages: json['Messages'] != null
          ? List<Message>.from(json['Messages'].map((x) => Message.fromJson(x)))
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'cree_par': creePar,
      'livre_id': livreId,
      'titre': titre,
      'cree_le': creeLe.toIso8601String(),
      'Livre': livre?.toJson(),
      'Messages': messages.isNotEmpty
          ? messages.map((e) => e.toJson()).toList()
          : [],
    };
  }
}
