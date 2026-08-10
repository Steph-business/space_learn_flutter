class BadgeModel {
  final String id;
  final String utilisateurId;
  final DateTime? debloqueLe;
  final String name;
  final String description;
  final String iconUrl;
  final String code;

  BadgeModel({
    required this.id,
    required this.utilisateurId,
    this.debloqueLe,
    required this.name,
    required this.description,
    required this.iconUrl,
    required this.code,
  });

  factory BadgeModel.fromJson(Map<String, dynamic> json) {
    final badgeData = json['badge'] ?? {};
    return BadgeModel(
      id: json['id'] ?? '',
      utilisateurId: json['utilisateur_id'] ?? '',
      debloqueLe: json['debloque_le'] != null
          ? DateTime.parse(json['debloque_le'])
          : null,
      name: badgeData['nom'] ?? '',
      description: badgeData['description'] ?? '',
      iconUrl: badgeData['icone_url'] ?? '',
      code: badgeData['code'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'utilisateur_id': utilisateurId,
      'debloque_le': debloqueLe?.toIso8601String(),
      'badge': {
        'nom': name,
        'description': description,
        'icone_url': iconUrl,
        'code': code,
      },
    };
  }
}
