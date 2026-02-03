class AuthorRevenueModel {
  final List<TimeFrameRevenue> dailyRevenue;
  final List<TimeFrameRevenue> weeklyRevenue;
  final List<TimeFrameRevenue> monthlyRevenue;
  final List<TimeFrameRevenue> yearlyRevenue;
  final List<BookRevenue> revenueByBook;
  final double totalRevenue;

  AuthorRevenueModel({
    required this.dailyRevenue,
    required this.weeklyRevenue,
    required this.monthlyRevenue,
    required this.yearlyRevenue,
    required this.revenueByBook,
    required this.totalRevenue,
  });

  factory AuthorRevenueModel.fromJson(Map<String, dynamic> json) {
    return AuthorRevenueModel(
      dailyRevenue:
          (json['daily_revenue'] as List?)
              ?.map((i) => TimeFrameRevenue.fromJson(i, 'day'))
              .toList() ??
          [],
      weeklyRevenue:
          (json['weekly_revenue'] as List?)
              ?.map((i) => TimeFrameRevenue.fromJson(i, 'week'))
              .toList() ??
          [],
      monthlyRevenue:
          (json['monthly_revenue'] as List?)
              ?.map((i) => TimeFrameRevenue.fromJson(i, 'month'))
              .toList() ??
          [],
      yearlyRevenue:
          (json['yearly_revenue'] as List?)
              ?.map((i) => TimeFrameRevenue.fromJson(i, 'year'))
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
      'daily_revenue': dailyRevenue.map((i) => i.toJson()).toList(),
      'weekly_revenue': weeklyRevenue.map((i) => i.toJson()).toList(),
      'monthly_revenue': monthlyRevenue.map((i) => i.toJson()).toList(),
      'yearly_revenue': yearlyRevenue.map((i) => i.toJson()).toList(),
      'revenue_by_book': revenueByBook.map((i) => i.toJson()).toList(),
      'total_revenue': totalRevenue,
    };
  }
}

class TimeFrameRevenue {
  final String date;
  final double revenue;

  TimeFrameRevenue({required this.date, required this.revenue});

  factory TimeFrameRevenue.fromJson(Map<String, dynamic> json, String dateKey) {
    return TimeFrameRevenue(
      date: json[dateKey] ?? json['date'] ?? '',
      revenue: (json['revenue'] ?? json['montant'] ?? json['amount'] ?? 0.0)
          .toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'date': date, 'revenue': revenue};
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
      titre: json['livre_titre'] ?? json['titre'] ?? json['title'] ?? '',
      montant: (json['revenue'] ?? json['montant'] ?? json['amount'] ?? 0.0)
          .toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'livre_id': livreId, 'titre': titre, 'montant': montant};
  }
}
