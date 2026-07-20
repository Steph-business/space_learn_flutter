class CitationModel {
  final String id;
  final String texte;
  final String auteur;
  final String? livreTitre;

  CitationModel({
    required this.id,
    required this.texte,
    required this.auteur,
    this.livreTitre,
  });

  factory CitationModel.fromJson(Map<String, dynamic> json) {
    return CitationModel(
      id: json['id'] ?? '',
      texte: json['texte'] ?? '',
      auteur: json['auteur'] ?? '',
      livreTitre: json['livre_titre'],
    );
  }
}