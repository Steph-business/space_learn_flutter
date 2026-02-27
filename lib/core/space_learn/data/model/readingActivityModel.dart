import 'package:flutter/foundation.dart';
import 'book_model.dart';

class ReadingActivityModel {
  final String id;
  final String utilisateurId;
  final String livreId;
  final int? _lastPage;
  final int? _totalPages;
  final int? _chapitreCourant;
  final num? _pourcentage;
  final DateTime? creeLe;
  final DateTime? majLe;
  final BookModel? livre;

  int get lastPage => _lastPage ?? 0;
  int get totalPages => _totalPages ?? 0;
  int get chapitreCourant => _chapitreCourant ?? 0;
  num get pourcentage => _pourcentage ?? 0;

  ReadingActivityModel({
    required this.id,
    required this.utilisateurId,
    required this.livreId,
    int? lastPage,
    int? totalPages,
    int? chapitreCourant,
    num? pourcentage,
    this.creeLe,
    this.majLe,
    this.livre,
  }) : _lastPage = lastPage,
       _totalPages = totalPages,
       _chapitreCourant = chapitreCourant,
       _pourcentage = pourcentage;

  factory ReadingActivityModel.fromJson(Map<String, dynamic> json) {
    try {
      return ReadingActivityModel(
        id: (json['id'] ?? json['ID'] ?? '').toString(),
        utilisateurId: (json['utilisateur_id'] ?? json['UtilisateurId'] ?? '')
            .toString(),
        livreId: (json['livre_id'] ?? json['LivreId'] ?? '').toString(),
        lastPage: (json['last_page'] ?? json['LastPage']) is num
            ? (json['last_page'] ?? json['LastPage']).toInt()
            : (json['last_page'] ?? json['LastPage']) != null
            ? int.tryParse((json['last_page'] ?? json['LastPage']).toString())
            : null,
        totalPages: (json['total_pages'] ?? json['TotalPages']) is num
            ? (json['total_pages'] ?? json['TotalPages']).toInt()
            : (json['total_pages'] ?? json['TotalPages']) != null
            ? int.tryParse(
                (json['total_pages'] ?? json['TotalPages']).toString(),
              )
            : null,
        chapitreCourant:
            (json['chapitre_courant'] ?? json['ChapitreCourant']) is num
            ? (json['chapitre_courant'] ?? json['ChapitreCourant']).toInt()
            : (json['chapitre_courant'] ?? json['ChapitreCourant']) != null
            ? int.tryParse(
                (json['chapitre_courant'] ?? json['ChapitreCourant'])
                    .toString(),
              )
            : null,
        pourcentage: (() {
          final p =
              json['pourcentage'] ?? json['Pourcentage'] ?? json['percentage'];
          if (p == null) return 0.0;
          if (p is num) return p.toDouble();
          return double.tryParse(p.toString()) ?? 0.0;
        })(),
        creeLe: (json['cree_le'] ?? json['CreeLe']) != null
            ? DateTime.parse((json['cree_le'] ?? json['CreeLe']).toString())
            : null,
        majLe: (json['maj_le'] ?? json['MajLe']) != null
            ? DateTime.parse((json['maj_le'] ?? json['MajLe']).toString())
            : null,
        livre: (json['Livre'] ?? json['livre']) != null
            ? BookModel.fromJson(json['Livre'] ?? json['livre'])
            : null,
      );
    } catch (e) {
      debugPrint("Error parsing ReadingActivityModel: $e");
      return ReadingActivityModel(
        id: (json['id'] ?? '').toString(),
        utilisateurId: (json['utilisateur_id'] ?? '').toString(),
        livreId: (json['livre_id'] ?? '').toString(),
      );
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'utilisateur_id': utilisateurId,
      'livre_id': livreId,
      'last_page': lastPage,
      'total_pages': totalPages,
      'chapitre_courant': chapitreCourant,
      'pourcentage': pourcentage,
      'cree_le': creeLe?.toIso8601String(),
      'maj_le': majLe?.toIso8601String(),
      // 'Livre': livre?.toJson(), // Removed to avoid infinite recursion
    };
  }
}
