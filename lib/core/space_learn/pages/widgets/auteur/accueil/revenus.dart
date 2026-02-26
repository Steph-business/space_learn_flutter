import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';

class Revenus extends StatefulWidget {
  const Revenus({super.key});

  @override
  State<Revenus> createState() => _RevenusState();
}

class _RevenusState extends State<Revenus> {
  bool isRevenueSelected = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B), // Dark slate
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
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
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "Total: 1,450 €",
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    "Croissance: +12%",
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
          const SizedBox(height: 30),

          // Chart
          SizedBox(height: 100, child: LineChart(_mainData())),

          const SizedBox(height: 12),

          // X-Axis Labels
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildDateLabel("1 Mai"),
                _buildDateLabel("9 Mai"),
                _buildDateLabel("15 Mai"),
                _buildDateLabel("23 Mai"),
                _buildDateLabel("30 Mai"),
              ],
            ),
          ),

          const SizedBox(height: 24),

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
                            ? const Color(0xFF1E293B)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        "Lectures",
                        style: GoogleFonts.poppins(
                          color: !isRevenueSelected
                              ? Colors.white
                              : Colors.white54,
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
                            ? const Color(0xFF1E293B)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        "Revenus",
                        style: GoogleFonts.poppins(
                          color: isRevenueSelected
                              ? Colors.white
                              : Colors.white54,
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
        color: Colors.white30,
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  LineChartData _mainData() {
    return LineChartData(
      gridData: FlGridData(show: false),
      titlesData: FlTitlesData(show: false),
      borderData: FlBorderData(show: false),
      minX: 0,
      maxX: 14,
      minY: 0,
      maxY: 10,
      lineBarsData: [
        LineChartBarData(
          spots: const [
            FlSpot(0, 2),
            FlSpot(1.5, 4),
            FlSpot(2.8, 3),
            FlSpot(4, 5.5),
            FlSpot(5, 6),
            FlSpot(6.2, 4),
            FlSpot(7.5, 8.5),
            FlSpot(8.5, 4),
            FlSpot(9.5, 6),
            FlSpot(10.5, 5),
            FlSpot(11.5, 7),
            FlSpot(12.5, 6),
            FlSpot(14, 8),
          ],
          isCurved: true,
          color: const Color(0xFF3B82F6), // Blue as in image
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
                const Color(0xFF3B82F6).withOpacity(0.2),
                const Color(0xFF3B82F6).withOpacity(0.0),
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
