import 'bookModel.dart';

class ChapterModel {
  final String id;
  final String livreId; // livre_id
  final String titre;
  final String contenu;
  final int numero;
  final DateTime? creeLe;
  final DateTime? majLe;
  final BookModel? livre;

  ChapterModel({
    required this.id,
    required this.livreId,
    required this.titre,
    required this.contenu,
    required this.numero,
    this.creeLe,
    this.majLe,
    this.livre,
  });

  factory ChapterModel.fromJson(Map<String, dynamic> json) {
    return ChapterModel(
      id: json['id'] ?? '',
      livreId: json['livre_id'] ?? '',
      titre: json['titre'] ?? '',
      contenu: json['contenu'] ?? '',
      numero: (json['numero'] ?? 0).toInt(),
      creeLe: json['cree_le'] != null ? DateTime.parse(json['cree_le']) : null,
      majLe: json['maj_le'] != null ? DateTime.parse(json['maj_le']) : null,
      livre: json['livre'] != null ? BookModel.fromJson(json['livre']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'livre_id': livreId,
      'titre': titre,
      'contenu': contenu,
      'numero': numero,
      'cree_le': creeLe?.toIso8601String(),
      'maj_le': majLe?.toIso8601String(),
      'livre': livre?.toJson(),
    };
  }
}
