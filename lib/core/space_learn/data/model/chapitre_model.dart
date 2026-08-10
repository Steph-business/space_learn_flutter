class ChapitreModel {
  final String id;
  final String livreId;
  final int numero;
  final String titre;
  final String description;
  final bool estGratuit;

  /// Page du document ou commence le chapitre. 0 quand elle est
  /// inconnue : le chapitre reste affiche, mais n'ouvre pas le lecteur
  /// a un endroit precis.
  final int pageDepart;
  final DateTime? creeLe;

  ChapitreModel({
    required this.id,
    required this.livreId,
    required this.numero,
    required this.titre,
    this.description = '',
    this.estGratuit = false,
    this.pageDepart = 0,
    this.creeLe,
  });

  factory ChapitreModel.fromJson(Map<String, dynamic> json) {
    return ChapitreModel(
      id: (json['id'] ?? json['ID'] ?? '').toString(),
      livreId: (json['livre_id'] ?? json['LivreID'] ?? '').toString(),
      numero: (json['numero'] ?? json['Numero'] ?? 0) is int
          ? json['numero'] ?? json['Numero'] ?? 0
          : int.tryParse((json['numero'] ?? json['Numero'] ?? 0).toString()) ?? 0,
      titre: json['titre'] ?? json['Titre'] ?? '',
      description: json['description'] ?? json['Description'] ?? '',
      estGratuit: json['est_gratuit'] ?? json['EstGratuit'] ?? false,
      pageDepart: (json['page_depart'] ?? json['PageDepart'] ?? 0) is int
          ? json['page_depart'] ?? json['PageDepart'] ?? 0
          : int.tryParse((json['page_depart'] ?? 0).toString()) ?? 0,
      creeLe: json['cree_le'] != null ? DateTime.tryParse(json['cree_le']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'numero': numero,
      'titre': titre,
      'description': description,
      'est_gratuit': estGratuit,
      'page_depart': pageDepart,
    };
  }
}
