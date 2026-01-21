class ProfilModel {
  final String id;
  final String libelle;

  ProfilModel({required this.id, required this.libelle});

  factory ProfilModel.fromJson(Map<String, dynamic> json) {
    return ProfilModel(
      id: json['id'],
      // On utilise trim() pour enlever les espaces superflus
      libelle: (json['libelle'] as String? ?? '').trim(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'libelle': libelle,
    };
  }
}
