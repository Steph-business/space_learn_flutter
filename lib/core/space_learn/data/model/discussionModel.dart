import 'book_model.dart';
import 'messageModel.dart';

class Discussion {
  final String id;
  final String? creePar;

  /// Nom de la personne qui a ouvert la discussion.
  ///
  /// Le serveur le renvoie depuis toujours dans `nom_utilisateur`, mais
  /// l'application ne le lisait pas : elle affichait les six premiers
  /// caractères de [creePar], c'est-à-dire un morceau d'identifiant — « @70f2c9 ».
  final String? nomUtilisateur;
  final String? type;

  /// Categorie du sujet, choisie a l'ouverture.
  ///
  /// Les onglets de la page de forum filtraient sur le TITRE : « Theories » ne
  /// retenait que les sujets dont le titre contenait litteralement ce mot.
  /// Trois onglets sur quatre ne renvoyaient donc jamais rien. La colonne
  /// existe cote serveur depuis toujours ; elle n'etait ni remplie ni lue.
  final String? categorie;

  final String? description;
  final String? imageBanniere;
  final String? auteurId;
  final String? livreId;
  final String titre;
  final DateTime? creeLe;
  final BookModel? livre;
  final List<Message> messages;
  final int? messagesCount;
  final int? likesCount;

  /// Ai-je aime ce sujet ?
  ///
  /// Sans cette information, le coeur ne peut etre que creux : l'application
  /// ne saurait pas distinguer « personne n'a aime » de « moi j'ai aime ».
  final bool aimeParMoi;
  final DateTime? dernierMessageLe;

  Discussion({
    required this.id,
    this.creePar,
    this.nomUtilisateur,
    this.type,
    this.categorie,
    this.description,
    this.imageBanniere,
    this.auteurId,
    this.livreId,
    required this.titre,
    this.creeLe,
    this.livre,
    this.messages = const [],
    this.messagesCount,
    this.likesCount,
    this.aimeParMoi = false,
    this.dernierMessageLe,
  });

  factory Discussion.fromJson(Map<String, dynamic> json) {
    int parseCount(dynamic data) {
      if (data == null) return 0;
      if (data is num) return data.toInt();
      if (data is String) return int.tryParse(data) ?? 0;
      if (data is List) return data.length;
      return 0;
    }

    final int calculatedCount = (() {
      final possibleKeys = [
        'nombre_messages',
        'NombreMessages',
        'nombreMessages',
        'messages_count',
        'messagesCount',
        'nbr_messages',
        'nb_messages',
        'nbrMessages',
        'nbMessages',
        'total_messages',
        'totalMessages',
        'count',
      ];
      for (final key in possibleKeys) {
        final val = parseCount(json[key]);
        if (val > 0) return val;
      }
      if (json['_count'] != null) {
        return parseCount(
          json['_count']['Messages'] ?? json['_count']['messages'],
        );
      }
      return parseCount(json['messages']);
    })();

    // Le serveur envoie « nombre_jaime ». Les quatre autres cles essayees
    // auparavant n'ont jamais existe : la valeur restait donc a zero, et le
    // coeur affiche avec elle ne bougeait jamais.
    final int calculatedLikes = parseCount(json['nombre_jaime']);

    final d = Discussion(
      id: json['id'] ?? '',
      creePar: json['cree_par'],
      nomUtilisateur: json['nom_utilisateur']?.toString(),
      type: json['type'],
      categorie: json['categorie']?.toString(),
      description: json['description'],
      imageBanniere: json['image_banniere'],
      auteurId: json['auteur_id'],
      livreId: json['livre_id'],
      titre: json['titre'] ?? '',
      creeLe: json['cree_le'] != null
          ? DateTime.tryParse(json['cree_le'])
          : null,
      livre: json['Livre'] != null ? BookModel.fromJson(json['Livre']) : null,
      messages: (json['Messages'] is List)
          ? List<Message>.from(json['Messages'].map((x) => Message.fromJson(x)))
          : (json['messages'] is List)
          ? List<Message>.from(
              (json['messages'] as List).map((x) => Message.fromJson(x)),
            )
          : [],
      messagesCount: calculatedCount,
      likesCount: calculatedLikes,
      aimeParMoi: json['aime_par_moi'] == true,
      dernierMessageLe: json['dernier_message_le'] != null
          ? DateTime.tryParse(json['dernier_message_le'])
          : null,
    );

    // Ensure messagesCount is at least messages.length
    if ((d.messagesCount == null || d.messagesCount == 0) &&
        d.messages.isNotEmpty) {
      return Discussion(
        id: d.id,
        creePar: d.creePar,
        type: d.type,
        description: d.description,
        imageBanniere: d.imageBanniere,
        auteurId: d.auteurId,
        livreId: d.livreId,
        titre: d.titre,
        creeLe: d.creeLe,
        livre: d.livre,
        messages: d.messages,
        messagesCount: d.messages.length,
        likesCount: d.likesCount,
        aimeParMoi: d.aimeParMoi,
        dernierMessageLe: d.dernierMessageLe,
      );
    }

    return d;
  }

  /// Le meme sujet, avec quelques champs changes.
  ///
  /// Recopier la liste des champs a chaque endroit qui modifie un sujet est un
  /// piege : le jour ou l'on ajoute un champ au modele, chaque copie oubliee
  /// le perd sans bruit. Ici, un seul endroit a tenir a jour.
  Discussion copyWith({int? likesCount, bool? aimeParMoi}) {
    return Discussion(
      id: id,
      creePar: creePar,
      nomUtilisateur: nomUtilisateur,
      type: type,
      categorie: categorie,
      description: description,
      imageBanniere: imageBanniere,
      auteurId: auteurId,
      livreId: livreId,
      titre: titre,
      creeLe: creeLe,
      livre: livre,
      messages: messages,
      messagesCount: messagesCount,
      likesCount: likesCount ?? this.likesCount,
      aimeParMoi: aimeParMoi ?? this.aimeParMoi,
      dernierMessageLe: dernierMessageLe,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'cree_par': creePar,
      'type': type,
      'description': description,
      'image_banniere': imageBanniere,
      'auteur_id': auteurId,
      'livre_id': livreId,
      'titre': titre,
      'cree_le': creeLe?.toIso8601String(),
      'Livre': livre?.toJson(),
      'Messages': messages.isNotEmpty
          ? messages.map((e) => e.toJson()).toList()
          : [],
      'messages_count': messagesCount,
      'likes_count': likesCount,
    };
  }
}
