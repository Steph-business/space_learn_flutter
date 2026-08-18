class GoalModel {
  final String id;
  final String titre;
  final String description;
  final String type; // CHALLENGE, DAILY, etc.
  final int valeurCible;
  final int valeurActuelle;
  final bool estTermine;
  final DateTime? dateFin;

  GoalModel({
    required this.id,
    required this.titre,
    required this.description,
    required this.type,
    required this.valeurCible,
    required this.valeurActuelle,
    required this.estTermine,
    this.dateFin,
  });

  factory GoalModel.fromJson(Map<String, dynamic> json) {
    return GoalModel(
      // `code` d'abord : c'est la clé stable, partagée avec les objectifs
      // calculés localement. L'`id` est l'identifiant d'une ligne en base, qui
      // ne dit rien de la métrique mesurée — et un objectif calculé n'en a pas.
      id: (json['code'] is String && (json['code'] as String).isNotEmpty)
          ? json['code']
          : (json['id'] ?? ''),
      titre: json['titre'] ?? '',
      description: json['description'] ?? '',
      type: json['type'] ?? 'CHALLENGE',
      valeurCible: json['valeur_cible'] ?? 0,
      valeurActuelle: json['valeur_actuelle'] ?? 0,
      estTermine: json['est_termine'] ?? false,
      dateFin: json['date_fin'] != null
          ? DateTime.parse(json['date_fin'])
          : null,
    );
  }

  double get progress =>
      (valeurCible > 0) ? (valeurActuelle / valeurCible).clamp(0.0, 1.0) : 0.0;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'titre': titre,
      'description': description,
      'type': type,
      'valeur_cible': valeurCible,
      'valeur_actuelle': valeurActuelle,
      'est_termine': estTermine,
      'date_fin': dateFin?.toIso8601String(),
    };
  }
}
