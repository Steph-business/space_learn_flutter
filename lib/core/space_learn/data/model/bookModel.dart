import 'categorie.dart';
import 'activiteModel.dart';
import 'readingActivityModel.dart';
import 'recommendationModel.dart';
import 'userModel.dart';
import '../../../utils/api_routes.dart';

class BookModel {
  final String id;
  final String auteurId; // auteur_id
  final String titre;
  final String description;
  final String? imageCouverture;
  final String? fichierUrl;
  final String format; // PDF | EPUB | MOBI
  final int prix;
  final int stock;
  final String? categorieId; // categorie_id
  final String statut; // publie | brouillon | en_revision
  final String? adresseContratNft;
  final DateTime? creeLe;
  final DateTime? majLe;

  // Stats
  final double noteMoyenne;
  final int telechargements;

  // Relations
  final Categorie? categorie; // Categorie
  final List<ReviewModel>? activites; // Activites
  final List<ReadingActivityModel>? progressions; // Progressions
  final List<RecommendationModel>? recommandations; // Recommandations
  final UserModel? auteur; // Auteur

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
    this.auteur,
    double? noteMoyenne,
    int? telechargements,
  }) : noteMoyenne = noteMoyenne ?? 0.0,
       telechargements = telechargements ?? 0;

  factory BookModel.fromJson(Map<String, dynamic> json) {
    // Handle author extraction
    UserModel? author;
    final authorData =
        json['Auteur'] ??
        json['auteur'] ??
        json['author'] ??
        json['Utilisateur'];

    if (authorData != null) {
      if (authorData is Map<String, dynamic>) {
        try {
          author = UserModel.fromJson(authorData);
        } catch (e) {
          // Fallback if full parsing fails but we have the name
          final name = authorData['nom_complet'] ?? authorData['NomComplet'];
          if (name != null) {
            author = UserModel(
              id: authorData['id'] ?? '',
              profilId: authorData['profil_id'] ?? '',
              email: authorData['email'] ?? '',
              nomComplet: name,
              isProfileComplete: false,
            );
          }
        }
      } else if (authorData is String) {
        // If it's just a string, create a dummy UserModel with that name
        author = UserModel(
          id: '',
          profilId: '',
          email: '',
          nomComplet: authorData,
          isProfileComplete: false,
        );
      }
    } else {
      // Fallback: check for top-level name fields
      final nameFallback =
          json['auteur_nom'] ??
          json['author_name'] ??
          json['NomComplet'] ??
          json['nom_complet'];
      if (nameFallback != null && nameFallback is String) {
        author = UserModel(
          id: '',
          profilId: '',
          email: '',
          nomComplet: nameFallback,
          isProfileComplete: false,
        );
      }
    }

    return BookModel(
      id: json['id'] ?? '',
      auteurId: json['auteur_id'] ?? json['author_id'] ?? '',
      titre: json['titre'] ?? json['title'] ?? '',
      description: json['description'] ?? '',
      imageCouverture: _sanitizeImageUrl(
        json['image_couverture'],
        useGin: true,
      ),
      fichierUrl: _sanitizeImageUrl(json['fichier_url'], useGin: true),
      format: json['format'] ?? '',
      prix: (json['prix'] ?? json['price'] ?? 0).toInt(),
      stock: (json['stock'] ?? 0).toInt(),
      categorieId: json['categorie_id'],
      statut: json['statut'] ?? '',
      adresseContratNft: json['adresse_contrat_nft'],
      creeLe: json['cree_le'] != null ? DateTime.parse(json['cree_le']) : null,
      majLe: json['maj_le'] != null ? DateTime.parse(json['maj_le']) : null,
      noteMoyenne: (json['note_moyenne'] != null)
          ? (json['note_moyenne'] as num).toDouble()
          : 0.0,
      telechargements: (json['telechargements'] != null)
          ? (json['telechargements'] as num).toInt()
          : 0,
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
      auteur: author,
    );
  }

  static String? _sanitizeImageUrl(String? url, {bool useGin = false}) {
    return ApiRoutes.sanitizeImageUrl(url, useGin: useGin);
  }

  String get authorName => auteur?.nomComplet ?? 'Auteur inconnu';

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
      'note_moyenne': noteMoyenne,
      'telechargements': telechargements,
      'Categorie': categorie?.toJson(),
      'Activites': activites?.map((i) => i.toJson()).toList(),
      'Progressions': progressions?.map((i) => i.toJson()).toList(),
      'Recommandations': recommandations?.map((i) => i.toJson()).toList(),
      'Auteur': auteur?.toJson(),
    };
  }
}
