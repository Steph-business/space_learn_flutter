import 'bookModel.dart';

class BookStatsModel {
  final String id;
  final String livreId;
  final int vues;
  final int telechargements;
  final double noteMoyenne;
  final double revenus;
  final String periode;
  final DateTime? creeLe;
  final BookModel? livre;

  BookStatsModel({
    required this.id,
    required this.livreId,
    required this.vues,
    required this.telechargements,
    required this.noteMoyenne,
    required this.revenus,
    required this.periode,
    this.creeLe,
    this.livre,
  });

  factory BookStatsModel.fromJson(Map<String, dynamic> json) {
    return BookStatsModel(
      id: json['id'] ?? '',
      livreId: json['livre_id'] ?? '',
      vues: json['vues'] ?? 0,
      telechargements: json['telechargements'] ?? 0,
      noteMoyenne: (json['note_moyenne'] != null) ? (json['note_moyenne'] as num).toDouble() : 0.0,
      revenus: (json['revenus'] != null) ? (json['revenus'] as num).toDouble() : 0.0,
      periode: json['periode'] ?? '',
      creeLe: json['cree_le'] != null ? DateTime.parse(json['cree_le']) : null,
      livre: json['livre'] != null ? BookModel.fromJson(json['livre']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'livre_id': livreId,
      'vues': vues,
      'telechargements': telechargements,
      'note_moyenne': noteMoyenne,
      'revenus': revenus,
      'periode': periode,
      'cree_le': creeLe?.toIso8601String(),
      'livre': livre?.toJson(),
    };
  }
}
