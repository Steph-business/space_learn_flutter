class Evenement {
  final String id;
  final String typePublication;

  /// Nature de l'événement — « Séance de Dédicace », « Live Q&A »…
  /// Elle était envoyée dans typePublication, où la base la refusait.
  final String? categorie; // ANNONCE ou EVENEMENT
  final String titre;
  final String contenu;
  final String? imageUrl;
  final DateTime? dateEvenement;
  final String auteurId;
  final String? nomAuteur;
  final DateTime? creeLe;

  /// Lien de visioconférence optionnel (Google Meet, Zoom, Jitsi, YouTube Live…).
  /// Affiché sous forme de bouton « Rejoindre » sur la carte et la page de détail.
  final String? lienVisio;

  /// L'événement a déjà eu lieu.
  ///
  /// Calculé par le serveur, jamais stocké : une colonne serait fausse dès la
  /// minute suivante. Rien n'est masqué pour autant — un événement terminé
  /// reste consultable, il descend en bas de liste et le dit.
  ///
  /// Toujours faux pour une annonce, qui n'a pas de date : elle vieillit sans
  /// expirer.
  final bool passe;

  Evenement({
    required this.id,
    required this.typePublication,
    this.categorie,
    required this.titre,
    required this.contenu,
    this.imageUrl,
    this.dateEvenement,
    required this.auteurId,
    this.nomAuteur,
    this.creeLe,
    this.lienVisio,
    this.passe = false,
  });

  factory Evenement.fromJson(Map<String, dynamic> json) {
    return Evenement(
      id: json['id'] ?? '',
      typePublication: json['type_publication'] ?? 'ANNONCE',
      categorie: json['categorie']?.toString(),
      titre: json['titre'] ?? '',
      contenu: json['contenu'] ?? '',
      imageUrl: json['image_url'],
      dateEvenement: _instantLocal(json['date_evenement']),
      auteurId: json['auteur_id'] ?? '',
      nomAuteur:
          json['nom_auteur'] ?? json['auteur_nom'] ?? json['nom_complet'],
      creeLe: _instantLocal(json['cree_le']),
      lienVisio: (json['lien_visio'] as String?)?.trim().isEmpty == true
          ? null
          : json['lien_visio'] as String?,
      // Le serveur tranche. En repli — serveur plus ancien — on recalcule
      // localement plutôt que de tout afficher comme à venir.
      passe:
          json['passe'] == true ||
          _estPasse(_instantLocal(json['date_evenement'])),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type_publication': typePublication,
      'titre': titre,
      'contenu': contenu,
      'image_url': imageUrl,
      // En UTC explicite, comme ce que le service envoie au serveur.
      //
      // `toIso8601String()` sur une date locale ne porte AUCUN indicateur de
      // fuseau : relue par [_instantLocal] ou par le serveur, elle serait
      // prise pour de l'UTC et l'instant se décalerait à chaque aller-retour.
      // Le suffixe « Z » ferme la boucle.
      'date_evenement': dateEvenement?.toUtc().toIso8601String(),
      'auteur_id': auteurId,
      'nom_auteur': nomAuteur,
      'cree_le': creeLe?.toUtc().toIso8601String(),
      if (lienVisio != null && lienVisio!.isNotEmpty) 'lien_visio': lienVisio,
      'passe': passe,
    };
  }

  /// Une date reçue du serveur, ramenée à l'heure locale de l'appareil.
  ///
  /// Une date d'événement désigne un INSTANT, pas une heure murale : un
  /// rendez-vous fixé à 18 h à Douala doit se lire « 17 h » à Abidjan. C'est
  /// déjà la règle du site, qui convertit à la lecture ; le mobile la rejoint.
  ///
  /// La conversion vit ICI, au bord du modèle, et une seule fois. Si chaque
  /// écran la refaisait, il suffirait qu'un seul l'oublie — ou l'applique deux
  /// fois — pour que la même rencontre s'affiche à deux heures différentes
  /// selon l'endroit où on la regarde.
  ///
  /// Le serveur renvoie du RFC 3339 zoné : Go marshale toujours un `time.Time`
  /// avec son décalage, `DateTime.parse` en fait donc un instant UTC que
  /// `toLocal()` ramène chez le lecteur. Une chaîne SANS indicateur de fuseau
  /// — repli défensif, jamais produit par ce serveur — est lue comme de l'UTC,
  /// exactement comme le fait `parserDate` côté serveur : sans cette règle, la
  /// même chaîne désignerait un instant différent sur chaque téléphone.
  static DateTime? _instantLocal(dynamic brut) {
    if (brut == null) return null;
    final date = DateTime.tryParse(brut.toString());
    if (date == null) return null;
    if (date.isUtc) return date.toLocal();
    return DateTime.utc(
      date.year,
      date.month,
      date.day,
      date.hour,
      date.minute,
      date.second,
      date.millisecond,
      date.microsecond,
    ).toLocal();
  }

  /// Repli local : la journée entière compte, comme côté serveur. Un événement
  /// du matin reste « à venir » jusqu'au soir, sinon il disparaîtrait de la
  /// liste alors qu'il est en cours.
  ///
  /// La date arrive déjà ramenée en heure locale par [_instantLocal] : les
  /// deux termes de la comparaison appartiennent au même monde. Elle opposait
  /// auparavant une date lue telle quelle — donc en UTC dès que le serveur
  /// donnait un fuseau — à `DateTime.now()`, qui est local : la journée de
  /// grâce se décalait du décalage horaire de l'appareil, et une rencontre du
  /// soir passait pour terminée avant de l'être.
  static bool _estPasse(DateTime? date) {
    if (date == null) return false;
    final finDeJournee = DateTime(date.year, date.month, date.day + 1);
    return DateTime.now().isAfter(finDeJournee);
  }
}
