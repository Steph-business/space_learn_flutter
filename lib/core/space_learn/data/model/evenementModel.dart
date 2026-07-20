class Evenement {
  final String id;
  final String typePublication; // ANNONCE ou EVENEMENT
  final String titre;
  final String contenu;
  final String? imageUrl;
  final DateTime? dateEvenement;
  final String auteurId;
  final DateTime? creeLe;

  Evenement({
    required this.id,
    required this.typePublication,
    required this.titre,
    required this.contenu,
    this.imageUrl,
    this.dateEvenement,
    required this.auteurId,
    this.creeLe,
  });

  factory Evenement.fromJson(Map<String, dynamic> json) {
    return Evenement(
      id: json['id'] ?? '',
      typePublication: json['type_publication'] ?? 'ANNONCE',
      titre: json['titre'] ?? '',
      contenu: json['contenu'] ?? '',
      imageUrl: json['image_url'],
      dateEvenement: json['date_evenement'] != null
          ? DateTime.tryParse(json['date_evenement'])
          : null,
      auteurId: json['auteur_id'] ?? '',
      creeLe: json['cree_le'] != null
          ? DateTime.tryParse(json['cree_le'])
          : null,
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
      'cree_le': creeLe?.toIso8601String(),
    };
  }
}