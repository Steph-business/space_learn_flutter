import 'package:flutter/material.dart';

import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/authorStatsService.dart';
import 'package:space_learn_flutter/core/utils/tokenStorage.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/authServices.dart';

class StatistiquesWidget extends StatefulWidget {
  const StatistiquesWidget({super.key});

  @override
  State<StatistiquesWidget> createState() => _StatistiquesWidgetState();
}

class _StatistiquesWidgetState extends State<StatistiquesWidget> {
  int _selectedIndex = 0;
  final List<String> filters = ["7 jours", "30 jours", "3 mois", "1 an"];
  bool _isLoading = false;

  final AuthorStatsService _authorStatsService = AuthorStatsService();
  final AuthService _authService = AuthService();
  Map<String, dynamic> _fetchedData = {};

  @override
  void initState() {
    super.initState();
    _onFilterChanged(0);
  }

  // Dynamic data based on selected period
  Map<String, dynamic> get _currentData {
    if (_fetchedData.isNotEmpty) {
      return {
        'revenue': {
          'value': '${_fetchedData['revenue'] ?? 0} FCFA',
          'change': '${_fetchedData['revenue_change'] ?? 0} FCFA',
          'percent': '${_fetchedData['revenue_percent'] ?? 0}%'
        },
        'views': {
          'value': '${_fetchedData['views'] ?? 0}',
          'change': '${_fetchedData['views_change'] ?? 0}',
          'percent': '${_fetchedData['views_percent'] ?? 0}%'
        },
        'downloads': {
          'value': '${_fetchedData['downloads'] ?? 0}',
          'change': '${_fetchedData['downloads_change'] ?? 0}',
          'percent': '${_fetchedData['downloads_percent'] ?? 0}%'
        },
        'rating': {
          'value': '${_fetchedData['rating'] ?? 0.0}',
          'change': '',
          'percent': '${_fetchedData['rating_change'] ?? 0}'
        },
      };
    }

    // Fallback to zeros if no data
    return {
      'revenue': {'value': '0 FCFA', 'change': '', 'percent': '0%'},
      'views': {'value': '0', 'change': '', 'percent': '0%'},
      'downloads': {'value': '0', 'change': '', 'percent': '0%'},
      'rating': {'value': '0', 'change': '', 'percent': '0%'},
    };
  }

  void _onFilterChanged(int index) async {
    setState(() {
      _isLoading = true;
      _selectedIndex = index;
    });

    try {
      final token = await TokenStorage.getToken();
      if (token != null) {
        final user = await _authService.getUser(token);
        if (user != null) {
           final period = ["7d", "30d", "3m", "1y"][index];
           final data = await _authorStatsService.getAuthorStats(user.id, period);
           if (mounted) {
             setState(() {
               _fetchedData = data;
             });
           }
        }
      }
    } catch (e) {
      print("Error loading stats: $e");
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
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
