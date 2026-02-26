class RelationModel {
  final String id;
  final String utilisateurId; // utilisateur_id
  final String suitId; // suit_id
  final DateTime? creeLe;
  final String? nomComplet;
  final String? profilePhoto;

  RelationModel({
    required this.id,
    required this.utilisateurId,
    required this.suitId,
    this.creeLe,
    this.nomComplet,
    this.profilePhoto,
  });

  factory RelationModel.fromJson(Map<String, dynamic> json) {
    // Check for nested user data (common in Joins)
    final userData =
        json['Utilisateur'] ??
        json['utilisateur'] ??
        json['User'] ??
        json['user'];
    String? name = json['nom_complet'] ?? json['NomComplet'];
    String? photo = json['profile_photo'] ?? json['ProfilePhoto'];

    if (userData != null && userData is Map<String, dynamic>) {
      name ??=
          userData['nom_complet'] ??
          userData['NomComplet'] ??
          userData['name'] ??
          userData['full_name'];
      photo ??= userData['profile_photo'] ?? userData['ProfilePhoto'];
    }

    return RelationModel(
      id: json['id'] ?? (json['ID'] != null ? json['ID'].toString() : ''),
      utilisateurId: json['utilisateur_id'] ?? json['UtilisateurID'] ?? '',
      suitId: json['suit_id'] ?? json['SuitID'] ?? '',
      creeLe: json['cree_le'] != null ? DateTime.parse(json['cree_le']) : null,
      nomComplet: name,
      profilePhoto: photo,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'utilisateur_id': utilisateurId,
      'suit_id': suitId,
      'cree_le': creeLe?.toIso8601String(),
      'nom_complet': nomComplet,
      'profile_photo': profilePhoto,
    };
  }
}
