import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/themes/widgets/app_card.dart';
import 'package:space_learn_flutter/core/themes/widgets/app_segmented_control.dart';
import 'package:flutter/material.dart';
import 'package:space_learn_flutter/core/themes/app_dimensions.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/authorStatsService.dart';
import 'package:space_learn_flutter/core/utils/app_notifications.dart';
import 'package:space_learn_flutter/core/utils/message_erreur.dart';

class PeriodOption {
  final String key;
  final String label;
  final String fullLabel;

  const PeriodOption({
    required this.key,
    required this.label,
    required this.fullLabel,
  });
}

class Revenus extends StatefulWidget {
  final Map<String, dynamic> stats;
  final String? authorId;
  final ValueChanged<String>? onPeriodChanged;

  const Revenus({
    super.key,
    required this.stats,
    this.authorId,
    this.onPeriodChanged,
  });

  @override
  State<Revenus> createState() => _RevenusState();
}

class _RevenusState extends State<Revenus> {
  bool isRevenueSelected = true;
  String _selectedPeriodKey = '30d';
  bool _isLoadingPeriodData = false;
  Map<String, dynamic>? _customPeriodStats;
  final AuthorStatsService _authorStatsService = AuthorStatsService();

  static const List<PeriodOption> _periods = [
    PeriodOption(key: '7d', label: 'Semaine', fullLabel: 'Cette Semaine'),
    PeriodOption(key: '30d', label: 'Mois', fullLabel: 'Ce Mois'),
    PeriodOption(key: '1y', label: 'Année', fullLabel: 'Cette Année'),
  ];

  PeriodOption get _currentPeriod => _periods.firstWhere(
    (p) => p.key == _selectedPeriodKey,
    orElse: () => _periods[1],
  );

  Map<String, dynamic> get activeStats => _customPeriodStats ?? widget.stats;

  double get totalRevenue => (activeStats['total_revenue'] ?? 0).toDouble();
  double get totalDownloads => (activeStats['total_downloads'] ?? 0).toDouble();

  @override
  void didUpdateWidget(Revenus oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.stats != oldWidget.stats && _customPeriodStats == null) {
      setState(() {});
    }
  }

  Future<void> _handlePeriodChange(String periodKey) async {
    if (_selectedPeriodKey == periodKey) return;

    setState(() {
      _selectedPeriodKey = periodKey;
      _isLoadingPeriodData = true;
    });

    widget.onPeriodChanged?.call(periodKey);

    if (widget.authorId != null && widget.authorId!.isNotEmpty) {
      try {
        final newStats = await _authorStatsService.getAuthorStats(
          widget.authorId!,
          periodKey,
        );
        if (mounted) {
          setState(() {
            _customPeriodStats = newStats.isNotEmpty ? newStats : null;
            _isLoadingPeriodData = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoadingPeriodData = false);
          // Sans ce message, changer de période sur un appel refusé laissait
          // les chiffres de la période précédente sous le nouveau libellé :
          // l'auteur lisait « ce mois-ci » au-dessus des montants de l'an
          // dernier.
          AppNotifications.showSnackBar(
            context,
            message: messageLisible(
              e,
              repli: "Les chiffres de cette période sont indisponibles.",
            ),
            isError: true,
          );
        }
      }
    } else {
      if (mounted) {
        setState(() => _isLoadingPeriodData = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    AppColors.suivreLeTheme(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Header: Title & Period Dropdown Selector + Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left Column: Main Title & Dropdown Pill
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isRevenueSelected ? "Revenus" : "Lectures",
                    style: GoogleFonts.poppins(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Dropdown Selector (PopupMenuButton)
                  PopupMenuButton<String>(
                    onSelected: (String periodKey) =>
                        _handlePeriodChange(periodKey),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusInner,
                      ),
                    ),
                    color: AppColors.cardBackground,
                    elevation: 6,
                    itemBuilder: (BuildContext context) {
                      return _periods.map((PeriodOption option) {
                        final isSelected = option.key == _selectedPeriodKey;
                        return PopupMenuItem<String>(
                          value: option.key,
                          child: Row(
                            children: [
                              Text(
                                option.label,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w400,
                                  color: isSelected
                                      ? AppColors.accentInk
                                      : AppColors.textPrimary,
                                ),
                              ),
                              if (isSelected) ...[
                                const Spacer(),
                                Icon(
                                  Icons.check_rounded,
                                  size: 18,
                                  color: AppColors.accentInk,
                                ),
                              ],
                            ],
                          ),
                        );
                      }).toList();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.scaffoldBackground,
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusCard,
                        ),
                        border: Border.all(
                          color: AppColors.accentInk.withOpacity(0.3),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _currentPeriod.label,
                            style: GoogleFonts.poppins(
                              color: AppColors.accentInk,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 18,
                            color: AppColors.accentInk,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Right Column: Total Amount
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "Total (${_currentPeriod.label})",
                    style: GoogleFonts.poppins(
                      color: AppColors.textHint,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isRevenueSelected
                        ? '${totalRevenue.toStringAsFixed(0)} FCFA'
                        : totalDownloads.toStringAsFixed(0),
                    style: GoogleFonts.poppins(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 28),

          // Chart Section with loader overlay
          SizedBox(
            height: 120,
            child: Stack(
              children: [
                LineChart(_buildChartData()),
                if (_isLoadingPeriodData)
                  Positioned.fill(
                    child: Container(
                      color: AppColors.cardBackground.withOpacity(0.6),
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.accentInk,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // X-Axis Labels
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: _buildXAxisLabels(),
            ),
          ),

          const SizedBox(height: 24),

          // Selector Lectures / Revenus
          AppSegmentedControl(
            labels: const ["Lectures", "Revenus"],
            selectedIndex: isRevenueSelected ? 1 : 0,
            onChanged: (index) =>
                setState(() => isRevenueSelected = index == 1),
          ),
        ],
      ),
    );
  }

  Widget _buildDateLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.poppins(
        color: AppColors.textHint,
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  List<Widget> _buildXAxisLabels() {
    switch (_selectedPeriodKey) {
      case '7d':
        return [
          _buildDateLabel("Lun"),
          _buildDateLabel("Mar"),
          _buildDateLabel("Jeu"),
          _buildDateLabel("Sam"),
          _buildDateLabel("Dim"),
        ];
      case '30d':
        return [
          _buildDateLabel("Sem 1"),
          _buildDateLabel("Sem 2"),
          _buildDateLabel("Sem 3"),
          _buildDateLabel("Sem 4"),
        ];
      case '1y':
      default:
        final List<String> months = [
          "Jan",
          "Fév",
          "Mar",
          "Avr",
          "Mai",
          "Juin",
          "Juil",
          "Août",
          "Sep",
          "Oct",
          "Nov",
          "Déc",
        ];
        return [
          _buildDateLabel(months[0]),
          _buildDateLabel(months[3]),
          _buildDateLabel(months[6]),
          _buildDateLabel(months[9]),
          _buildDateLabel(months[11]),
        ];
    }
  }

  LineChartData _buildChartData() {
    List<dynamic> rawData = [];
    if (activeStats['monthly_revenue'] != null) {
      rawData = activeStats['monthly_revenue'];
    } else if (activeStats['period_revenue'] != null) {
      rawData = activeStats['period_revenue'];
    }

    int pointCount = 12;
    if (_selectedPeriodKey == '7d') pointCount = 7;
    if (_selectedPeriodKey == '30d') pointCount = 4;

    List<double> chartValues = List.filled(pointCount, 0.0);
    for (int i = 0; i < rawData.length && i < pointCount; i++) {
      if (rawData[i] is num) {
        chartValues[i] = (rawData[i] as num).toDouble();
      }
    }

    if (!isRevenueSelected) {
      chartValues = chartValues
          .map((val) => val > 0 ? (val / 1500) : 0.0)
          .toList();
    }

    double maxY = chartValues.isEmpty
        ? 10
        : chartValues.reduce((a, b) => a > b ? a : b);
    if (maxY == 0) maxY = 10;
    maxY = maxY * 1.2;

    List<FlSpot> spots = [];
    for (int i = 0; i < pointCount; i++) {
      spots.add(FlSpot(i.toDouble(), chartValues[i]));
    }

    return LineChartData(
      gridData: const FlGridData(show: false),
      titlesData: const FlTitlesData(show: false),
      borderData: FlBorderData(show: false),
      minX: 0,
      maxX: (pointCount - 1).toDouble(),
      minY: 0,
      maxY: maxY,
      lineBarsData: [
        LineChartBarData(
          spots: spots.isEmpty ? [const FlSpot(0, 0)] : spots,
          isCurved: true,
          color: AppColors.accentInk,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) =>
                FlDotCirclePainter(
                  radius: 4,
                  color: AppColors.accentInk,
                  strokeWidth: 2,
                  strokeColor: AppColors.cardBackground,
                ),
          ),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: [
                AppColors.secondary.withOpacity(0.2),
                AppColors.secondary.withOpacity(0.0),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ],
    );
  }
}
