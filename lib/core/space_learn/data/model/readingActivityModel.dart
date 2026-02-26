import 'book_model.dart';

class ReadingActivityModel {
  final String id;
  final String utilisateurId;
  final String livreId;
  final int chapitreCourant; // chapitre_courant
  final num pourcentage; // pourcentage
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
      id: json['id'] ?? json['ID'] ?? '',
      utilisateurId: json['utilisateur_id'] ?? json['UtilisateurId'] ?? '',
      livreId: json['livre_id'] ?? json['LivreId'] ?? '',
      chapitreCourant: json['chapitre_courant'] ?? json['ChapitreCourant'] ?? 0,
      pourcentage: json['pourcentage'] ?? json['Pourcentage'] ?? 0,
      creeLe: (json['cree_le'] ?? json['CreeLe']) != null
          ? DateTime.parse(json['cree_le'] ?? json['CreeLe'])
          : null,
      majLe: (json['maj_le'] ?? json['MajLe']) != null
          ? DateTime.parse(json['maj_le'] ?? json['MajLe'])
          : null,
      livre: (json['Livre'] ?? json['livre']) != null
          ? BookModel.fromJson(json['Livre'] ?? json['livre'])
          : null,
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
