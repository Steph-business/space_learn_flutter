import 'bookModel.dart';

class ReadingActivityModel {
  final String id;
  final String utilisateurId;
  final String livreId;
  final int chapitreCourant; // chapitre_courant
  final int pourcentage; // pourcentage
  final DateTime? creeLe;
  final DateTime? majLe; // maj_le
  final BookModel? livre;

  ReadingActivityModel({
    required this.id,
    required this.utilisateurId,
    required this.livreId,
    required this.chapitreCourant,
    required this.pourcentage,
    this.creeLe,
    this.majLe,
    this.livre,
  });

  factory ReadingActivityModel.fromJson(Map<String, dynamic> json) {
    return ReadingActivityModel(
      id: json['id'] ?? '',
      utilisateurId: json['utilisateur_id'] ?? '',
      livreId: json['livre_id'] ?? '',
      chapitreCourant: json['chapitre_courant'] ?? 0,
      pourcentage: json['pourcentage'] ?? 0,
      creeLe: json['cree_le'] != null ? DateTime.parse(json['cree_le']) : null,
      majLe: json['maj_le'] != null ? DateTime.parse(json['maj_le']) : null,
      livre: json['Livre'] != null ? BookModel.fromJson(json['Livre']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'utilisateur_id': utilisateurId,
      'livre_id': livreId,
      'chapitre_courant': chapitreCourant,
      'pourcentage': pourcentage,
      'cree_le': creeLe?.toIso8601String(),
      'maj_le': majLe?.toIso8601String(),
      'Livre': livre?.toJson(),
    };
  }
}
