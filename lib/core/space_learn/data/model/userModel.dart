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
    return UserModel(
      id: json['ID'] ?? '',
      profilId: json['ProfilID'] ?? '',
      nomComplet: json['NomComplet'] ?? '',
      email: json['Email'] ?? '',
      biography: json['Biography'],
      profilePhoto: json['ProfilePhoto'],
      socialLinks: json['SocialLinks'],
      walletAddress: json['WalletAddress'],
      isProfileComplete: json['IsProfileComplete'] ?? false,
      createdAt: json['CreatedAt'] != null
          ? DateTime.parse(json['CreatedAt'])
          : null,
      updatedAt: json['UpdatedAt'] != null
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
