import 'discussionModel.dart';

class Message {
  final String id;
  final String discussionId;
  final String utilisateurId;
  final String contenu;
  final DateTime creeLe;
  final Discussion? discussion;
  final String? nomUtilisateur;
  final String? photoProfil;

  Message({
    required this.id,
    required this.discussionId,
    required this.utilisateurId,
    required this.contenu,
    required this.creeLe,
    this.discussion,
    this.nomUtilisateur,
    this.photoProfil,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      discussionId: json['discussion_id'],
      utilisateurId: json['utilisateur_id'],
      contenu: json['contenu'],
      creeLe: DateTime.parse(json['cree_le']),
      nomUtilisateur: json['nom_utilisateur'],
      photoProfil: json['photo_profil'],
      discussion: json['Discussion'] != null
          ? Discussion.fromJson(json['Discussion'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'discussion_id': discussionId,
      'utilisateur_id': utilisateurId,
      'contenu': contenu,
      'cree_le': creeLe.toIso8601String(),
      'Discussion': discussion?.toJson(),
    };
  }
}
