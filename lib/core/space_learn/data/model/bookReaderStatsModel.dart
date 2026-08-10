class BookReaderStatsModel {
  final String livreId;
  final int totalReadingTime; // in minutes
  final int sessionsCount;
  final double percentage;
  final int lastPage;
  final int totalPages;
  final DateTime? lastReadAt;

  BookReaderStatsModel({
    required this.livreId,
    required this.totalReadingTime,
    required this.sessionsCount,
    required this.percentage,
    required this.lastPage,
    required this.totalPages,
    this.lastReadAt,
  });

  factory BookReaderStatsModel.fromJson(Map<String, dynamic> json) {
    return BookReaderStatsModel(
      livreId: json['livre_id'] ?? '',
      totalReadingTime: json['total_reading_time'] ?? 0,
      sessionsCount: json['sessions_count'] ?? 0,
      percentage: (json['percentage'] ?? 0).toDouble(),
      lastPage: json['last_page'] ?? 0,
      totalPages: json['total_pages'] ?? 0,
      lastReadAt: json['last_read_at'] != null
          ? DateTime.parse(json['last_read_at'])
          : null,
    );
  }

  String get formattedTime {
    if (totalReadingTime < 60) return "${totalReadingTime}m";
    int hours = totalReadingTime ~/ 60;
    int minutes = totalReadingTime % 60;
    return minutes > 0 ? "${hours}h ${minutes}m" : "${hours}h";
  }
}
