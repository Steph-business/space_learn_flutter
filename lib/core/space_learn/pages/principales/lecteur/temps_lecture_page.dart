import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/themes/app_dimensions.dart';
import 'package:space_learn_flutter/core/themes/app_text_styles.dart';
import '../../../data/dataServices/reading_time_storage.dart';
import '../../../data/dataServices/readerStatsService.dart';
import '../../../../utils/token_storage.dart';

class TempsLecturePage extends StatefulWidget {
  final String userId;

  const TempsLecturePage({super.key, required this.userId});

  @override
  State<TempsLecturePage> createState() => _TempsLecturePageState();
}

class _TempsLecturePageState extends State<TempsLecturePage> {
  final ReaderStatsService _statsService = ReaderStatsService();

  int _totalMinutes = 0;
  int _todayMinutes = 0;
  int _streakDays = 0;
  int _dailyGoalMinutes = 15;
  String _reminderTime = '20:30';
  bool _reminderEnabled = true;
  List<DailyReadingPoint> _weeklyPoints = [];
  List<ReadingSessionModel> _recentSessions = [];
  bool _isLoading = true;

  // Preset options in minutes
  final List<int> _presetGoals = [15, 30, 45, 60, 90, 120, 180];

  @override
  void initState() {
    super.initState();
    _loadReadingAnalytics();
  }

  Future<void> _loadReadingAnalytics() async {
    try {
      final totalMin =
          await ReadingTimeStorage.getTotalReadingMinutes(widget.userId);
      final todayMin =
          await ReadingTimeStorage.getTodayReadingMinutes(widget.userId);
      final streak = await ReadingTimeStorage.getReadingStreak(widget.userId);
      final goal = await ReadingTimeStorage.getDailyGoalMinutes(widget.userId);
      final reminderT =
          await ReadingTimeStorage.getDailyReminderTime(widget.userId);
      final reminderEn =
          await ReadingTimeStorage.getDailyReminderEnabled(widget.userId);
      final points =
          await ReadingTimeStorage.getWeeklyReadingPoints(widget.userId);
      final sessions =
          await ReadingTimeStorage.getRecentSessions(widget.userId);

      try {
        final token = await TokenStorage.getToken();
        if (token != null) {
          await _statsService.getReaderStats(widget.userId);
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _totalMinutes = totalMin;
          _todayMinutes = todayMin;
          _streakDays = streak;
          _dailyGoalMinutes = goal;
          _reminderTime = reminderT;
          _reminderEnabled = reminderEn;
          _weeklyPoints = points;
          _recentSessions = sessions;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateDailyGoal(int targetMin) async {
    setState(() {
      _dailyGoalMinutes = targetMin;
    });
    await ReadingTimeStorage.setDailyGoalMinutes(widget.userId, targetMin);
  }

  Future<void> _toggleReminder(bool enabled) async {
    setState(() {
      _reminderEnabled = enabled;
    });
    await ReadingTimeStorage.setDailyReminderEnabled(widget.userId, enabled);
  }

  Future<void> _setExactReminderTime(String timeStr) async {
    setState(() {
      _reminderTime = timeStr;
    });
    await ReadingTimeStorage.setDailyReminderTime(widget.userId, timeStr);
  }

  Future<void> _pickReminderTime() async {
    final parts = _reminderTime.split(':');
    final initialHour = int.tryParse(parts.first) ?? 20;
    final initialMinute = int.tryParse(parts.last) ?? 30;

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initialHour, minute: initialMinute),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppColors.primary,
              surface: AppColors.cardBackground,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final hourStr = picked.hour.toString().padLeft(2, '0');
      final minuteStr = picked.minute.toString().padLeft(2, '0');
      final timeStr = '$hourStr:$minuteStr';
      await _setExactReminderTime(timeStr);
    }
  }

  void _showCustomGoalDialog() {
    int selectedHours = _dailyGoalMinutes ~/ 60;
    int selectedMins = _dailyGoalMinutes % 60;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusCard),
        ),
      ),
      builder: (ctx) {
        // Le builder n'est pas un build() : il s'exécute dans son propre
        // élément, plus tard. Sans cet abonnement, la feuille garde la palette
        // en vigueur à son ouverture et ne suit pas une bascule clair/sombre.
        AppColors.suivreLeTheme(ctx);
        return StatefulBuilder(
          builder: (context, setModalState) {
            final totalCalculated = (selectedHours * 60) + selectedMins;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Objectif de lecture sur-mesure",
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: AppColors.textSecondary),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Définissez le temps exact que vous souhaitez dédier aux livres par jour.",
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.12),
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusPill),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        _formatGoalDuration(totalCalculated),
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.accentInk,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Heures : $selectedHours h",
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Slider(
                              value: selectedHours.toDouble(),
                              min: 0,
                              max: 8,
                              divisions: 8,
                              activeColor: AppColors.primary,
                              inactiveColor:
                                  AppColors.textHint.withOpacity(0.2),
                              onChanged: (val) {
                                setModalState(() {
                                  selectedHours = val.round();
                                  if (selectedHours == 0 &&
                                      selectedMins == 0) {
                                    selectedMins = 5;
                                  }
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Minutes : $selectedMins min",
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Slider(
                              value: selectedMins.toDouble(),
                              min: 0,
                              max: 55,
                              divisions: 11,
                              activeColor: AppColors.primary,
                              inactiveColor:
                                  AppColors.textHint.withOpacity(0.2),
                              onChanged: (val) {
                                setModalState(() {
                                  selectedMins = val.round();
                                  if (selectedHours == 0 &&
                                      selectedMins == 0) {
                                    selectedMins = 5;
                                  }
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        final finalMin =
                            (selectedHours * 60) + selectedMins;
                        _updateDailyGoal(finalMin > 0 ? finalMin : 15);
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.onAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppDimensions.radiusPill),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        "Valider cet objectif",
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _formatGoalDuration(int minutes) {
    if (minutes < 60) {
      return "$minutes min / jour";
    }
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (m == 0) {
      return "$h h / jour";
    }
    return "${h}h ${m}m / jour";
  }

  String _getGoalChipLabel(int minutes) {
    if (minutes < 60) {
      return "$minutes min";
    }
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (m == 0) {
      return "${h}h";
    }
    return "${h}h${m.toString().padLeft(2, '0')}";
  }

  String _getAnnualEstimate(int minutesPerDay) {
    if (minutesPerDay <= 15) {
      return "🌱 Permet de lire environ 12 à 15 livres par an.";
    } else if (minutesPerDay <= 30) {
      return "🌿 Permet de lire environ 25 à 30 livres par an.";
    } else if (minutesPerDay <= 60) {
      return "🚀 Permet de lire plus de 50 livres par an — Rythme régulier !";
    } else if (minutesPerDay <= 120) {
      return "🏆 Rythme d'élite : plus de 100 livres par an !";
    } else {
      return "🔥 Passion absolue : niveau grand érudit !";
    }
  }

  @override
  Widget build(BuildContext context) {
    AppColors.suivreLeTheme(context);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.cardBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Temps & Habitudes de Lecture",
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            )
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _loadReadingAnalytics,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeroOverview(),
                    const SizedBox(height: 16),
                    _buildWeeklyChartSection(),
                    const SizedBox(height: 16),
                    _buildDailyGoalCustomizer(),
                    const SizedBox(height: 16),
                    _buildDailyReminderCard(),
                    const SizedBox(height: 16),
                    _buildRecentSessionsTimeline(),
                    const SizedBox(height: 16),
                    _buildMotivationTipsCard(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeroOverview() {
    final formattedTotal =
        ReadingTimeStorage.formatMinutesFull(_totalMinutes);
    final todayProgress = _dailyGoalMinutes > 0
        ? (_todayMinutes / _dailyGoalMinutes).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryDark,
            AppColors.primary,
          ],
        ),
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.18),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Temps total cumulé",
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.onAccent.withOpacity(0.8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formattedTotal,
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: AppColors.onAccent,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.onAccent.withOpacity(0.12),
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusPill),
                  border: Border.all(
                    color: AppColors.onAccent.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("🔥", style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Text(
                      _streakDays > 0
                          ? "$_streakDays ${_streakDays == 1 ? 'jour' : 'jours'}"
                          : "0 jour",
                      style: GoogleFonts.poppins(
                        color: AppColors.onAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.onAccent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(AppDimensions.radiusInner),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Objectif du jour",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.onAccent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      "$_todayMinutes / ${_dailyGoalMinutes < 60 ? '$_dailyGoalMinutes min' : _formatGoalDuration(_dailyGoalMinutes).replaceAll(' / jour', '')}",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.onAccent,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusXs),
                  child: LinearProgressIndicator(
                    value: todayProgress,
                    minHeight: 8,
                    backgroundColor: AppColors.onAccent.withOpacity(0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _todayMinutes >= _dailyGoalMinutes
                          ? AppColors.success
                          : AppColors.onAccent,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _todayMinutes >= _dailyGoalMinutes
                      ? "🎉 Félicitations ! Objectif du jour atteint."
                      : "Encore ${(_dailyGoalMinutes - _todayMinutes).clamp(0, 999)} min pour valider votre journée !",
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppColors.onAccent.withOpacity(0.85),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyChartSection() {
    int totalWeekMinutes = 0;
    int maxMin = 15;
    for (var p in _weeklyPoints) {
      totalWeekMinutes += p.minutes;
      if (p.minutes > maxMin) maxMin = p.minutes;
    }
    final avgPerDay = (totalWeekMinutes / 7).round();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(
          color: AppColors.textPrimary.withOpacity(0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Les 7 derniers jours",
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                "Total : ${ReadingTimeStorage.formatMinutes(totalWeekMinutes)}",
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accentInk,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            "Moyenne : $avgPerDay min par jour",
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 120,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: _weeklyPoints.map((point) {
                final heightFactor =
                    (point.minutes / maxMin).clamp(0.05, 1.0);
                return _buildBarColumn(point, heightFactor);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarColumn(DailyReadingPoint point, double heightFactor) {
    final isToday = point.isToday;
    final hasRead = point.minutes > 0;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          hasRead ? "${point.minutes}m" : "",
          style: GoogleFonts.poppins(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: isToday ? AppColors.accentInk : AppColors.textHint,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 26,
          height: 70 * heightFactor,
          decoration: BoxDecoration(
            gradient: hasRead
                ? LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: isToday
                        ? [AppColors.primaryDark, AppColors.primary]
                        : [
                            AppColors.primary.withOpacity(0.6),
                            AppColors.primaryLight.withOpacity(0.3),
                          ],
                  )
                : null,
            color: hasRead ? null : AppColors.textHint.withOpacity(0.12),
            borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
            border: isToday
                ? Border.all(color: AppColors.primary, width: 1.5)
                : null,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          point.dayLabel,
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
            color: isToday ? AppColors.accentInk : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildDailyGoalCustomizer() {
    final isPresetSelected = _presetGoals.contains(_dailyGoalMinutes);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(
          color: AppColors.textPrimary.withOpacity(0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.tune_rounded,
                      color: AppColors.accentInk, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    "Personnaliser mon objectif",
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusPill),
                ),
                child: Text(
                  _formatGoalDuration(_dailyGoalMinutes),
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.accentInk,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            "Choisissez un temps prédéfini ou ajustez librement :",
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ..._presetGoals.map((min) {
                final isSelected = _dailyGoalMinutes == min;
                return ChoiceChip(
                  label: Text(_getGoalChipLabel(min)),
                  selected: isSelected,
                  onSelected: (val) {
                    if (val) _updateDailyGoal(min);
                  },
                  selectedColor: AppColors.primary,
                  backgroundColor: AppColors.scaffoldBackground,
                  labelStyle: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? AppColors.onAccent
                        : AppColors.textPrimary,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusPill),
                    side: BorderSide(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textHint.withOpacity(0.25),
                    ),
                  ),
                );
              }),
              ActionChip(
                avatar: Icon(
                  Icons.edit_outlined,
                  size: 15,
                  color: !isPresetSelected
                      ? AppColors.onAccent
                      : AppColors.accentInk,
                ),
                label: Text(
                  !isPresetSelected
                      ? _getGoalChipLabel(_dailyGoalMinutes)
                      : "Autre...",
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: !isPresetSelected
                        ? FontWeight.bold
                        : FontWeight.w500,
                    color: !isPresetSelected
                        ? AppColors.onAccent
                        : AppColors.textPrimary,
                  ),
                ),
                backgroundColor: !isPresetSelected
                    ? AppColors.primary
                    : AppColors.scaffoldBackground,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusPill),
                  side: BorderSide(
                    color: !isPresetSelected
                        ? AppColors.primary
                        : AppColors.primary.withOpacity(0.5),
                  ),
                ),
                onPressed: _showCustomGoalDialog,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text(
                "Ajustement fin :",
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              Text(
                _formatGoalDuration(_dailyGoalMinutes),
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.accentInk,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: AppColors.textHint.withOpacity(0.15),
              thumbColor: AppColors.primary,
              overlayColor: AppColors.primary.withOpacity(0.2),
              trackHeight: 4,
            ),
            child: Slider(
              value: _dailyGoalMinutes.toDouble().clamp(5.0, 240.0),
              min: 5,
              max: 240,
              divisions: 47,
              onChanged: (val) {
                _updateDailyGoal(val.round());
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: AppColors.scaffoldBackground,
              borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _getAnnualEstimate(_dailyGoalMinutes),
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyReminderCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(
          color: _reminderEnabled
              ? AppColors.primary.withOpacity(0.35)
              : AppColors.textPrimary.withOpacity(0.06),
        ),
        boxShadow: _reminderEnabled
            ? [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _reminderEnabled
                      ? AppColors.primary.withOpacity(0.15)
                      : AppColors.textHint.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _reminderEnabled
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_off_outlined,
                  color: _reminderEnabled
                      ? AppColors.accentInk
                      : AppColors.textHint,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Rappel quotidien de lecture",
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _reminderEnabled
                          ? "Notification programmée chaque jour"
                          : "Recevoir un rappel pour garder le rythme",
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Transform.scale(
                scale: 0.9,
                child: Switch(
                  value: _reminderEnabled,
                  activeColor: AppColors.primary,
                  activeTrackColor: AppColors.primary.withOpacity(0.4),
                  inactiveThumbColor: AppColors.textHint,
                  inactiveTrackColor: AppColors.textHint.withOpacity(0.2),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: _toggleReminder,
                ),
              ),
            ],
          ),
          if (_reminderEnabled) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: AppColors.scaffoldBackground,
                borderRadius: BorderRadius.circular(AppDimensions.radiusInner),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.25),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(
                            AppDimensions.radiusXs,
                          ),
                        ),
                        child: Icon(
                          Icons.alarm_rounded,
                          size: 20,
                          color: AppColors.accentInk,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Heure du rappel",
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            _reminderTime,
                            style: GoogleFonts.poppins(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: AppColors.accentInk,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: _pickReminderTime,
                    icon: const Icon(Icons.access_time_rounded, size: 16),
                    label: const Text("Modifier"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onAccent,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      textStyle: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusPill),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  "Créneaux rapides :",
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildQuickTimeChip("08:00", "Matin"),
                        const SizedBox(width: 6),
                        _buildQuickTimeChip("13:00", "Midi"),
                        const SizedBox(width: 6),
                        _buildQuickTimeChip("20:30", "Soir"),
                        const SizedBox(width: 6),
                        _buildQuickTimeChip("22:00", "Nuit"),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickTimeChip(String timeStr, String label) {
    final isSelected = _reminderTime == timeStr;
    return InkWell(
      onTap: () => _setExactReminderTime(timeStr),
      borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : AppColors.scaffoldBackground,
          borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : AppColors.textHint.withOpacity(0.2),
          ),
        ),
        child: Text(
          "$label ($timeStr)",
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? AppColors.onAccent : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildRecentSessionsTimeline() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(
          color: AppColors.textPrimary.withOpacity(0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history_rounded,
                  color: AppColors.accentInk, size: 20),
              const SizedBox(width: 8),
              Text(
                "Sessions de lecture récentes",
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_recentSessions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.menu_book_outlined,
                      size: 40,
                      color: AppColors.textHint,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Aucune session enregistrée pour l'instant",
                      style: AppTextStyles.bodyFaded16,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Ouvrez un livre dans votre bibliothèque pour lancer votre première session !",
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppColors.textHint,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _recentSessions.length,
              separatorBuilder: (_, __) => const Divider(height: 16),
              itemBuilder: (context, index) {
                final session = _recentSessions[index];
                final dateStr = DateFormat('dd MMM à HH:mm', 'fr_FR')
                    .format(session.timestamp);
                final durationStr =
                    ReadingTimeStorage.formatMinutes(session.durationMinutes);

                return Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.auto_stories_rounded,
                        size: 18,
                        color: AppColors.accentInk,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            session.bookTitle,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            dateStr,
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.12),
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusPill),
                      ),
                      child: Text(
                        durationStr,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.accentInk,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildMotivationTipsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.lightbulb_outline_rounded,
              color: AppColors.accentInk,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Conseil d'habitude SpaceLearn",
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "La régularité prime sur la quantité : lire 15 à 30 minutes chaque jour construit une habitude d'apprentissage puissante et durable !",
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
