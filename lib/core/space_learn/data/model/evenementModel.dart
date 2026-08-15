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
  });

  factory Evenement.fromJson(Map<String, dynamic> json) {
    return Evenement(
      id: json['id'] ?? '',
      typePublication: json['type_publication'] ?? 'ANNONCE',
      categorie: json['categorie']?.toString(),
      titre: json['titre'] ?? '',
      contenu: json['contenu'] ?? '',
      imageUrl: json['image_url'],
      dateEvenement: json['date_evenement'] != null
          ? DateTime.tryParse(json['date_evenement'])
          : null,
      auteurId: json['auteur_id'] ?? '',
      nomAuteur: json['nom_auteur'] ?? json['auteur_nom'] ?? json['nom_complet'],
      creeLe: json['cree_le'] != null
          ? DateTime.tryParse(json['cree_le'])
          : null,
      lienVisio: (json['lien_visio'] as String?)?.trim().isEmpty == true
          ? null
          : json['lien_visio'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type_publication': typePublication,
      'titre': titre,
      'contenu': contenu,
      'image_url': imageUrl,
      'date_evenement': dateEvenement?.toIso8601String(),
      'auteur_id': auteurId,
      'nom_auteur': nomAuteur,
      'cree_le': creeLe?.toIso8601String(),
      if (lienVisio != null && lienVisio!.isNotEmpty) 'lien_visio': lienVisio,
    };
  }
}
