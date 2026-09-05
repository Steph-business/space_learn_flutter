import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/themes/app_dimensions.dart';
import 'package:space_learn_flutter/core/themes/app_text_styles.dart';
import '../../../data/dataServices/reading_time_storage.dart';
import '../../../data/dataServices/readerStatsService.dart';
import 'package:space_learn_flutter/core/services/rappels_lecture.dart';
import 'package:space_learn_flutter/core/utils/app_notifications.dart';

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

  /// Les créneaux de lecture, avec leurs jours.
  ///
  /// Remplacent l'heure unique `_reminderTime` et sa bascule : une seule heure,
  /// la même sept jours sur sept, et surtout aucune notification jamais
  /// programmée.
  List<CreneauLecture> _creneaux = [];
  List<DailyReadingPoint> _weeklyPoints = [];
  List<ReadingSessionModel> _recentSessions = [];
  bool _isLoading = true;

  /// Le bilan du serveur a répondu et a quelque chose à dire.
  ///
  /// Retenu, et non plus consommé sur place : le total, la journée et la série
  /// venaient du serveur pendant que l'histogramme des sept jours et les
  /// sessions récentes restaient locaux. Sur un appareil neuf, l'écran
  /// annonçait « aujourd'hui 45 min » au-dessus d'une barre du jour à zéro —
  /// la contradiction entre deux écrans était devenue une contradiction à
  /// l'intérieur d'un seul.
  bool _serveurRenseigne = false;

  // Preset options in minutes
  final List<int> _presetGoals = [15, 30, 45, 60, 90, 120, 180];

  @override
  void initState() {
    super.initState();
    _loadReadingAnalytics();
  }

  Future<void> _loadReadingAnalytics() async {
    try {
      final totalMin = await ReadingTimeStorage.getTotalReadingMinutes(
        widget.userId,
      );
      final todayMin = await ReadingTimeStorage.getTodayReadingMinutes(
        widget.userId,
      );
      final streak = await ReadingTimeStorage.getReadingStreak(widget.userId);
      final goal = await ReadingTimeStorage.getDailyGoalMinutes(widget.userId);
      // Synchronise plutôt que de simplement lire : le serveur porte les
      // créneaux du compte, et cet appareil les reprogramme au passage. C'est
      // ce qui fait qu'une réinstallation ne fait pas disparaître les rappels.
      final creneaux = await RappelsLecture.synchroniser();
      final points = await ReadingTimeStorage.getWeeklyReadingPoints(
        widget.userId,
      );
      final sessions = await ReadingTimeStorage.getRecentSessions(
        widget.userId,
      );

      // Le bilan SERVEUR fait foi dès qu'il a quelque chose à dire — même
      // règle que badges_page et l'accueil. Cet écran ne lisait QUE le
      // compteur local : après une réinstallation ou sur un nouvel appareil,
      // il affichait « 0 minute », série 0, pendant que l'accueil et les
      // badges montraient les vraies valeurs — deux écrans, deux vérités.
      // (L'ancien code appelait même `getReaderStats` et JETAIT le résultat.
      // Cette méthode n'existe plus : elle frappait la route des statistiques
      // par LIVRE avec un identifiant d'utilisateur et ne rendait, en dernier
      // recours, que des zéros factices.)
      //
      // Le comptage local reste tenu en parallèle : il est le seul recours
      // hors ligne, et le graphe des 7 jours comme les sessions récentes,
      // qui n'existent pas dans le bilan, continuent d'en venir.
      final bilan = await _statsService.lireBilan();
      final serveurRenseigne = (bilan?['total'] ?? 0) > 0;

      if (mounted) {
        setState(() {
          _serveurRenseigne = serveurRenseigne;
          _totalMinutes = serveurRenseigne ? bilan!['total']! : totalMin;
          _todayMinutes = serveurRenseigne ? bilan!['jour']! : todayMin;
          _streakDays = serveurRenseigne ? (bilan?['serie'] ?? 0) : streak;
          _dailyGoalMinutes = goal;
          _creneaux = creneaux;
          // La barre du jour dit la MÊME chose que l'anneau d'objectif.
          //
          // Elles se contredisaient : l'anneau lisait le serveur, la barre le
          // compteur de cet appareil. Après une réinstallation, « Encore N min
          // pour valider votre journée » surplombait une barre du jour vide.
          // Les six autres jours restent locaux — le bilan ne porte pas encore
          // le détail par journée, et l'écran le DIT plutôt que de le laisser
          // croire (voir _buildWeeklyChartSection).
          _weeklyPoints = serveurRenseigne
              ? _accorderLeJourAuServeur(points, bilan!['jour'] ?? 0)
              : points;
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

  /// Remplace la barre d'aujourd'hui par le chiffre du serveur.
  ///
  /// Les journées passées ne sont pas dans le bilan (le serveur les calcule
  /// dans `lecture/service.go` sans les renvoyer) : elles restent celles de
  /// l'appareil. Mais la journée en cours, elle, est affichée deux fois sur le
  /// même écran, et deux chiffres différents pour la même journée sont pires
  /// qu'un chiffre incomplet.
  List<DailyReadingPoint> _accorderLeJourAuServeur(
    List<DailyReadingPoint> points,
    int minutesDuJour,
  ) {
    return points
        .map(
          (p) => p.isToday
              ? DailyReadingPoint(
                  dayLabel: p.dayLabel,
                  date: p.date,
                  minutes: minutesDuJour,
                  isToday: true,
                )
              : p,
        )
        .toList();
  }

  Future<void> _updateDailyGoal(int targetMin) async {
    setState(() {
      _dailyGoalMinutes = targetMin;
    });
    await ReadingTimeStorage.setDailyGoalMinutes(widget.userId, targetMin);
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
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusPill,
                        ),
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
                              inactiveColor: AppColors.textHint.withOpacity(
                                0.2,
                              ),
                              onChanged: (val) {
                                setModalState(() {
                                  selectedHours = val.round();
                                  if (selectedHours == 0 && selectedMins == 0) {
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
                              inactiveColor: AppColors.textHint.withOpacity(
                                0.2,
                              ),
                              onChanged: (val) {
                                setModalState(() {
                                  selectedMins = val.round();
                                  if (selectedHours == 0 && selectedMins == 0) {
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
                        final finalMin = (selectedHours * 60) + selectedMins;
                        _updateDailyGoal(finalMin > 0 ? finalMin : 15);
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.onAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppDimensions.radiusPill,
                          ),
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
          ? Center(child: CircularProgressIndicator(color: AppColors.primary))
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
    final formattedTotal = ReadingTimeStorage.formatMinutesFull(_totalMinutes);
    final todayProgress = _dailyGoalMinutes > 0
        ? (_todayMinutes / _dailyGoalMinutes).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryDark, AppColors.primary],
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
                  borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
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
                  borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
                  child: LinearProgressIndicator(
                    value: todayProgress,
                    minHeight: 8,
                    backgroundColor: AppColors.onAccent.withOpacity(0.15),
                    // La barre est posée sur un aplat d'accent : son encre vient
                    // de `onAccent`, atteinte ou non. Le vert de `success` est
                    // réservé à la confirmation ; en décor, il cesse de vouloir
                    // dire quoi que ce soit là où il compte vraiment.
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.onAccent,
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
        border: Border.all(color: AppColors.textPrimary.withOpacity(0.06)),
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
          // Dire d'où vient ce détail plutôt que de le faire passer pour le
          // compte entier. Le bilan du serveur ne porte que le total, la
          // journée et la série ; le découpage par jour est mesuré ici. Sans
          // cette phrase, un lecteur qui vient de réinstaller voit six barres
          // vides sous un total de plusieurs heures et conclut à une perte.
          if (_serveurRenseigne) ...[
            const SizedBox(height: 4),
            Text(
              "Détail mesuré sur cet appareil — votre temps total, lui, suit "
              "votre compte.",
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: AppColors.textHint,
              ),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            height: 120,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: _weeklyPoints.map((point) {
                final heightFactor = (point.minutes / maxMin).clamp(0.05, 1.0);
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
        border: Border.all(color: AppColors.textPrimary.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.tune_rounded,
                    color: AppColors.accentInk,
                    size: 20,
                  ),
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
                  borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
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
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? AppColors.onAccent
                        : AppColors.textPrimary,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusPill,
                    ),
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
                  borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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

  /// Les créneaux de lecture du lecteur.
  ///
  /// L'écran n'offrait qu'une heure unique, la même sept jours sur sept — et
  /// surtout, il ne programmait rien : le code n'appelait que `show()`, un
  /// affichage immédiat. Le lecteur croyait recevoir un rappel à 20 h 30 ; rien
  /// ne partait, jamais.
  ///
  /// On ne lit pas à la même heure un mardi et un dimanche. Chaque créneau
  /// porte donc son heure ET ses jours, et plusieurs peuvent coexister.
  Widget _buildDailyReminderCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(color: AppColors.textPrimary.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(
                    AppDimensions.radiusInner,
                  ),
                ),
                child: Icon(
                  Icons.notifications_active_outlined,
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
                      "Vos créneaux de lecture",
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      _creneaux.isEmpty
                          ? "Aucun rappel programmé"
                          : "${_creneaux.length} créneau(x) programmé(s)",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_creneaux.isEmpty)
            _proposerPremiersCreneaux()
          else
            ..._creneaux.asMap().entries.map(
              (e) => _carteCreneau(e.key, e.value),
            ),

          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _ajouterCreneau,
              icon: Icon(
                Icons.add_rounded,
                size: 18,
                color: AppColors.accentInk,
              ),
              label: Text(
                "Ajouter un créneau",
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accentInk,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Trois départs courants, pour ne pas laisser l'écran vide.
  ///
  /// Un lecteur qui découvre la fonction ne sait pas quoi choisir : proposer
  /// « en semaine », « tous les jours » et « le week-end » évite la page blanche
  /// et dit du même coup ce que l'on peut régler.
  Widget _proposerPremiersCreneaux() {
    final propositions = <String, CreneauLecture>{
      "En semaine à 7h": const CreneauLecture(
        heure: 7,
        minute: 0,
        jours: {1, 2, 3, 4, 5},
      ),
      "Tous les jours à 20h30": const CreneauLecture(
        heure: 20,
        minute: 30,
        jours: {1, 2, 3, 4, 5, 6, 7},
      ),
      "Le week-end à 10h": const CreneauLecture(
        heure: 10,
        minute: 0,
        jours: {6, 7},
      ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Choisissez un moment, ou composez le vôtre :",
          style: GoogleFonts.poppins(
            fontSize: 12.5,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: propositions.entries.map((e) {
            return ActionChip(
              label: Text(
                e.key,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accentInk,
                ),
              ),
              backgroundColor: AppColors.primary.withOpacity(0.12),
              side: BorderSide(color: AppColors.primary.withOpacity(0.3)),
              onPressed: () => _enregistrerCreneaux([..._creneaux, e.value]),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _carteCreneau(int index, CreneauLecture creneau) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.scaffoldBackground,
        borderRadius: BorderRadius.circular(AppDimensions.radiusInner),
        border: Border.all(
          color: creneau.actif
              ? AppColors.primary.withOpacity(0.3)
              : AppColors.textHint.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              InkWell(
                onTap: () => _choisirHeure(index, creneau),
                borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Text(
                    creneau.libelleHeure,
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: creneau.actif
                          ? AppColors.accentInk
                          : AppColors.textHint,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  creneau.libelleJours,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Switch(
                value: creneau.actif,
                onChanged: (v) =>
                    _majCreneau(index, creneau.copyWith(actif: v)),
              ),
              IconButton(
                tooltip: "Supprimer ce créneau",
                icon: Icon(
                  Icons.delete_outline_rounded,
                  size: 20,
                  color: AppColors.textHint,
                ),
                onPressed: () {
                  final restants = [..._creneaux]..removeAt(index);
                  _enregistrerCreneaux(restants);
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (i) {
              final jour = i + 1;
              const noms = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
              final choisi = creneau.jours.contains(jour);
              return GestureDetector(
                onTap: () {
                  final jours = {...creneau.jours};
                  // Un créneau sans aucun jour ne programme rien : on garde
                  // toujours au moins un jour coché plutôt que de laisser une
                  // ligne inerte que le lecteur croirait active.
                  if (choisi && jours.length == 1) return;
                  if (choisi) {
                    jours.remove(jour);
                  } else {
                    jours.add(jour);
                  }
                  _majCreneau(index, creneau.copyWith(jours: jours));
                },
                child: Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: choisi
                        ? AppColors.primary
                        : AppColors.textHint.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    noms[i],
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: choisi
                          ? AppColors.onAccent
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Future<void> _choisirHeure(int index, CreneauLecture creneau) async {
    final choisi = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: creneau.heure, minute: creneau.minute),
    );
    if (choisi == null) return;
    _majCreneau(
      index,
      creneau.copyWith(heure: choisi.hour, minute: choisi.minute),
    );
  }

  /// Le maximum que le compte accepte.
  ///
  /// C'est la borne du serveur (lecture/controller.go : au-delà de vingt
  /// créneaux, la liste entière est refusée par un 400). La refuser ICI plutôt
  /// que de laisser partir la requête change tout : un refus de contenu ne se
  /// rejoue pas, donc le vingt-et-unième créneau serait resté local, puis
  /// aurait disparu au prochain passage sur cet écran — sans un mot.
  static const int _maxCreneaux = 20;

  Future<void> _ajouterCreneau() async {
    if (_creneaux.length >= _maxCreneaux) {
      AppNotifications.showSnackBar(
        context,
        message:
            "Vingt créneaux au maximum — supprimez-en un pour en ajouter un autre",
        isError: true,
      );
      return;
    }
    final choisi = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 20, minute: 30),
    );
    if (choisi == null) return;
    _enregistrerCreneaux([
      ..._creneaux,
      CreneauLecture(
        heure: choisi.hour,
        minute: choisi.minute,
        jours: const {1, 2, 3, 4, 5, 6, 7},
      ),
    ]);
  }

  void _majCreneau(int index, CreneauLecture creneau) {
    final liste = [..._creneaux];
    liste[index] = creneau;
    _enregistrerCreneaux(liste);
  }

  /// Enregistre ET reprogramme : les deux sont indissociables. Un créneau
  /// enregistré sans être programmé est exactement le défaut qu'on corrige.
  ///
  /// Le bandeau vert ne s'affiche que si le COMPTE a suivi.
  ///
  /// Il s'affichait dans tous les cas : `enregistrer` ne rendait rien et ne
  /// savait rien du sort de son envoi au serveur, qui était avalé en silence.
  /// Un lecteur sans réseau lisait « Rappels programmés — 1 créneau » alors
  /// que le compte n'en savait rien, et deux jours plus tard, en wifi, l'écran
  /// lui revenait vide, ses notifications annulées. On dit maintenant ce qui
  /// s'est réellement passé : les créneaux sont bien posés sur CET appareil —
  /// ils sonneront — mais le compte, lui, attend le retour du réseau. Ni vert
  /// ni rouge : rien n'est perdu, rien n'est fini.
  Future<void> _enregistrerCreneaux(List<CreneauLecture> liste) async {
    setState(() => _creneaux = liste);
    final porteAuCompte = await RappelsLecture.enregistrer(liste);
    if (!mounted) return;
    if (!porteAuCompte) {
      AppNotifications.showSnackBar(
        context,
        message: liste.isEmpty
            ? "Rappels désactivés sur cet appareil — le compte sera mis à jour dès le retour du réseau"
            : "Rappels programmés sur cet appareil — le compte sera mis à jour dès le retour du réseau",
      );
      return;
    }
    AppNotifications.showSnackBar(
      context,
      message: liste.isEmpty
          ? "Rappels désactivés"
          : "Rappels programmés — ${liste.length} créneau(x)",
      isSuccess: true,
    );
  }

  Widget _buildRecentSessionsTimeline() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(color: AppColors.textPrimary.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history_rounded, color: AppColors.accentInk, size: 20),
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
                      // Une liste vide au-dessus d'un total de plusieurs
                      // heures se lit comme une perte. Le détail des séances
                      // est tenu sur l'appareil : après une réinstallation il
                      // repart de zéro, sans que le temps du compte bouge.
                      _serveurRenseigne
                          ? "Aucune session enregistrée sur cet appareil"
                          : "Aucune session enregistrée pour l'instant",
                      style: AppTextStyles.bodyFaded16,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _serveurRenseigne
                          ? "Le détail des séances est conservé sur le téléphone où vous lisez ; votre temps total, lui, suit votre compte."
                          : "Ouvrez un livre dans votre bibliothèque pour lancer votre première session !",
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
                final dateStr = DateFormat(
                  'dd MMM à HH:mm',
                  'fr_FR',
                ).format(session.timestamp);
                final durationStr = ReadingTimeStorage.formatMinutes(
                  session.durationMinutes,
                );

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
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusPill,
                        ),
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
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
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
