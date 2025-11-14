import 'package:flutter/material.dart';

import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../principales/lecteur/stat_detail.dart';

class StatsSection extends StatelessWidget {
  const StatsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => Scaffold(
              backgroundColor: const Color.fromARGB(255, 250, 249, 246),
              appBar: AppBar(
                backgroundColor: const Color.fromARGB(255, 33, 32, 32),
                title: const Text(
                  'Statistiques Détaillées',
                  style: TextStyle(color: Colors.white),
                ),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              body: const SingleChildScrollView(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    DetailedStatistics(),
                    SizedBox(height: 16),
                    GrowthIndicatorsWidget(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: const [
          _StatItem(
            icon: FontAwesomeIcons.bookOpen,
            value: "12",
            label: "Livres lus",
            color: Colors.blue,
          ),
          _StatItem(
            icon: FontAwesomeIcons.hourglassHalf,
            value: "34h",
            label: "Temps total",
            color: Colors.green,
          ),
          _StatItem(
            icon: FontAwesomeIcons.trophy,
            value: "5",
            label: "Objectifs",
            color: Colors.orange,
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }
}
