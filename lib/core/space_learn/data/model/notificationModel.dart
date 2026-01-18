class NotificationModel {
  final String id;
  final String utilisateurId;
  final String type;
  final String contenu;
  final bool lu;
  final DateTime? creeLe;

  NotificationModel({
    required this.id,
    required this.utilisateurId,
    required this.type,
    required this.contenu,
    required this.lu,
    this.creeLe,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] ?? '',
      utilisateurId: json['utilisateur_id'] ?? '',
      type: json['type'] ?? '',
      contenu: json['contenu'] ?? '',
      lu: json['lu'] ?? false,
      creeLe: json['cree_le'] != null ? DateTime.parse(json['cree_le']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'utilisateur_id': utilisateurId,
      'type': type,
      'contenu': contenu,
      'lu': lu,
      'cree_le': creeLe?.toIso8601String(),
    };
  }
}
