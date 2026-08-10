class BookmarkModel {
  final String id;
  final String utilisateurId;
  final String livreId;
  final int pageNumber;
  final String? label;
  final DateTime? createdAt;
  final int? chapitre; // Keeping for compatibility if needed

  BookmarkModel({
    required this.id,
    required this.utilisateurId,
    required this.livreId,
    required this.pageNumber,
    this.label,
    this.createdAt,
    this.chapitre,
  });

  factory BookmarkModel.fromJson(Map<String, dynamic> json) {
    return BookmarkModel(
      id: json['id'] ?? '',
      utilisateurId: json['utilisateur_id'] ?? json['UtilisateurID'] ?? '',
      livreId: json['livre_id'] ?? json['LivreID'] ?? '',
      pageNumber: (json['page_number'] ?? json['page'] ?? 0).toInt(),
      label: json['label'] ?? json['note'],
      chapitre: (json['chapitre'] ?? 0).toInt(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : (json['CreatedAt'] != null
                ? DateTime.parse(json['CreatedAt'])
                : null),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'livre_id': livreId,
      'page_number': pageNumber,
      if (label != null) 'label': label,
      if (chapitre != null) 'chapitre': chapitre,
    };
  }
}
