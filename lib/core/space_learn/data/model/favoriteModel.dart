import 'bookModel.dart';

class FavoriteModel {
  final String id;
  final String utilisateurId; // utilisateur_id
  final String livreId; // livre_id
  final DateTime? creeLe;
  final BookModel? livre;

  FavoriteModel({
    required this.id,
    required this.utilisateurId,
    required this.livreId,
    this.creeLe,
    this.livre,
  });

  factory FavoriteModel.fromJson(Map<String, dynamic> json) {
    return FavoriteModel(
      id: json['id'] ?? '',
      utilisateurId: json['utilisateur_id'] ?? '',
      livreId: json['livre_id'] ?? '',
      creeLe: json['cree_le'] != null ? DateTime.parse(json['cree_le']) : null,
      livre: json['livre'] != null ? BookModel.fromJson(json['livre']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'utilisateur_id': utilisateurId,
      'livre_id': livreId,
      'cree_le': creeLe?.toIso8601String(),
      'livre': livre?.toJson(),
    };
  }
}
