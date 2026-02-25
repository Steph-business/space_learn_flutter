class ReviewModel {
  final String id;
  final String livreId;
  final String utilisateurId;
  final String? nomUtilisateur;
  final String? photoProfil;
  final int note;
  final String? commentaire;
  final DateTime? creeLe;

  ReviewModel({
    required this.id,
    required this.livreId,
    required this.utilisateurId,
    this.nomUtilisateur,
    this.photoProfil,
    required this.note,
    this.commentaire,
    this.creeLe,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    return ReviewModel(
      id: json['id'] ?? '',
      livreId: json['livre_id'] ?? '',
      utilisateurId: json['utilisateur_id'] ?? '',
      nomUtilisateur: json['nom_utilisateur'],
      photoProfil: json['photo_profil'],
      note: json['note'] ?? 0,
      commentaire: json['commentaire'],
      creeLe: json['cree_le'] != null ? DateTime.parse(json['cree_le']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'livre_id': livreId,
      'utilisateur_id': utilisateurId,
      'nom_utilisateur': nomUtilisateur,
      'photo_profil': photoProfil,
      'note': note,
      'commentaire': commentaire,
      'cree_le': creeLe?.toIso8601String(),
    };
  }
}
