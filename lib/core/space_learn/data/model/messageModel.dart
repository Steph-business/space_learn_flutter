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
  final String? rangUtilisateur;

  /// Le serveur dit si la personne connectee peut retirer ce message.
  ///
  /// Le droit ne se devine pas cote application : il vaut pour ses propres
  /// propos, mais aussi pour qui repond du salon — celui qui a ouvert le
  /// sujet, ou l'auteur du livre autour duquel le club s'est forme. Seul le
  /// serveur connait ces liens.
  final bool peutSupprimer;

  /// Ce message vient-il de l'auteur du livre autour duquel le club s'est
  /// forme ?
  ///
  /// Le role n'etait jamais transporte : dans le salon de son propre ouvrage,
  /// l'ecrivain apparaissait comme un lecteur parmi d'autres. Celui qui posait
  /// une question ne savait pas que la reponse venait de la personne qui avait
  /// ecrit le livre.
  final bool estAuteurDuLivre;

  Message({
    required this.id,
    required this.discussionId,
    required this.utilisateurId,
    required this.contenu,
    required this.creeLe,
    this.discussion,
    this.nomUtilisateur,
    this.photoProfil,
    this.rangUtilisateur,
    this.peutSupprimer = false,
    this.estAuteurDuLivre = false,
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
      rangUtilisateur: json['rang_utilisateur'] ?? json['RangUtilisateur'],
      peutSupprimer: json['peut_supprimer'] == true,
      estAuteurDuLivre: json['est_auteur_du_livre'] == true,
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
