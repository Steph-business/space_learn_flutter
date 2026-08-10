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
    String formattedTime = '0h';
    final timeData = json['total_time'] ?? json['total_reading_time'];

    if (timeData is num) {
      if (timeData < 60) {
        formattedTime = "${timeData}m";
      } else {
        int hours = timeData ~/ 60;
        int minutes = (timeData % 60).toInt();
        formattedTime = minutes > 0 ? "${hours}h ${minutes}m" : "${hours}h";
      }
    } else if (timeData is String) {
      formattedTime = timeData;
    }

    return ReaderStatsModel(
      booksRead: json['books_read'] ?? json['books_count'] ?? 0,
      totalTime: formattedTime,
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
