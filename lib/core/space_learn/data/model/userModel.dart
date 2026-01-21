class UserModel {
  final String id;
  final String profilId;
  final String nomComplet;
  final String email;
  final String? biography;
  final String? profilePhoto;
  final String? socialLinks;
  final String? walletAddress;
  final bool isProfileComplete;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  UserModel({
    required this.id,
    required this.profilId,
    required this.email,
    required this.nomComplet,
    this.biography,
    this.profilePhoto,
    this.socialLinks,
    this.walletAddress,
    required this.isProfileComplete,
    this.createdAt,
    this.updatedAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    String name = json['nom_complet'] ?? json['NomComplet'] ?? json['name'] ?? json['full_name'] ?? '';
    if (name.isEmpty) {
      name = json['email'] ?? json['Email'] ?? '';
    }

    return UserModel(
      id: json['id'] ?? json['ID'] ?? '',
      profilId: json['profil_id'] ?? json['ProfilID'] ?? '',
      nomComplet: name,
      email: json['email'] ?? json['Email'] ?? '',
      biography: json['biography'] ?? json['Biography'],
      profilePhoto: json['profile_photo'] ?? json['ProfilePhoto'],
      socialLinks: json['social_links'] ?? json['SocialLinks'],
      walletAddress: json['wallet_address'] ?? json['WalletAddress'],
      isProfileComplete:
          json['is_profile_complete'] ?? json['IsProfileComplete'] ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : json['CreatedAt'] != null
          ? DateTime.parse(json['CreatedAt'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : json['UpdatedAt'] != null
          ? DateTime.parse(json['UpdatedAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ID': id,
      'ProfilID': profilId,
      'NomComplet': nomComplet,
      'email': email,
      'Biography': biography,
      'ProfilePhoto': profilePhoto,
      'SocialLinks': socialLinks,
      'WalletAddress': walletAddress,
      'IsProfileComplete': isProfileComplete,
      if (createdAt != null) 'CreatedAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'UpdatedAt': updatedAt!.toIso8601String(),
    };
  }
}
