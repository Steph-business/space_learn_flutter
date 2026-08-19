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

  /// Réservé à l'auteur du propos, et pour vingt-quatre heures.
  ///
  /// Modérer, c'est retirer — jamais réécrire au nom de quelqu'un : le
  /// responsable d'un salon peut donc supprimer sans jamais pouvoir modifier.
  /// C'est le serveur qui tranche, l'application ne fait qu'obéir.
  final bool peutModifier;

  /// Le texte affiché n'est pas celui qui a été publié.
  ///
  /// Sans ce marqueur, on pourrait réécrire un propos après qu'on y a répondu
  /// et faire dire à la conversation autre chose que ce qui s'y est passé.
  final bool modifie;

  /// Le message a été retiré : sa place reste, ses mots sont partis.
  final bool supprime;

  /// Retiré par quelqu'un d'autre que son auteur.
  ///
  /// WhatsApp ne fait pas la différence. Ici elle compte : quand le
  /// responsable d'un salon retire vos propos, vous devez pouvoir le
  /// constater. Son identité, elle, ne circule pas.
  final bool retireParUnTiers;

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
    this.peutModifier = false,
    this.modifie = false,
    this.supprime = false,
    this.retireParUnTiers = false,
  });

  /// Ce qui s'affiche à la place d'un message retiré.
  String get texteAffiche {
    if (!supprime) return contenu;
    return retireParUnTiers
        ? "Message retiré par la modération"
        : "Message retiré";
  }

  /// Le même message, retiré.
  ///
  /// Sert à refléter tout de suite un retrait accepté par le serveur, sans
  /// recharger tout le fil. Le contenu part avec — comme en base.
  Message retire() => Message(
    id: id,
    discussionId: discussionId,
    utilisateurId: utilisateurId,
    contenu: '',
    creeLe: creeLe,
    discussion: discussion,
    nomUtilisateur: nomUtilisateur,
    photoProfil: photoProfil,
    rangUtilisateur: rangUtilisateur,
    peutSupprimer: false,
    estAuteurDuLivre: estAuteurDuLivre,
    peutModifier: false,
    modifie: false,
    supprime: true,
    // Retiré depuis cet écran : c'est donc la personne connectée. Si elle
    // n'est pas l'auteur du propos, c'est un retrait par un tiers.
    retireParUnTiers: retireParUnTiers,
  );

  Message copyWith({String? contenu, bool? modifie}) => Message(
    id: id,
    discussionId: discussionId,
    utilisateurId: utilisateurId,
    contenu: contenu ?? this.contenu,
    creeLe: creeLe,
    discussion: discussion,
    nomUtilisateur: nomUtilisateur,
    photoProfil: photoProfil,
    rangUtilisateur: rangUtilisateur,
    peutSupprimer: peutSupprimer,
    estAuteurDuLivre: estAuteurDuLivre,
    peutModifier: peutModifier,
    modifie: modifie ?? this.modifie,
    supprime: supprime,
    retireParUnTiers: retireParUnTiers,
  );

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      discussionId: json['discussion_id'],
      utilisateurId: json['utilisateur_id'],
      // Un message retiré revient avec un contenu vide : c'est voulu, le texte
      // est réellement effacé de la base. `?? ''` évite le plantage sur null.
      contenu: json['contenu'] ?? '',
      creeLe: DateTime.parse(json['cree_le']),
      nomUtilisateur: json['nom_utilisateur'],
      photoProfil: json['photo_profil'],
      rangUtilisateur: json['rang_utilisateur'] ?? json['RangUtilisateur'],
      peutSupprimer: json['peut_supprimer'] == true,
      estAuteurDuLivre: json['est_auteur_du_livre'] == true,
      peutModifier: json['peut_modifier'] == true,
      modifie: json['modifie'] == true,
      supprime: json['supprime'] == true,
      retireParUnTiers: json['retire_par_un_tiers'] == true,
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
