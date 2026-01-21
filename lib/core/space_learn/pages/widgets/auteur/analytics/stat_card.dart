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
  bool _isLoading = false;

  // Dynamic data based on selected period
  Map<String, dynamic> get _currentData {
    switch (_selectedIndex) {
      case 0: // 7 jours
        return {
          'revenue': {'value': '1,285 FCFA', 'change': '+127 FCFA', 'percent': '+12%'},
          'views': {'value': '15,247', 'change': '+1,156', 'percent': '+8%'},
          'downloads': {'value': '3,456', 'change': '+456', 'percent': '+15%'},
          'rating': {'value': '4.7', 'change': '', 'percent': '+0.2'},
        };
      case 1: // 30 jours
        return {
          'revenue': {'value': '4,850 FCFA', 'change': '+892 FCFA', 'percent': '+23%'},
          'views': {'value': '58,750', 'change': '+8,456', 'percent': '+17%'},
          'downloads': {
            'value': '12,450',
            'change': '+2,156',
            'percent': '+21%',
          },
          'rating': {'value': '4.6', 'change': '', 'percent': '+0.1'},
        };
      case 2: // 3 mois
        return {
          'revenue': {
            'value': '15,200 FCFA',
            'change': '+2,450 FCFA',
            'percent': '+19%',
          },
          'views': {'value': '185,000', 'change': '+28,750', 'percent': '+18%'},
          'downloads': {
            'value': '38,750',
            'change': '+8,456',
            'percent': '+28%',
          },
          'rating': {'value': '4.5', 'change': '', 'percent': '+0.3'},
        };
      case 3: // 1 an
        return {
          'revenue': {
            'value': '58,750 FCFA',
            'change': '+12,850 FCFA',
            'percent': '+28%',
          },
          'views': {
            'value': '725,000',
            'change': '+125,000',
            'percent': '+21%',
          },
          'downloads': {
            'value': '152,500',
            'change': '+35,750',
            'percent': '+31%',
          },
          'rating': {'value': '4.4', 'change': '', 'percent': '+0.4'},
        };
      default:
        return {
          'revenue': {'value': '0 FCFA', 'change': '', 'percent': '0%'},
          'views': {'value': '0', 'change': '', 'percent': '0%'},
          'downloads': {'value': '0', 'change': '', 'percent': '0%'},
          'rating': {'value': '0', 'change': '', 'percent': '0%'},
        };
    }
  }

  void _onFilterChanged(int index) async {
    setState(() {
      _isLoading = true;
      _selectedIndex = index;
    });

    // Simulate loading delay
    await Future.delayed(const Duration(milliseconds: 500));

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = _currentData;

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
                onTap: () => _onFilterChanged(index),
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
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                  ),
                )
              : Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: StatCard(
                            icon: FontAwesomeIcons.sackDollar,
                            value: data['revenue']['value'],
                            label: "Revenus totaux",
                            percent: data['revenue']['percent'],
                            change: data['revenue']['change'],
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: StatCard(
                            icon: FontAwesomeIcons.eye,
                            value: data['views']['value'],
                            label: "Vues totales",
                            percent: data['views']['percent'],
                            change: data['views']['change'],
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: StatCard(
                            icon: FontAwesomeIcons.download,
                            value: data['downloads']['value'],
                            label: "Téléchargements",
                            percent: data['downloads']['percent'],
                            change: data['downloads']['change'],
                            color: Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: StatCard(
                            icon: FontAwesomeIcons.star,
                            value: data['rating']['value'],
                            label: "Note moyenne",
                            percent: data['rating']['percent'],
                            change: data['rating']['change'],
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
          _buildValueWidget(),
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

  Widget _buildValueWidget() {
    if (value.contains('FCFA')) {
      final parts = value.split(' FCFA');
      return Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '${parts[0]} ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const TextSpan(
              text: 'FCFA',
              style: TextStyle(fontWeight: FontWeight.normal),
            ),
          ],
          style: const TextStyle(fontSize: 20, color: Colors.black),
        ),
      );
    }
    return Text(
      value,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
    );
  }
}
