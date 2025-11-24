/// Dart imports with relative correct path
import 'chapterModel.dart';

class BookModel {
  final String id;
  final String auteurId; // auteur_id
  final String titre;
  final String description;
  final String? imageCouverture;
  final String? fichierUrl;
  final String format; // PDF | EPUB | MOBI
  final double prix;
  final int stock;
  final String statut; // publie | brouillon | en_revision
  final String? adresseContratNft;
  final DateTime? creeLe;
  final DateTime? majLe;
  final List<ChapterModel>? chapitres;

  BookModel({
    required this.id,
    required this.auteurId,
    required this.titre,
    required this.description,
    this.imageCouverture,
    this.fichierUrl,
    required this.format,
    required this.prix,
    required this.stock,
    required this.statut,
    this.adresseContratNft,
    this.creeLe,
    this.majLe,
    this.chapitres,
  });

  factory BookModel.fromJson(Map<String, dynamic> json) {
    return BookModel(
      id: json['id'] ?? '',
      auteurId: json['auteur_id'] ?? '',
      titre: json['titre'] ?? '',
      description: json['description'] ?? '',
      imageCouverture: json['image_couverture'],
      fichierUrl: json['fichier_url'],
      format: json['format'] ?? '',
      prix: (json['prix'] ?? 0.0).toDouble(),
      stock: (json['stock'] ?? 0).toInt(),
      statut: json['statut'] ?? '',
      adresseContratNft: json['adresse_contrat_nft'],
      creeLe: json['cree_le'] != null ? DateTime.parse(json['cree_le']) : null,
      majLe: json['maj_le'] != null ? DateTime.parse(json['maj_le']) : null,
      chapitres: json['chapitres'] != null
          ? (json['chapitres'] as List)
              .map((e) => ChapterModel.fromJson(e))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'auteur_id': auteurId,
      'titre': titre,
      'description': description,
      'image_couverture': imageCouverture,
      'fichier_url': fichierUrl,
      'format': format,
      'prix': prix,
      'stock': stock,
      'statut': statut,
      'adresse_contrat_nft': adresseContratNft,
      'cree_le': creeLe?.toIso8601String(),
      'maj_le': majLe?.toIso8601String(),
      'chapitres': chapitres?.map((c) => c.toJson()).toList(),
    };
  }
}
