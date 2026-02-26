import 'book_model.dart';

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
      // Injection du nom de l'auteur provenant de la jointure (nom_auteur)
      final joinName =
          json['nom_auteur'] ?? json['NomAuteur'] ?? json['auteur_nom'];
      if (joinName != null &&
          (bookJson['nom_auteur'] == null ||
              bookJson['nom_auteur'].toString().isEmpty)) {
        bookJson['nom_auteur'] = joinName;
      }
      book = BookModel.fromJson(bookJson);
    }

    return LibraryModel(
      id: json['id'] ?? '',
      utilisateurId: json['utilisateur_id'] ?? '',
      livreId: json['livre_id'] ?? '',
      acquisVia: json['acquis_via'] ?? '',
      auteurNom: json['nom_auteur'] ?? json['NomAuteur'] ?? json['auteur_nom'],
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
