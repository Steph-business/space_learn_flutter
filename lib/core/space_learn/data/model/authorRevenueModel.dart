class AuthorRevenueModel {
  final List<MonthlyRevenue> monthlyRevenue;
  final List<BookRevenue> revenueByBook;
  final double totalRevenue;

  AuthorRevenueModel({
    required this.monthlyRevenue,
    required this.revenueByBook,
    required this.totalRevenue,
  });

  factory AuthorRevenueModel.fromJson(Map<String, dynamic> json) {
    return AuthorRevenueModel(
      monthlyRevenue:
          (json['monthly_revenue'] as List?)
              ?.map((i) => MonthlyRevenue.fromJson(i))
              .toList() ??
          [],
      revenueByBook:
          (json['revenue_by_book'] as List?)
              ?.map((i) => BookRevenue.fromJson(i))
              .toList() ??
          [],
      totalRevenue: (json['total_revenue'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'monthly_revenue': monthlyRevenue.map((i) => i.toJson()).toList(),
      'revenue_by_book': revenueByBook.map((i) => i.toJson()).toList(),
      'total_revenue': totalRevenue,
    };
  }
}

class MonthlyRevenue {
  final String mois;
  final int annee;
  final double montant;

  MonthlyRevenue({
    required this.mois,
    required this.annee,
    required this.montant,
  });

  factory MonthlyRevenue.fromJson(Map<String, dynamic> json) {
    return MonthlyRevenue(
      mois: json['mois'] ?? json['month'] ?? '',
      annee: json['annee'] ?? json['year'] ?? 0,
      montant: (json['montant'] ?? json['amount'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'mois': mois, 'annee': annee, 'montant': montant};
  }
}

class BookRevenue {
  final String livreId;
  final String titre;
  final double montant;

  BookRevenue({
    required this.livreId,
    required this.titre,
    required this.montant,
  });

  factory BookRevenue.fromJson(Map<String, dynamic> json) {
    return BookRevenue(
      livreId: json['livre_id'] ?? json['book_id'] ?? '',
      titre: json['titre'] ?? json['title'] ?? '',
      montant: (json['montant'] ?? json['amount'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'livre_id': livreId, 'titre': titre, 'montant': montant};
  }
}
