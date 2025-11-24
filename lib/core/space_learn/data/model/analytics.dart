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
      id: json['id'] as String,
      utilisateurId: json['utilisateur_id'] as String,
      periode: json['periode'] as String,
      revenusTotaux: (json['revenus_totaux'] as num).toDouble(),
      vuesTotales: json['vues_totales'] as int,
      telechargementsTotaux: json['telechargements_totaux'] as int,
      noteMoyenne: (json['note_moyenne'] as num).toDouble(),
      variationRevenus: (json['variation_revenus'] as num).toDouble(),
      variationVues: (json['variation_vues'] as num).toDouble(),
      variationTelechargements: (json['variation_telechargements'] as num).toDouble(),
      variationNote: (json['variation_note'] as num).toDouble(),
      creeLe: DateTime.parse(json['cree_le'] as String),
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
