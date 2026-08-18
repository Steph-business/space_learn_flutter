class BadgeModel {
  final String id;
  final String utilisateurId;
  final DateTime? debloqueLe;
  final String name;
  final String description;
  final String iconUrl;
  final String code;

  /// Où en est le lecteur, et jusqu'où il doit aller.
  ///
  /// Un badge verrouillé ne disait rien de plus que « verrouillé ». Entre
  /// « 24 annotations sur 25 » et « 1 sur 25 », il y a pourtant toute la
  /// différence entre une soirée de lecture et un objectif lointain — et c'est
  /// cette différence qui donne envie d'ouvrir un livre ce soir.
  final int progression;
  final int cible;

  /// La famille du badge : assiduité, lecture, curiosité, communauté…
  final String famille;

  BadgeModel({
    required this.id,
    required this.utilisateurId,
    this.debloqueLe,
    required this.name,
    required this.description,
    required this.iconUrl,
    required this.code,
    this.progression = 0,
    this.cible = 0,
    this.famille = '',
  });

  bool get estDebloque => debloqueLe != null;

  /// La fraction parcourue, entre 0 et 1. Zéro quand le serveur ne dit rien.
  double get avancement {
    if (estDebloque) return 1;
    if (cible <= 0) return 0;
    final part = progression / cible;
    return part.clamp(0.0, 1.0);
  }

  factory BadgeModel.fromJson(Map<String, dynamic> json) {
    final badgeData = json['badge'] ?? {};
    return BadgeModel(
      id: json['id'] ?? '',
      utilisateurId: json['utilisateur_id'] ?? '',
      debloqueLe: json['debloque_le'] != null
          ? DateTime.tryParse(json['debloque_le'].toString())
          : null,
      name: badgeData['nom'] ?? '',
      description: badgeData['description'] ?? '',
      iconUrl: badgeData['icone_url'] ?? '',
      code: badgeData['code'] ?? '',
      progression: (json['progression'] as num?)?.toInt() ?? 0,
      cible: (json['cible'] as num?)?.toInt() ?? 0,
      famille: json['famille'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'utilisateur_id': utilisateurId,
      'debloque_le': debloqueLe?.toIso8601String(),
      'progression': progression,
      'cible': cible,
      'famille': famille,
      'badge': {
        'nom': name,
        'description': description,
        'icone_url': iconUrl,
        'code': code,
      },
    };
  }
}
