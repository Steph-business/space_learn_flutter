import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class RevenueChart extends StatelessWidget {
  const RevenueChart({super.key});

  @override
  Widget build(BuildContext context) {
    final data = [3.0, 5.5, 4.0, 7.0, 6.0, 8.0, 7.5, 5.0];

    return Container(
      height: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: BarChart(
        BarChartData(
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final week = "S${value.toInt() + 1}";
                  return SideTitleWidget(
                    axisSide: AxisSide.bottom,
                    child: Text(week, style: const TextStyle(fontSize: 10)),
                  );
                },
              ),
            ),
          ),
          barGroups: data.asMap().entries.map((e) {
            return BarChartGroupData(
              x: e.key,
              barRods: [
                BarChartRodData(toY: e.value, color: Colors.orange, width: 16),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
