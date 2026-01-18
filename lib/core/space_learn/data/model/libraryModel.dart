import 'bookModel.dart';

class LibraryModel {
  final String id;
  final String utilisateurId; // utilisateur_id
  final String livreId; // livre_id
  final String acquisVia;
  final DateTime? creeLe;
  final BookModel? livre;

  LibraryModel({
    required this.id,
    required this.utilisateurId,
    required this.livreId,
    required this.acquisVia,
    this.creeLe,
    this.livre,
  });

  factory LibraryModel.fromJson(Map<String, dynamic> json) {
    return LibraryModel(
      id: json['id'] ?? '',
      utilisateurId: json['utilisateur_id'] ?? '',
      livreId: json['livre_id'] ?? '',
      acquisVia: json['acquis_via'] ?? '',
      creeLe: json['cree_le'] != null ? DateTime.parse(json['cree_le']) : null,
      livre: json['Livre'] != null ? BookModel.fromJson(json['Livre']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'utilisateur_id': utilisateurId,
      'livre_id': livreId,
      'acquis_via': acquisVia,
      'cree_le': creeLe?.toIso8601String(),
      'Livre': livre?.toJson(),
    };
  }
}
