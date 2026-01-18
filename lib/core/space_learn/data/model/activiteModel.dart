import 'bookModel.dart';
import 'profilModel.dart';

class ReviewModel {
  final String id;
  final String utilisateurId; // utilisateur_id
  final String livreId; // livre_id
  final int note;
  final String commentaire;
  final DateTime? creeLe;
  final BookModel? livre;
  final ProfilModel? utilisateur;

  ReviewModel({
    required this.id,
    required this.utilisateurId,
    required this.livreId,
    required this.note,
    required this.commentaire,
    this.creeLe,
    this.livre,
    this.utilisateur,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    return ReviewModel(
      id: json['id'] ?? '',
      utilisateurId: json['utilisateur_id'] ?? '',
      livreId: json['livre_id'] ?? '',
      note: json['note'] ?? 0,
      commentaire: json['commentaire'] ?? '',
      creeLe: json['cree_le'] != null ? DateTime.parse(json['cree_le']) : null,
      livre: json['Livre'] != null ? BookModel.fromJson(json['Livre']) : null,
      utilisateur: json['utilisateur'] != null
          ? ProfilModel.fromJson(json['utilisateur'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'utilisateur_id': utilisateurId,
      'livre_id': livreId,
      'note': note,
      'commentaire': commentaire,
      'cree_le': creeLe?.toIso8601String(),
      'Livre': livre?.toJson(),
      'utilisateur': utilisateur?.toJson(),
    };
  }
}
