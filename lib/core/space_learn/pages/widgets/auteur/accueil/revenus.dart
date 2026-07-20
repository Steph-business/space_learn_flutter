import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:space_learn_flutter/core/space_learn/data/model/book_model.dart';

class Revenus extends StatefulWidget {
  final Map<String, dynamic> stats;
  const Revenus({super.key, required this.stats});

  @override
  State<Revenus> createState() => _RevenusState();
}

class _RevenusState extends State<Revenus> {
  bool isRevenueSelected = true;

  double get totalRevenue => (widget.stats['total_revenue'] ?? 0).toDouble();
  double get totalDownloads => (widget.stats['total_downloads'] ?? 0).toDouble();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground, // Dark slate
        borderRadius: BorderRadius.circular(20),
        
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  "Revenus - 30 Derniers Jours",
                  style: GoogleFonts.poppins(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "Total: ${isRevenueSelected ? totalRevenue.toStringAsFixed(0) + " FCFA" : totalDownloads.toStringAsFixed(0)}",
                    style: GoogleFonts.poppins(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    "", // Growth hidden until backend supports it
                    style: GoogleFonts.poppins(
                      color: Colors.green,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 30),

          // Chart
          SizedBox(height: 100, child: LineChart(_mainData())),

          SizedBox(height: 12),

          // X-Axis Labels
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: _buildMonthLabels(),
            ),
          ),

          SizedBox(height: 24),

          // Toggle Button
          Container(
            height: 42,
            decoration: BoxDecoration(
              color: const Color(
                0xFF0F172A,
              ), // Even darker background for toggle
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => isRevenueSelected = false),
                    child: Container(
                      decoration: BoxDecoration(
                        color: !isRevenueSelected
                            ? AppColors.cardBackground
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        "Lectures",
                        style: GoogleFonts.poppins(
                          color: !isRevenueSelected
                              ? Colors.white
                              : AppColors.textHint,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => isRevenueSelected = true),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isRevenueSelected
                            ? AppColors.cardBackground
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        "Revenus",
                        style: GoogleFonts.poppins(
                          color: isRevenueSelected
                              ? Colors.white
                              : AppColors.textHint,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
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

  List<Widget> _buildMonthLabels() {
    // Generate 5 labels for the X-axis from the 12 months data
    // We will just show Jan, Mar, Jun, Sep, Dec as an example to fit the space
    final List<String> months = ["Jan", "Fév", "Mar", "Avr", "Mai", "Juin", "Juil", "Août", "Sep", "Oct", "Nov", "Déc"];
    return [
      _buildDateLabel(months[0]),
      _buildDateLabel(months[3]),
      _buildDateLabel(months[6]),
      _buildDateLabel(months[9]),
      _buildDateLabel(months[11]),
    ];
  }

  LineChartData _mainData() {
    List<dynamic> rawData = [];
    if (widget.stats['monthly_revenue'] != null) {
      rawData = widget.stats['monthly_revenue'];
    }

    // Default 12 zeros if data is empty or missing
    List<double> monthlyData = List.filled(12, 0.0);
    for (int i = 0; i < rawData.length && i < 12; i++) {
      if (rawData[i] is num) {
        monthlyData[i] = (rawData[i] as num).toDouble();
      }
    }

    // Since we don't have monthly_downloads yet from backend, 
    // we'll derive a proxy curve for 'Lectures' if not revenue selected.
    if (!isRevenueSelected) {
      monthlyData = monthlyData.map((val) => val > 0 ? (val / 1500) : 0.0).toList(); // Approximation
    }

    double maxY = monthlyData.isEmpty ? 10 : monthlyData.reduce((a, b) => a > b ? a : b);
    if (maxY == 0) maxY = 10;
    
    // Add 20% padding to top
    maxY = maxY * 1.2;

    List<FlSpot> spots = [];
    for (int i = 0; i < 12; i++) {
      spots.add(FlSpot(i.toDouble(), monthlyData[i]));
    }

    return LineChartData(
      gridData: FlGridData(show: false),
      titlesData: FlTitlesData(show: false),
      borderData: FlBorderData(show: false),
      minX: 0,
      maxX: 11,
      minY: 0,
      maxY: maxY,
      lineBarsData: [
        LineChartBarData(
          spots: spots.isEmpty ? [FlSpot(0, 0)] : spots,
          isCurved: true,
          color: AppColors.secondary, // Blue as in image
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) =>
                FlDotCirclePainter(
                  radius: 4,
                  color: Colors.orange, // Orange dots as in image
                  strokeWidth: 2,
                  strokeColor: Colors.white,
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