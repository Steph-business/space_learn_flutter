import 'bookModel.dart';

class RecommendationModel {
  final String id;
  final String utilisateurId;
  final String livreId;
  final String raison;
  final DateTime? creeLe;
  final BookModel? livre;

  RecommendationModel({
    required this.id,
    required this.utilisateurId,
    required this.livreId,
    required this.raison,
    this.creeLe,
    this.livre,
  });

  factory RecommendationModel.fromJson(Map<String, dynamic> json) {
    return RecommendationModel(
      id: json['id'] ?? '',
      utilisateurId: json['utilisateur_id'] ?? '',
      livreId: json['livre_id'] ?? '',
      raison: json['raison'] ?? '',
      creeLe: json['cree_le'] != null ? DateTime.parse(json['cree_le']) : null,
      livre: json['livre'] != null ? BookModel.fromJson(json['livre']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'utilisateur_id': utilisateurId,
      'livre_id': livreId,
      'raison': raison,
      'cree_le': creeLe?.toIso8601String(),
      'livre': livre?.toJson(),
    };
  }
}
