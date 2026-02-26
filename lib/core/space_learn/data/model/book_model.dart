import 'categorie.dart';
import 'activite_model.dart';
import 'readingActivityModel.dart';
import 'recommendationModel.dart';
import 'user_model.dart';
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

  // Stats - Made robust with gutters to avoid Null errors during Hot Reload
  final double? _noteMoyenne;
  final int? _telechargements;
  final int? _nombreMessages;

  double get noteMoyenne => _noteMoyenne ?? 0.0;
  int get telechargements => _telechargements ?? 0;
  int get nombreMessages => _nombreMessages ?? 0;

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
    int? nombreMessages,
  }) : _noteMoyenne = noteMoyenne ?? 0.0,
       _telechargements = telechargements ?? 0,
       _nombreMessages = nombreMessages ?? 0;

  factory BookModel.fromJson(Map<String, dynamic> json) {
    // Handle author extraction
    final String authorId =
        (json['auteur_id'] ??
                json['author_id'] ??
                json['AuteurID'] ??
                json['auteurID'] ??
                json['AuthorID'] ??
                json['authorID'] ??
                '')
            .toString();

    UserModel? author;
    final authorData =
        json['Auteur'] ??
        json['auteur'] ??
        json['Utilisateur'] ??
        json['utilisateur'] ??
        json['author'] ??
        json['user'];

    if (authorData != null) {
      if (authorData is Map<String, dynamic>) {
        try {
          author = UserModel.fromJson(authorData);
        } catch (e) {
          // Fallback if full parsing fails but we have a name field
          String? name = authorData['nom_complet'] ?? authorData['NomComplet'];

          if (name != null) {
            author = UserModel(
              id: authorData['id'] ?? authorId,
              profilId: authorData['profil_id'] ?? authorId,
              email: authorData['email'] ?? '',
              nomComplet: name.toString(),
              isProfileComplete: false,
            );
          }
        }
      } else if (authorData is String) {
        author = UserModel(
          id: authorId,
          profilId: authorId,
          email: '',
          nomComplet: authorData,
          isProfileComplete: false,
        );
      }
    }

    // Secondary fallback using the joined field from backend (JOIN on profiles)
    if (author == null || author.nomComplet.isEmpty) {
      final nameFallback =
          json['nom_auteur'] ??
          json['NomAuteur'] ??
          json['nom_complet'] ??
          json['NomComplet'] ??
          json['auteur_nom'] ??
          json['AuteurNom'] ??
          json['display_name'] ??
          json['displayName'];

      if (nameFallback != null && nameFallback.toString().isNotEmpty) {
        author = UserModel(
          id: authorId,
          profilId: authorId,
          email: json['email'] ?? json['Email'] ?? json['auteur_email'] ?? '',
          nomComplet: nameFallback.toString(),
          isProfileComplete: false,
        );
      }
    }

    return BookModel(
      id: json['id'] ?? '',
      auteurId: authorId,
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
      noteMoyenne: (() {
        final val =
            json['note_moyenne'] ??
            json['NoteMoyenne'] ??
            json['note_moyenne_avis'] ??
            json['average_rating'] ??
            json['rating'];
        if (val == null) return 0.0;
        return (val as num).toDouble();
      })(),
      telechargements: (() {
        final val =
            json['nombre_avis'] ??
            json['NombreAvis'] ??
            json['reviews_count'] ??
            json['review_count'] ??
            json['activites_count'] ??
            json['telechargements'] ??
            json['downloads'] ??
            0;
        int count = (val as num).toInt();
        if (count == 0 && json['Activites'] is List) {
          return (json['Activites'] as List).length;
        }
        return count;
      })(),
      nombreMessages:
          (json['nombre_messages'] ??
                  json['NombreMessages'] ??
                  json['messages_count'] ??
                  0)
              .toInt(),
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
          : (json['Progression'] != null || json['progression'] != null)
          ? [
              ReadingActivityModel.fromJson(
                json['Progression'] ?? json['progression'],
              ),
            ]
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

  String get authorName => (auteur != null && auteur!.nomComplet.isNotEmpty)
      ? auteur!.nomComplet
      : 'Auteur inconnu';

  BookModel copyWith({
    String? id,
    String? auteurId,
    String? titre,
    String? description,
    String? imageCouverture,
    String? fichierUrl,
    String? format,
    int? prix,
    int? stock,
    String? categorieId,
    String? statut,
    String? adresseContratNft,
    DateTime? creeLe,
    DateTime? majLe,
    double? noteMoyenne,
    int? telechargements,
    int? nombreMessages,
    Categorie? categorie,
    List<ReviewModel>? activites,
    List<ReadingActivityModel>? progressions,
    List<RecommendationModel>? recommandations,
    UserModel? auteur,
  }) {
    return BookModel(
      id: id ?? this.id,
      auteurId: auteurId ?? this.auteurId,
      titre: titre ?? this.titre,
      description: description ?? this.description,
      imageCouverture: imageCouverture ?? this.imageCouverture,
      fichierUrl: fichierUrl ?? this.fichierUrl,
      format: format ?? this.format,
      prix: prix ?? this.prix,
      stock: stock ?? this.stock,
      categorieId: categorieId ?? this.categorieId,
      statut: statut ?? this.statut,
      adresseContratNft: adresseContratNft ?? this.adresseContratNft,
      creeLe: creeLe ?? this.creeLe,
      majLe: majLe ?? this.majLe,
      noteMoyenne: noteMoyenne ?? this.noteMoyenne,
      telechargements: telechargements ?? this.telechargements,
      nombreMessages: nombreMessages ?? this.nombreMessages,
      categorie: categorie ?? this.categorie,
      activites: activites ?? this.activites,
      progressions: progressions ?? this.progressions,
      recommandations: recommandations ?? this.recommandations,
      auteur: auteur ?? this.auteur,
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
      'note_moyenne': noteMoyenne,
      'telechargements': telechargements,
      'nombre_messages': nombreMessages,
      'Categorie': categorie?.toJson(),
      'Activites': activites?.map((i) => i.toJson()).toList(),
      'Progressions': progressions?.map((i) => i.toJson()).toList(),
      'Recommandations': recommandations?.map((i) => i.toJson()).toList(),
      'Auteur': auteur?.toJson(),
    };
  }
}
