import 'bookModel.dart';

class LibraryModel {
  final String id;
  final String utilisateurId; // utilisateur_id
  final String livreId; // livre_id
  final String acquisVia;
  final String? auteurNom; // auteur_nom (provenant de la jointure)
  final DateTime? creeLe;
  final BookModel? livre;

  LibraryModel({
    required this.id,
    required this.utilisateurId,
    required this.livreId,
    required this.acquisVia,
    this.auteurNom,
    this.creeLe,
    this.livre,
  });

  factory LibraryModel.fromJson(Map<String, dynamic> json) {
    print("🔍 LibraryModel.fromJson keys: ${json.keys.toList()}");

    // Extraction du livre
    Map<String, dynamic>? bookJson =
        json['Livre'] ?? json['livre'] ?? json['Book'] ?? json['book'];

    BookModel? book;
    if (bookJson != null) {
      // Si on a un auteur_nom à la racine, on l'injecte dans le JSON du livre
      // pour que BookModel.fromJson puisse le récupérer.
      if (json['auteur_nom'] != null && bookJson['auteur_nom'] == null) {
        bookJson['auteur_nom'] = json['auteur_nom'];
      }
      book = BookModel.fromJson(bookJson);
    }

    return LibraryModel(
      id: json['id'] ?? '',
      utilisateurId: json['utilisateur_id'] ?? '',
      livreId: json['livre_id'] ?? '',
      acquisVia: json['acquis_via'] ?? '',
      auteurNom: json['auteur_nom'],
      creeLe: json['cree_le'] != null ? DateTime.parse(json['cree_le']) : null,
      livre: book,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'utilisateur_id': utilisateurId,
      'livre_id': livreId,
      'acquis_via': acquisVia,
      'auteur_nom': auteurNom,
      'cree_le': creeLe?.toIso8601String(),
      'Livre': livre?.toJson(),
    };
  }
}
