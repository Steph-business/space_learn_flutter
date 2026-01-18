import 'bookModel.dart';

class DetailedStatsModel {
  final String id;
  final String livreId;
  final double tauxConversion;
  final int nouveauxLecteurs;
  final double satisfaction;
  final double tempsLectureMoyen;
  final double lecteursReccurents;
  final double revenuParVue;
  final DateTime? creeLe;
  final BookModel? livre;

  DetailedStatsModel({
    required this.id,
    required this.livreId,
    required this.tauxConversion,
    required this.nouveauxLecteurs,
    required this.satisfaction,
    required this.tempsLectureMoyen,
    required this.lecteursReccurents,
    required this.revenuParVue,
    this.creeLe,
    this.livre,
  });

  factory DetailedStatsModel.fromJson(Map<String, dynamic> json) {
    return DetailedStatsModel(
      id: json['id'] ?? '',
      livreId: json['livre_id'] ?? '',
      tauxConversion: (json['taux_conversion'] != null)
          ? (json['taux_conversion'] as num).toDouble()
          : 0.0,
      nouveauxLecteurs: json['nouveaux_lecteurs'] ?? 0,
      satisfaction: (json['satisfaction'] != null)
          ? (json['satisfaction'] as num).toDouble()
          : 0.0,
      tempsLectureMoyen: (json['temps_lecture_moyen'] != null)
          ? (json['temps_lecture_moyen'] as num).toDouble()
          : 0.0,
      lecteursReccurents: (json['lecteurs_recurrents'] != null)
          ? (json['lecteurs_recurrents'] as num).toDouble()
          : 0.0,
      revenuParVue: (json['revenu_par_vue'] != null)
          ? (json['revenu_par_vue'] as num).toDouble()
          : 0.0,
      creeLe: json['cree_le'] != null ? DateTime.parse(json['cree_le']) : null,
      livre: json['Livre'] != null ? BookModel.fromJson(json['Livre']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'livre_id': livreId,
      'taux_conversion': tauxConversion,
      'nouveaux_lecteurs': nouveauxLecteurs,
      'satisfaction': satisfaction,
      'temps_lecture_moyen': tempsLectureMoyen,
      'lecteurs_recurrents': lecteursReccurents,
      'revenu_par_vue': revenuParVue,
      'cree_le': creeLe?.toIso8601String(),
      'Livre': livre?.toJson(),
    };
  }
}
