import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../data/model/readerStatsModel.dart';

class DailyGoalSection extends StatelessWidget {
  final ReaderStatsModel? stats;
  final int dailyGoalMinutes;

  const DailyGoalSection({super.key, this.stats, this.dailyGoalMinutes = 30});

  // Essaie de parser le temps total en minutes (format: "2h30" ou "45min" ou "1h")
  int _parseTotalMinutes(String? timeStr) {
    if (timeStr == null || timeStr == '0h') return 0;
    int total = 0;
    final hourMatch = RegExp(r'(\d+)h').firstMatch(timeStr);
    final minMatch = RegExp(r'(\d+)min').firstMatch(timeStr);
    if (hourMatch != null) total += int.parse(hourMatch.group(1)!) * 60;
    if (minMatch != null) total += int.parse(minMatch.group(1)!);
    // Si format simple "2h" sans minutes
    if (total == 0 && hourMatch != null) {
      total = int.parse(hourMatch.group(1)!) * 60;
    }
    return total;
  }

  String _getMotivationalMessage(double progress) {
    if (progress >= 1.0) return '🎉 Objectif atteint ! Bravo !';
    if (progress >= 0.75) return '💪 Presque là, continuez !';
    if (progress >= 0.5) return '🔥 Vous êtes à mi-chemin !';
    if (progress >= 0.25) return '📖 Bon début, continuez !';
    return '✨ Commencez votre session !';
  }

  @override
  Widget build(BuildContext context) {
    final totalMinutes = _parseTotalMinutes(stats?.totalTime);
    // On représente l'objectif du jour comme un % des minutes totales (simulé)
    // En réalité on prendrait les minutes de la session du jour
    final todayMinutes =
        totalMinutes % (dailyGoalMinutes * 2); // Simule la session du jour
    final progress = (todayMinutes / dailyGoalMinutes).clamp(0.0, 1.0);
    final message = _getMotivationalMessage(progress);
    final isCompleted = progress >= 1.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: Colors.transparent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.flag_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Objectif du jour',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '$dailyGoalMinutes min de lecture',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // Percentage badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isCompleted
                      ? const Color(0xFF10B981).withOpacity(0.1)
                      : const Color(0xFF6366F1).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${(progress * 100).round()}%',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: isCompleted
                        ? const Color(0xFF10B981)
                        : const Color(0xFF6366F1),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Progress bar
          Stack(
            children: [
              // Background
              Container(
                height: 10,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              // Fill
              AnimatedFractionallySizedBox(
                duration: const Duration(milliseconds: 800),
                widthFactor: progress,
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isCompleted
                          ? [const Color(0xFF10B981), const Color(0xFF059669)]
                          : [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withOpacity(0.4),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                message,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[400],
                ),
              ),
              Row(
                children: [
                  _buildMiniStat(
                    Icons.menu_book_rounded,
                    '${stats?.booksRead ?? 0}',
                    'livres',
                    const Color(0xFF6366F1),
                  ),
                  const SizedBox(width: 12),
                  _buildMiniStat(
                    Icons.emoji_events_rounded,
                    '${stats?.goalsAchieved ?? 0}',
                    'objectifs',
                    const Color(0xFFF59E0B),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 2),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: const Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }
}
