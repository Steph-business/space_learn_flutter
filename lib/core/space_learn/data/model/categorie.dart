class Categorie {
  final String id;
  final String nom;
  final String statut;
  final DateTime creeLe;

  Categorie({
    required this.id,
    required this.nom,
    required this.statut,
    required this.creeLe,
  });

  factory Categorie.fromJson(Map<String, dynamic> json) {
    return Categorie(
      id: json['id'] ?? '',
      nom: json['nom'] ?? '',
      statut: json['statut'] ?? '',
      creeLe: json['cree_le'] != null
          ? DateTime.parse(json['cree_le'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nom': nom,
      'statut': statut,
      'cree_le': creeLe.toIso8601String(),
    };
  }
}
