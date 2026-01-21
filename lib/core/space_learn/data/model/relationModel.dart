class RelationModel {
  final String id;
  final String utilisateurId; // utilisateur_id
  final String suitId; // suit_id
  final DateTime? creeLe;

  RelationModel({
    required this.id,
    required this.utilisateurId,
    required this.suitId,
    this.creeLe,
  });

  factory RelationModel.fromJson(Map<String, dynamic> json) {
    return RelationModel(
      id: json['id'] ?? '',
      utilisateurId: json['utilisateur_id'] ?? '',
      suitId: json['suit_id'] ?? '',
      creeLe: json['cree_le'] != null ? DateTime.parse(json['cree_le']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'utilisateur_id': utilisateurId,
      'suit_id': suitId,
      'cree_le': creeLe?.toIso8601String(),
    };
  }
}
