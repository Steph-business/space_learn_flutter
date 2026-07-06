import 'book_model.dart';
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

  final String? nomUtilisateur;

  ReviewModel({
    required this.id,
    required this.utilisateurId,
    required this.livreId,
    required this.note,
    required this.commentaire,
    this.creeLe,
    this.livre,
    this.utilisateur,
    this.nomUtilisateur,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    String? name =
        json['nom_utilisateur'] ??
        json['username'] ??
        json['NomComplet'] ??
        json['nom_complet'];

    final dateStr = json['cree_le'] ?? json['created_at'] ?? json['CreeLe'];
    DateTime? creeLe;
    if (dateStr != null) {
      try {
        creeLe = DateTime.parse(dateStr.toString());
      } catch (e) {
      }
    }

    final livreData = json['Livre'] ?? json['livre'] ?? json['book'];
    final userData = json['utilisateur'] ?? json['user'] ?? json['Utilisateur'];

    return ReviewModel(
      id: json['id']?.toString() ?? '',
      utilisateurId:
          (json['utilisateur_id'] ?? json['user_id'])?.toString() ?? '',
      livreId: (json['livre_id'] ?? json['book_id'])?.toString() ?? '',
      note: json['note'] ?? 0,
      commentaire: json['commentaire'] ?? json['comment'] ?? '',
      creeLe: creeLe,
      livre: livreData != null ? BookModel.fromJson(livreData) : null,
      utilisateur: userData != null ? ProfilModel.fromJson(userData) : null,
      nomUtilisateur: name,
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
      // 'Livre': livre?.toJson(), // Removed to avoid infinite recursion
      'utilisateur': utilisateur?.toJson(),
    };
  }
}
