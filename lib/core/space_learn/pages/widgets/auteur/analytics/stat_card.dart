import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class StatistiquesWidget extends StatefulWidget {
  const StatistiquesWidget({super.key});

  @override
  State<StatistiquesWidget> createState() => _StatistiquesWidgetState();
}

class _StatistiquesWidgetState extends State<StatistiquesWidget> {
  int _selectedIndex = 0;
  final List<String> filters = ["7 jours", "30 jours", "3 mois", "1 an"];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 🔶 Barre de filtres
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.orange.shade700,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(20),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(filters.length, (index) {
              final isSelected = _selectedIndex == index;
              return GestureDetector(
                onTap: () => setState(() => _selectedIndex = index),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withOpacity(0.3)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    filters[index],
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),

        // 📊 Liste de cartes statistiques
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: const [
                  Expanded(
                    child: StatCard(
                      icon: FontAwesomeIcons.sackDollar,
                      value: "€1,285",
                      label: "Revenus totaux",
                      percent: "+12%",
                      change: "+€127",
                      color: Colors.green,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: StatCard(
                      icon: FontAwesomeIcons.eye,
                      value: "15,247",
                      label: "Vues totales",
                      percent: "+8%",
                      change: "+1,156",
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: const [
                  Expanded(
                    child: StatCard(
                      icon: FontAwesomeIcons.download,
                      value: "3,456",
                      label: "Téléchargements",
                      percent: "+15%",
                      change: "+456",
                      color: Colors.orange,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: StatCard(
                      icon: FontAwesomeIcons.star,
                      value: "4.7",
                      label: "Note moyenne",
                      percent: "+0.2",
                      change: "",
                      color: Colors.amber,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// 💠 Widget de carte individuelle
class StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final String percent;
  final String change;
  final Color color;

  const StatCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    required this.percent,
    required this.change,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                percent,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 4),
              if (change.isNotEmpty)
                Text("($change)", style: TextStyle(color: color, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}
