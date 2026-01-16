class ReaderStatsModel {
  final int booksRead;
  final String totalTime;
  final int goalsAchieved;

  ReaderStatsModel({
    required this.booksRead,
    required this.totalTime,
    required this.goalsAchieved,
  });

  factory ReaderStatsModel.fromJson(Map<String, dynamic> json) {
    return ReaderStatsModel(
      booksRead: json['books_read'] ?? 0,
      totalTime: json['total_time'] ?? '0h',
      goalsAchieved: json['goals_achieved'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'books_read': booksRead,
      'total_time': totalTime,
      'goals_achieved': goalsAchieved,
    };
  }
}
