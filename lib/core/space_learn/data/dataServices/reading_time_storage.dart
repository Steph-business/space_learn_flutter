import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../model/goalModel.dart';

class ReadingSessionModel {
  final String id;
  final String bookId;
  final String bookTitle;
  final DateTime timestamp;
  final int durationSeconds;

  ReadingSessionModel({
    required this.id,
    required this.bookId,
    required this.bookTitle,
    required this.timestamp,
    required this.durationSeconds,
  });

  int get durationMinutes => (durationSeconds / 60).ceil();

  factory ReadingSessionModel.fromJson(Map<String, dynamic> json) {
    return ReadingSessionModel(
      id: json['id'] ?? '',
      bookId: json['bookId'] ?? '',
      bookTitle: json['bookTitle'] ?? 'Livre',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp']) ?? DateTime.now()
          : DateTime.now(),
      durationSeconds: json['durationSeconds'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'bookId': bookId,
    'bookTitle': bookTitle,
    'timestamp': timestamp.toIso8601String(),
    'durationSeconds': durationSeconds,
  };
}

class DailyReadingPoint {
  final String dayLabel; // "Lun", "Mar", etc.
  final DateTime date;
  final int minutes;
  final bool isToday;

  DailyReadingPoint({
    required this.dayLabel,
    required this.date,
    required this.minutes,
    required this.isToday,
  });
}

class ReadingTimeStorage {
  static const String _keyPrefixTotal = 'reading_total_seconds_';
  static const String _keyPrefixToday = 'reading_today_seconds_';
  static const String _keyPrefixBook = 'reading_book_seconds_';
  static const String _keyPrefixSessions = 'reading_sessions_';
  static const String _keyPrefixGoal = 'reading_daily_goal_minutes_';
  static const String _keyPrefixReminderTime = 'reading_reminder_time_';
  static const String _keyPrefixReminderEnabled = 'reading_reminder_enabled_';

  static String _resolveUserId(String? userId) {
    if (userId != null && userId.trim().isNotEmpty && userId != '0') {
      return userId.trim();
    }
    return 'default_user';
  }

  static String _dateKey(String uid, DateTime dt) {
    final nowStr = DateFormat('yyyy-MM-dd').format(dt);
    return '$_keyPrefixToday${uid}_$nowStr';
  }

  static String _todayKey(String uid) {
    return _dateKey(uid, DateTime.now());
  }

  /// Record elapsed reading seconds for a user session
  static Future<void> addReadingSeconds({
    required String? userId,
    String? bookId,
    required int seconds,
  }) async {
    if (seconds <= 0) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = _resolveUserId(userId);

      // 1. Total seconds
      final totalKey = '$_keyPrefixTotal$uid';
      final currentTotal = prefs.getInt(totalKey) ?? 0;
      await prefs.setInt(totalKey, currentTotal + seconds);

      // 2. Today's seconds
      final todayK = _todayKey(uid);
      final currentToday = prefs.getInt(todayK) ?? 0;
      await prefs.setInt(todayK, currentToday + seconds);

      // 3. Book specific seconds
      if (bookId != null && bookId.isNotEmpty) {
        final bookKey = '$_keyPrefixBook${uid}_$bookId';
        final currentBook = prefs.getInt(bookKey) ?? 0;
        await prefs.setInt(bookKey, currentBook + seconds);
      }
    } catch (_) {}
  }

  /// Record a completed reading session with timestamp and book title
  static Future<void> recordSession({
    required String? userId,
    required String bookId,
    required String bookTitle,
    required int durationSeconds,
  }) async {
    if (durationSeconds < 5) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = _resolveUserId(userId);
      final sessionsKey = '$_keyPrefixSessions$uid';

      final existingRaw = prefs.getStringList(sessionsKey) ?? [];
      final List<ReadingSessionModel> sessions = existingRaw
          .map((str) {
            try {
              return ReadingSessionModel.fromJson(jsonDecode(str));
            } catch (_) {
              return null;
            }
          })
          .whereType<ReadingSessionModel>()
          .toList();

      final newSession = ReadingSessionModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        bookId: bookId,
        bookTitle: bookTitle.isNotEmpty ? bookTitle : 'Livre',
        timestamp: DateTime.now(),
        durationSeconds: durationSeconds,
      );

      sessions.insert(0, newSession);
      // Keep only recent 30 sessions
      final trimmed = sessions.take(30).toList();
      await prefs.setStringList(
        sessionsKey,
        trimmed.map((s) => jsonEncode(s.toJson())).toList(),
      );
    } catch (_) {}
  }

  /// Get recent reading sessions
  static Future<List<ReadingSessionModel>> getRecentSessions(
    String? userId, {
    int limit = 15,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = _resolveUserId(userId);
      final sessionsKey = '$_keyPrefixSessions$uid';

      final existingRaw = prefs.getStringList(sessionsKey) ?? [];
      final sessions = existingRaw
          .map((str) {
            try {
              return ReadingSessionModel.fromJson(jsonDecode(str));
            } catch (_) {
              return null;
            }
          })
          .whereType<ReadingSessionModel>()
          .toList();

      return sessions.take(limit).toList();
    } catch (_) {
      return [];
    }
  }

  /// Get total reading minutes for user
  static Future<int> getTotalReadingMinutes(String? userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = _resolveUserId(userId);
      final totalSeconds = prefs.getInt('$_keyPrefixTotal$uid') ?? 0;
      return totalSeconds ~/ 60;
    } catch (_) {
      return 0;
    }
  }

  /// Get today's reading minutes for user
  static Future<int> getTodayReadingMinutes(String? userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = _resolveUserId(userId);
      final todaySeconds = prefs.getInt(_todayKey(uid)) ?? 0;
      return todaySeconds ~/ 60;
    } catch (_) {
      return 0;
    }
  }

  /// Get 7-day weekly reading points (Last 7 days ending today)
  static Future<List<DailyReadingPoint>> getWeeklyReadingPoints(
    String? userId,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = _resolveUserId(userId);
      final now = DateTime.now();

      final List<DailyReadingPoint> points = [];
      const List<String> frenchDays = [
        'Lun',
        'Mar',
        'Mer',
        'Jeu',
        'Ven',
        'Sam',
        'Dim',
      ];

      for (int i = 6; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        final key = _dateKey(uid, date);
        final seconds = prefs.getInt(key) ?? 0;
        final minutes = seconds ~/ 60;
        final dayIndex = date.weekday - 1; // 1 = Monday, 7 = Sunday
        final dayLabel = (dayIndex >= 0 && dayIndex < 7)
            ? frenchDays[dayIndex]
            : 'J';

        points.add(
          DailyReadingPoint(
            dayLabel: dayLabel,
            date: date,
            minutes: minutes,
            isToday: i == 0,
          ),
        );
      }
      return points;
    } catch (_) {
      return [];
    }
  }

  /// Calculate consecutive reading days streak
  static Future<int> getReadingStreak(String? userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = _resolveUserId(userId);
      final now = DateTime.now();

      int streak = 0;
      // Check today first
      final todayKey = _dateKey(uid, now);
      final todaySeconds = prefs.getInt(todayKey) ?? 0;
      if (todaySeconds > 0) {
        streak++;
      }

      // Check backwards from yesterday
      for (int i = 1; i <= 365; i++) {
        final prevDate = now.subtract(Duration(days: i));
        final prevKey = _dateKey(uid, prevDate);
        final seconds = prefs.getInt(prevKey) ?? 0;
        if (seconds > 0) {
          streak++;
        } else {
          break;
        }
      }
      return streak;
    } catch (_) {
      return 0;
    }
  }

  /// Daily goal in minutes (default: 15)
  static Future<int> getDailyGoalMinutes(String? userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = _resolveUserId(userId);
      return prefs.getInt('$_keyPrefixGoal$uid') ?? 15;
    } catch (_) {
      return 15;
    }
  }

  static Future<void> setDailyGoalMinutes(String? userId, int minutes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = _resolveUserId(userId);
      await prefs.setInt('$_keyPrefixGoal$uid', minutes);
    } catch (_) {}
  }

  /// Daily reminder settings
  static Future<String> getDailyReminderTime(String? userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = _resolveUserId(userId);
      return prefs.getString('$_keyPrefixReminderTime$uid') ?? '20:30';
    } catch (_) {
      return '20:30';
    }
  }

  static Future<void> setDailyReminderTime(String? userId, String time) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = _resolveUserId(userId);
      await prefs.setString('$_keyPrefixReminderTime$uid', time);
    } catch (_) {}
  }

  static Future<bool> getDailyReminderEnabled(String? userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = _resolveUserId(userId);
      return prefs.getBool('$_keyPrefixReminderEnabled$uid') ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> setDailyReminderEnabled(
    String? userId,
    bool enabled,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = _resolveUserId(userId);
      await prefs.setBool('$_keyPrefixReminderEnabled$uid', enabled);
    } catch (_) {}
  }

  /// Format minutes into human readable text
  static String formatMinutes(int minutes) {
    if (minutes <= 0) return '0m';
    if (minutes < 60) return '${minutes}m';
    final hours = minutes ~/ 60;
    final remaining = minutes % 60;
    return remaining > 0 ? '${hours}h ${remaining}m' : '${hours}h';
  }

  /// Format minutes with clean label
  static String formatMinutesFull(int minutes) {
    if (minutes <= 0) return '0 minute';
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final remaining = minutes % 60;
    return remaining > 0 ? '${hours}h ${remaining}min' : '${hours}h';
  }

  /// Generate dynamic smart goals based on real activity
  static List<GoalModel> computeSmartGoals({
    required int booksRead,
    required int totalMinutes,
    required int todayMinutes,
    required int libraryCount,
    int dailyGoalTarget = 15,
  }) {
    return [
      GoalModel(
        id: 'goal_daily_reading',
        titre: 'Lecture quotidienne',
        description: 'Lire au moins $dailyGoalTarget minutes aujourd\'hui',
        type: 'DAILY',
        valeurCible: dailyGoalTarget,
        valeurActuelle: todayMinutes,
        estTermine: todayMinutes >= dailyGoalTarget,
      ),
      GoalModel(
        id: 'goal_first_book',
        titre: 'Premier chef-d\'œuvre',
        description: 'Terminer la lecture d\'un premier livre',
        type: 'CHALLENGE',
        valeurCible: 1,
        valeurActuelle: booksRead,
        estTermine: booksRead >= 1,
      ),
      GoalModel(
        id: 'goal_library_collection',
        titre: 'Bibliophile',
        description: 'Ajouter au moins 2 livres à sa bibliothèque',
        type: 'CHALLENGE',
        valeurCible: 2,
        valeurActuelle: libraryCount,
        estTermine: libraryCount >= 2,
      ),
      GoalModel(
        id: 'goal_hour_reader',
        titre: 'Grand Lecteur',
        description: 'Cumuler 1 heure totale de lecture',
        type: 'CHALLENGE',
        valeurCible: 60,
        valeurActuelle: totalMinutes,
        estTermine: totalMinutes >= 60,
      ),
    ];
  }
}
