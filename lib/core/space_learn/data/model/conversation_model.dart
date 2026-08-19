import '../../../utils/api_routes.dart';

/// La messagerie privée, côté lecture.
///
/// Ces modèles sont volontairement tolérants : une réponse à laquelle il
/// manque un champ doit se lire quand même. Le forum a montré ce qui arrive
/// sinon — `DateTime.parse(json['cree_le'])` sur un champ absent lève, et la
/// liste ENTIÈRE devient un écran d'erreur pour un seul élément mal formé.
/// Ici, un champ manquant coûte ce champ-là, jamais la conversation.

/// Le texte d'un champ, ou rien.
///
/// Une chaîne vide vaut une absence : le serveur renvoie parfois `""` là où
/// l'on attendait `null`, et « afficher la chaîne vide » n'est pas une réponse.
String? _texte(dynamic valeur) {
  if (valeur == null) return null;
  final t = valeur.toString().trim();
  return t.isEmpty ? null : t;
}

/// Une date, à l'heure du téléphone.
///
/// `tryParse` et non `parse` : une date illisible fait perdre l'horodatage,
/// pas le message. `toLocal` parce que le serveur horodate en UTC et que
/// l'heure affichée doit être celle de la personne qui lit.
DateTime? _date(dynamic valeur) {
  final t = _texte(valeur);
  if (t == null) return null;
  return DateTime.tryParse(t)?.toLocal();
}

/// Un entier, quelle que soit la forme sous laquelle il arrive.
///
/// JSON transporte volontiers un compteur en nombre à virgule ou en chaîne.
int _entier(dynamic valeur) {
  if (valeur is int) return valeur;
  if (valeur is num) return valeur.toInt();
  final t = _texte(valeur);
  if (t == null) return 0;
  return int.tryParse(t) ?? 0;
}

/// Un booléen transmis par le serveur, ou rien s'il ne l'a pas transmis.
///
/// Distinguer « le serveur a dit non » de « le serveur n'a rien dit » est tout
/// l'intérêt : dans le second cas seulement, on a le droit de se rabattre sur
/// une autre source.
bool? _booleen(dynamic valeur) {
  if (valeur is bool) return valeur;
  final t = _texte(valeur)?.toLowerCase();
  if (t == 'true') return true;
  if (t == 'false') return false;
  return null;
}

/// Une carte JSON, ou une carte vide.
Map<String, dynamic> _carte(dynamic valeur) {
  if (valeur is Map) return Map<String, dynamic>.from(valeur);
  return const <String, dynamic>{};
}

const List<String> _joursDeLaSemaine = [
  'Lundi',
  'Mardi',
  'Mercredi',
  'Jeudi',
  'Vendredi',
  'Samedi',
  'Dimanche',
];

/// L'heure telle qu'elle s'affiche à côté d'un message.
///
/// Aujourd'hui, l'heure ; hier, « Hier » ; dans la semaine, le jour ; au-delà,
/// la date. La règle vit ici, en un seul endroit, et non recopiée dans la
/// liste et dans le fil : `tempsRelatif` a déjà montré ce que coûtent deux
/// copies d'une même règle qui finissent par diverger.
///
/// Une date à venir se lit comme maintenant : l'horloge d'un téléphone et
/// celle d'un serveur ne sont jamais tout à fait d'accord.
String heureCourte(DateTime date, {DateTime? maintenant}) {
  final reference = maintenant ?? DateTime.now();
  final d = date.toLocal();

  final jourDuMessage = DateTime(d.year, d.month, d.day);
  final aujourdHui = DateTime(reference.year, reference.month, reference.day);
  final ecart = aujourdHui.difference(jourDuMessage).inDays;

  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');

  if (ecart <= 0) return '$hh:$mm';
  if (ecart == 1) return 'Hier';
  if (ecart < 7) return _joursDeLaSemaine[d.weekday - 1];

  final jj = d.day.toString().padLeft(2, '0');
  final mois = d.month.toString().padLeft(2, '0');
  return '$jj/$mois/${d.year}';
}

/// La personne d'en face.
class Correspondant {
  final String id;
  final String nom;
  final String? photo;

  const Correspondant({required this.id, required this.nom, this.photo});

  /// Ce qui s'affiche quand le nom n'est pas venu.
  ///
  /// Une ligne sans nom se lit comme une conversation vide ; « Utilisateur »
  /// dit au moins qu'il y a bien quelqu'un.
  String get nomAffiche => nom.isEmpty ? "Utilisateur" : nom;

  /// L'adresse de la photo, remise sur le serveur courant.
  ///
  /// Les photos de profil viennent du service d'authentification : c'est la
  /// base par défaut de [ApiRoutes.sanitizeImageUrl], comme pour `user_model`.
  String? get photoUrl => ApiRoutes.sanitizeImageUrl(photo);

  factory Correspondant.fromJson(Map<String, dynamic> json) {
    return Correspondant(
      id: _texte(json['id']) ?? '',
      nom: _texte(json['nom']) ?? '',
      photo: _texte(json['photo']),
    );
  }
}

/// Le dernier mot échangé, tel qu'il apparaît dans la liste.
///
/// Ce n'est pas un [MessagePrive] : la liste des conversations n'en transporte
/// que l'extrait, sans identifiant ni statut de lecture. Un modèle distinct
/// évite d'avoir à inventer un `id` pour tenir dans le mauvais moule.
class ApercuMessage {
  final String contenu;
  final DateTime? creeLe;

  /// Ce dernier message est-il le mien ?
  ///
  /// Sert à préfixer l'extrait par « Vous : » — sans quoi on ne sait pas si
  /// l'on attend une réponse ou si l'on en doit une.
  final bool deMoi;

  const ApercuMessage({required this.contenu, this.creeLe, this.deMoi = false});

  factory ApercuMessage.fromJson(Map<String, dynamic> json) {
    return ApercuMessage(
      contenu: _texte(json['contenu']) ?? '',
      creeLe: _date(json['cree_le']),
      deMoi: _booleen(json['de_moi']) ?? false,
    );
  }
}

/// Une conversation à deux.
class Conversation {
  final String id;
  final Correspondant correspondant;

  /// Nul tant que personne n'a écrit : une conversation peut exister sans
  /// message, puisque le serveur la crée à l'ouverture.
  final ApercuMessage? dernierMessage;

  final int nonLus;

  const Conversation({
    required this.id,
    required this.correspondant,
    this.dernierMessage,
    this.nonLus = 0,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    final brutDernier = json['dernier_message'];
    return Conversation(
      id: _texte(json['id']) ?? '',
      correspondant: Correspondant.fromJson(_carte(json['correspondant'])),
      // `null` est une valeur légitime ici, pas une anomalie : c'est une
      // conversation ouverte que personne n'a encore alimentée.
      dernierMessage: brutDernier is Map
          ? ApercuMessage.fromJson(_carte(brutDernier))
          : null,
      nonLus: _entier(json['non_lus']),
    );
  }

  /// La même conversation, avec un dernier message et sans non-lus.
  ///
  /// Sert au retour de l'écran de conversation : on vient de lire le fil et
  /// d'y écrire, la ligne de la liste doit le refléter sans attendre un
  /// rechargement complet.
  Conversation copyWith({ApercuMessage? dernierMessage, int? nonLus}) =>
      Conversation(
        id: id,
        correspondant: correspondant,
        dernierMessage: dernierMessage ?? this.dernierMessage,
        nonLus: nonLus ?? this.nonLus,
      );
}

/// Un message dans le fil d'une conversation.
class MessagePrive {
  final String id;
  final String expediteurId;
  final String contenu;
  final bool lu;
  final DateTime? creeLe;

  /// De quel côté la bulle se range.
  ///
  /// Le serveur le calcule et l'envoie : lui seul connaît avec certitude
  /// l'identité derrière le jeton. Quand il ne l'a pas envoyé — réponse
  /// partielle, ancienne version — on se rabat sur la comparaison avec
  /// l'identifiant du compte connecté ; à défaut de celui-ci, la bulle part à
  /// gauche. Se tromper de côté est moins grave qu'attribuer un propos à
  /// quelqu'un d'autre.
  final bool deMoi;

  const MessagePrive({
    required this.id,
    required this.expediteurId,
    required this.contenu,
    this.lu = false,
    this.creeLe,
    this.deMoi = false,
  });

  factory MessagePrive.fromJson(Map<String, dynamic> json, {String? moiId}) {
    final expediteurId = _texte(json['expediteur_id']) ?? '';
    final duServeur = _booleen(json['de_moi']);

    return MessagePrive(
      id: _texte(json['id']) ?? '',
      expediteurId: expediteurId,
      contenu: _texte(json['contenu']) ?? '',
      lu: _booleen(json['lu']) ?? false,
      creeLe: _date(json['cree_le']),
      deMoi:
          duServeur ??
          (moiId != null && moiId.isNotEmpty && expediteurId == moiId),
    );
  }
}
