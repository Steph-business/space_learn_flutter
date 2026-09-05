import 'discussionModel.dart';

/// Le texte d'un champ, ou rien.
///
/// Même forme que dans `conversation_model` et `reversement_model` : une
/// chaîne vide vaut une absence, le serveur renvoyant parfois `""` là où l'on
/// attendait `null`. Passer par `toString()` protège aussi du cas où un
/// identifiant arriverait en nombre : l'affectation directe à un `String`
/// levait alors, et c'est tout le fil qui disparaissait pour un seul message.
String? _texte(dynamic valeur) {
  if (valeur == null) return null;
  final t = valeur.toString().trim();
  return t.isEmpty ? null : t;
}

/// Une date, ou rien.
///
/// `tryParse` et non `parse` : la lecture d'une date illisible ne doit plus
/// lever. Ce qu'on en fait ensuite se décide dans [Message.fromJson], et non
/// ici.
DateTime? _date(dynamic valeur) {
  final t = _texte(valeur);
  if (t == null) return null;
  return DateTime.tryParse(t);
}

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

  /// Lit un message, sans faire tomber les autres avec lui.
  ///
  /// Avant, `id`, `discussion_id`, `utilisateur_id` et `cree_le` étaient lus
  /// sans repli, et `DateTime.parse` est stricte : un seul élément mal formé
  /// dans la réponse faisait échouer la conversion de TOUTE la liste, et le
  /// forum entier s'affichait en panne pour un message abîmé. Aucun
  /// déclencheur connu — le serveur envoie ces quatre champs depuis toujours —
  /// c'est une assurance, pas une réparation.
  ///
  /// Tolérer une donnée imparfaite n'est pas inventer du contenu : un message
  /// sans identifiant ni date n'est pas un message abîmé, c'est une ligne
  /// creuse qui s'afficherait comme un vrai propos. Sans identifiant on ne
  /// pourrait ni le retirer ni le réécrire ; sans date il n'a pas de place
  /// dans le fil. Ces deux-là sont donc refusés ici, explicitement, pour que
  /// la boucle de lecture les SAUTE — les autres messages, eux, s'affichent.
  factory Message.fromJson(Map<String, dynamic> json) {
    final id = _texte(json['id']);
    final creeLe = _date(json['cree_le']);
    if (id == null || creeLe == null) {
      throw const FormatException(
        'Message sans identifiant ou sans date lisible',
      );
    }

    final brutDiscussion = json['Discussion'];

    return Message(
      id: id,
      // Le reste se contente d'un repli : il manquerait l'un de ces champs que
      // le message resterait lisible à l'écran, et un message lisible vaut
      // mieux qu'un fil en panne.
      discussionId: _texte(json['discussion_id']) ?? '',
      utilisateurId: _texte(json['utilisateur_id']) ?? '',
      // Un message retiré revient avec un contenu vide : c'est voulu, le texte
      // est réellement effacé de la base. `?? ''` évite le plantage sur null.
      contenu: _texte(json['contenu']) ?? '',
      creeLe: creeLe,
      nomUtilisateur: _texte(json['nom_utilisateur']),
      photoProfil: _texte(json['photo_profil']),
      rangUtilisateur:
          _texte(json['rang_utilisateur']) ?? _texte(json['RangUtilisateur']),
      peutSupprimer: json['peut_supprimer'] == true,
      estAuteurDuLivre: json['est_auteur_du_livre'] == true,
      peutModifier: json['peut_modifier'] == true,
      modifie: json['modifie'] == true,
      supprime: json['supprime'] == true,
      retireParUnTiers: json['retire_par_un_tiers'] == true,
      // `is Map` et non `!= null` : un salon transporté sous une autre forme
      // que la sienne coûte le salon joint, jamais le message.
      discussion: brutDiscussion is Map
          ? Discussion.fromJson(Map<String, dynamic>.from(brutDiscussion))
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
