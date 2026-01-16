import 'bookModel.dart';

class ReadingActivityModel {
  final String id;
  final String utilisateurId;
  final String livreId;
  final int chapitreIndex;
  final int position;
  final DateTime? creeLe;
  final DateTime? misAJourLe;
  final BookModel? livre;

  ReadingActivityModel({
    required this.id,
    required this.utilisateurId,
    required this.livreId,
    required this.chapitreIndex,
    required this.position,
    this.creeLe,
    this.misAJourLe,
    this.livre,
  });

  factory ReadingActivityModel.fromJson(Map<String, dynamic> json) {
    return ReadingActivityModel(
      id: json['id'] ?? '',
      utilisateurId: json['utilisateur_id'] ?? '',
      livreId: json['livre_id'] ?? '',
      chapitreIndex: json['chapitre_index'] ?? 0,
      position: json['position'] ?? 0,
      creeLe: json['cree_le'] != null ? DateTime.parse(json['cree_le']) : null,
      misAJourLe: json['mis_a_jour_le'] != null
          ? DateTime.parse(json['mis_a_jour_le'])
          : null,
      livre: json['livre'] != null ? BookModel.fromJson(json['livre']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'utilisateur_id': utilisateurId,
      'livre_id': livreId,
      'chapitre_index': chapitreIndex,
      'position': position,
      'cree_le': creeLe?.toIso8601String(),
      'mis_a_jour_le': misAJourLe?.toIso8601String(),
      'livre': livre?.toJson(),
    };
  }
}
