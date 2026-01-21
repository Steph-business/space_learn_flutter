class Analytics {
  final String id;
  final String utilisateurId;
  final String periode;
  final double revenusTotaux;
  final int vuesTotales;
  final int telechargementsTotaux;
  final double noteMoyenne;
  final double variationRevenus;
  final double variationVues;
  final double variationTelechargements;
  final double variationNote;
  final DateTime creeLe;

  Analytics({
    required this.id,
    required this.utilisateurId,
    required this.periode,
    required this.revenusTotaux,
    required this.vuesTotales,
    required this.telechargementsTotaux,
    required this.noteMoyenne,
    required this.variationRevenus,
    required this.variationVues,
    required this.variationTelechargements,
    required this.variationNote,
    required this.creeLe,
  });

  factory Analytics.fromJson(Map<String, dynamic> json) {
    return Analytics(
      id: json['id'] ?? '',
      utilisateurId: json['utilisateur_id'] ?? '',
      periode: json['periode'] ?? '',
      revenusTotaux: (json['revenus_totaux'] ?? 0.0).toDouble(),
      vuesTotales: (json['vues_totales'] ?? 0).toInt(),
      telechargementsTotaux: (json['telechargements_totaux'] ?? 0).toInt(),
      noteMoyenne: (json['note_moyenne'] ?? 0.0).toDouble(),
      variationRevenus: (json['variation_revenus'] ?? 0.0).toDouble(),
      variationVues: (json['variation_vues'] ?? 0.0).toDouble(),
      variationTelechargements: (json['variation_telechargements'] ?? 0.0)
          .toDouble(),
      variationNote: (json['variation_note'] ?? 0.0).toDouble(),
      creeLe: json['cree_le'] != null
          ? DateTime.parse(json['cree_le'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'utilisateur_id': utilisateurId,
      'periode': periode,
      'revenus_totaux': revenusTotaux,
      'vues_totales': vuesTotales,
      'telechargements_totaux': telechargementsTotaux,
      'note_moyenne': noteMoyenne,
      'variation_revenus': variationRevenus,
      'variation_vues': variationVues,
      'variation_telechargements': variationTelechargements,
      'variation_note': variationNote,
      'cree_le': creeLe.toIso8601String(),
    };
  }
}
