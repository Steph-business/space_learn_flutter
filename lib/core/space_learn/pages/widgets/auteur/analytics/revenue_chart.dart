import 'package:flutter/material.dart';

import 'package:fl_chart/fl_chart.dart';

class RevenueChart extends StatefulWidget {
  const RevenueChart({super.key});

  @override
  State<RevenueChart> createState() => _RevenueChartState();
}

class _RevenueChartState extends State<RevenueChart> {
  int _selectedPeriod = 0; // 0: 7 jours, 1: 30 jours, 2: 3 mois, 3: 1 an
  bool _isLoading = false;

  List<double> get _chartData {
    switch (_selectedPeriod) {
      case 0: // 7 jours
        return [3.0, 5.5, 4.0, 7.0, 6.0, 8.0, 7.5];
      case 1: // 30 jours
        return [12.0, 15.5, 14.0, 17.0, 16.0, 18.0, 17.5, 15.0];
      case 2: // 3 mois
        return [
          45.0,
          52.5,
          48.0,
          55.0,
          50.0,
          58.0,
          56.5,
          52.0,
          48.0,
          55.0,
          50.0,
          58.0,
        ];
      case 3: // 1 an
        return [
          180.0,
          195.5,
          185.0,
          210.0,
          205.0,
          225.0,
          220.5,
          215.0,
          200.0,
          218.0,
          210.0,
          230.0,
        ];
      default:
        return [3.0, 5.5, 4.0, 7.0, 6.0, 8.0, 7.5];
    }
  }

  List<String> get _bottomLabels {
    switch (_selectedPeriod) {
      case 0: // 7 jours
        return ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
      case 1: // 30 jours
        return ['S1', 'S2', 'S3', 'S4'];
      case 2: // 3 mois
        return ['M1', 'M2', 'M3'];
      case 3: // 1 an
        return [
          'Jan',
          'Fév',
          'Mar',
          'Avr',
          'Mai',
          'Jun',
          'Jul',
          'Aoû',
          'Sep',
          'Oct',
          'Nov',
          'Déc',
        ];
      default:
        return ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    }
  }

  void _onPeriodChanged(int period) async {
    setState(() {
      _isLoading = true;
      _selectedPeriod = period;
    });

    // Simulate loading delay
    await Future.delayed(const Duration(milliseconds: 500));

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = _chartData;
    final labels = _bottomLabels;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Period selector
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _PeriodButton(
                label: '7j',
                isSelected: _selectedPeriod == 0,
                onTap: () => _onPeriodChanged(0),
              ),
              const SizedBox(width: 8),
              _PeriodButton(
                label: '30j',
                isSelected: _selectedPeriod == 1,
                onTap: () => _onPeriodChanged(1),
              ),
              const SizedBox(width: 8),
              _PeriodButton(
                label: '3m',
                isSelected: _selectedPeriod == 2,
                onTap: () => _onPeriodChanged(2),
              ),
              const SizedBox(width: 8),
              _PeriodButton(
                label: '1a',
                isSelected: _selectedPeriod == 3,
                onTap: () => _onPeriodChanged(3),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Chart
          SizedBox(
            height: 180,
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                    ),
                  )
                : BarChart(
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
                              final index = value.toInt();
                              if (index >= 0 && index < labels.length) {
                                return SideTitleWidget(
                                  axisSide: AxisSide.bottom,
                                  child: Text(
                                    labels[index],
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                      ),
                      barGroups: data.asMap().entries.map((e) {
                        return BarChartGroupData(
                          x: e.key,
                          barRods: [
                            BarChartRodData(
                              toY: e.value,
                              color: Colors.orange,
                              width: 16,
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _PeriodButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _PeriodButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.orange : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.orange,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
