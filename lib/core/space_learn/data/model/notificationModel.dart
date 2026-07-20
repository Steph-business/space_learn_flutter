class NotificationModel {
  final String id;
  final String utilisateurId;
  final String type;
  final String contenu;
  final bool lu;
  final DateTime? creeLe;
  final String? role; // 'auteur' or 'lecteur'
  final String? referenceId; // ID de l'objet associé (livre, discussion, etc.)
  final Map<String, dynamic>? data; // Données supplémentaires du backend

  NotificationModel({
    required this.id,
    required this.utilisateurId,
    required this.type,
    required this.contenu,
    required this.lu,
    this.creeLe,
    this.role,
    this.referenceId,
    this.data,
  });

  factory NotificationModel.fromJson(
    Map<String, dynamic> json, {
    String? role,
  }) {
    return NotificationModel(
      id: json['id'] ?? '',
      utilisateurId: json['utilisateur_id'] ?? '',
      type: json['type'] ?? '',
      contenu: json['contenu'] ?? '',
      lu: json['lu'] ?? false,
      creeLe: json['cree_le'] != null ? DateTime.parse(json['cree_le']) : null,
      role: role ?? json['role'],
      referenceId: json['reference_id'] ?? json['data_id'],
      data: json['data'] is Map<String, dynamic> ? json['data'] : null,
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
      if (referenceId != null) 'reference_id': referenceId,
    };
  }
}