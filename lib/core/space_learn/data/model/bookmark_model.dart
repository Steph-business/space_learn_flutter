class BookmarkModel {
  final String id;
  final String utilisateurId;
  final String livreId;
  final int page;
  final int chapitre;
  final String? note;
  final DateTime? createdAt;

  BookmarkModel({
    required this.id,
    required this.utilisateurId,
    required this.livreId,
    required this.page,
    required this.chapitre,
    this.note,
    this.createdAt,
  });

  factory BookmarkModel.fromJson(Map<String, dynamic> json) {
    return BookmarkModel(
      id: json['id'] ?? '',
      utilisateurId: json['utilisateur_id'] ?? json['UtilisateurID'] ?? '',
      livreId: json['livre_id'] ?? json['LivreID'] ?? '',
      page: (json['page'] ?? 0).toInt(),
      chapitre: (json['chapitre'] ?? 0).toInt(),
      note: json['note'],
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
      'page': page,
      'chapitre': chapitre,
      if (note != null) 'note': note,
    };
  }
}
