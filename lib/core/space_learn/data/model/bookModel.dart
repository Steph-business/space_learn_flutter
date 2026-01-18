import 'categorie.dart';
import 'activiteModel.dart';
import 'readingActivityModel.dart';
import 'recommendationModel.dart';

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
  final String? categorieId; // categorie_id
  final String statut; // publie | brouillon | en_revision
  final String? adresseContratNft;
  final DateTime? creeLe;
  final DateTime? majLe;

  // Relations
  final Categorie? categorie; // Categorie
  final List<ReviewModel>? activites; // Activites
  final List<ReadingActivityModel>? progressions; // Progressions
  final List<RecommendationModel>? recommandations; // Recommandations

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
    this.categorieId,
    required this.statut,
    this.adresseContratNft,
    this.creeLe,
    this.majLe,
    this.categorie,
    this.activites,
    this.progressions,
    this.recommandations,
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
      categorieId: json['categorie_id'],
      statut: json['statut'] ?? '',
      adresseContratNft: json['adresse_contrat_nft'],
      creeLe: json['cree_le'] != null ? DateTime.parse(json['cree_le']) : null,
      majLe: json['maj_le'] != null ? DateTime.parse(json['maj_le']) : null,
      categorie: json['Categorie'] != null
          ? Categorie.fromJson(json['Categorie'])
          : null,
      activites: json['Activites'] != null
          ? (json['Activites'] as List)
                .map((i) => ReviewModel.fromJson(i))
                .toList()
          : null,
      progressions: json['Progressions'] != null
          ? (json['Progressions'] as List)
                .map((i) => ReadingActivityModel.fromJson(i))
                .toList()
          : null,
      recommandations: json['Recommandations'] != null
          ? (json['Recommandations'] as List)
                .map((i) => RecommendationModel.fromJson(i))
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
      'categorie_id': categorieId,
      'statut': statut,
      'adresse_contrat_nft': adresseContratNft,
      'cree_le': creeLe?.toIso8601String(),
      'maj_le': majLe?.toIso8601String(),
      'Categorie': categorie?.toJson(),
      'Activites': activites?.map((i) => i.toJson()).toList(),
      'Progressions': progressions?.map((i) => i.toJson()).toList(),
      'Recommandations': recommandations?.map((i) => i.toJson()).toList(),
    };
  }
}
