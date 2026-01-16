import 'package:flutter/material.dart';

// Widget 1: Statistiques détaillées
class DetailedStatistics extends StatefulWidget {
  const DetailedStatistics({super.key});

  @override
  State<DetailedStatistics> createState() => _DetailedStatisticsState();
}

class _DetailedStatisticsState extends State<DetailedStatistics> {
  int _selectedPeriod = 0; // 0: 7 jours, 1: 30 jours, 2: 3 mois, 3: 1 an
  bool _isLoading = false;

  Map<String, dynamic> get _currentMetrics {
    switch (_selectedPeriod) {
      case 0: // 7 jours
        return {
          'conversion': {'value': '2.3%', 'label': 'Taux\nconversion'},
          'readers': {'value': '156', 'label': 'Nouveaux\nlecteurs'},
          'satisfaction': {'value': '89%', 'label': 'Satisfaction'},
          'readingTime': {'value': '4.2min', 'label': 'Temps\nlecture'},
          'recurring': {'value': '67%', 'label': 'Lecteurs\nrécurrents'},
          'revenuePerView': {'value': '€0.37', 'label': 'Revenu par\nvue'},
        };
      case 1: // 30 jours
        return {
          'conversion': {'value': '2.8%', 'label': 'Taux\nconversion'},
          'readers': {'value': '623', 'label': 'Nouveaux\nlecteurs'},
          'satisfaction': {'value': '87%', 'label': 'Satisfaction'},
          'readingTime': {'value': '4.5min', 'label': 'Temps\nlecture'},
          'recurring': {'value': '72%', 'label': 'Lecteurs\nrécurrents'},
          'revenuePerView': {'value': '€0.42', 'label': 'Revenu par\nvue'},
        };
      case 2: // 3 mois
        return {
          'conversion': {'value': '3.2%', 'label': 'Taux\nconversion'},
          'readers': {'value': '1,856', 'label': 'Nouveaux\nlecteurs'},
          'satisfaction': {'value': '85%', 'label': 'Satisfaction'},
          'readingTime': {'value': '4.8min', 'label': 'Temps\nlecture'},
          'recurring': {'value': '75%', 'label': 'Lecteurs\nrécurrents'},
          'revenuePerView': {'value': '€0.45', 'label': 'Revenu par\nvue'},
        };
      case 3: // 1 an
        return {
          'conversion': {'value': '3.8%', 'label': 'Taux\nconversion'},
          'readers': {'value': '7,256', 'label': 'Nouveaux\nlecteurs'},
          'satisfaction': {'value': '82%', 'label': 'Satisfaction'},
          'readingTime': {'value': '5.2min', 'label': 'Temps\nlecture'},
          'recurring': {'value': '78%', 'label': 'Lecteurs\nrécurrents'},
          'revenuePerView': {'value': '€0.48', 'label': 'Revenu par\nvue'},
        };
      default:
        return {
          'conversion': {'value': '0%', 'label': 'Taux\nconversion'},
          'readers': {'value': '0', 'label': 'Nouveaux\nlecteurs'},
          'satisfaction': {'value': '0%', 'label': 'Satisfaction'},
          'readingTime': {'value': '0min', 'label': 'Temps\nlecture'},
          'recurring': {'value': '0%', 'label': 'Lecteurs\nrécurrents'},
          'revenuePerView': {'value': '€0', 'label': 'Revenu par\nvue'},
        };
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
    final metrics = _currentMetrics;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.blue, Colors.purple, Colors.pink],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.bar_chart,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Statistiques détaillées',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              // Period selector
              Row(
                children: [
                  _buildPeriodButton('7j', 0),
                  const SizedBox(width: 4),
                  _buildPeriodButton('30j', 1),
                  const SizedBox(width: 4),
                  _buildPeriodButton('3m', 2),
                  const SizedBox(width: 4),
                  _buildPeriodButton('1a', 3),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Métriques avancées',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),
          _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                )
              : Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _MetricCard(
                            value: metrics['conversion']['value'],
                            label: metrics['conversion']['label'],
                            color: Colors.blue.shade50,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _MetricCard(
                            value: metrics['readers']['value'],
                            label: metrics['readers']['label'],
                            color: Colors.purple.shade50,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _MetricCard(
                            value: metrics['satisfaction']['value'],
                            label: metrics['satisfaction']['label'],
                            color: Colors.pink.shade50,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _MetricCard(
                            value: metrics['readingTime']['value'],
                            label: metrics['readingTime']['label'],
                            color: Colors.green.shade50,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _MetricCard(
                            value: metrics['recurring']['value'],
                            label: metrics['recurring']['label'],
                            color: Colors.orange.shade50,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _MetricCard(
                            value: metrics['revenuePerView']['value'],
                            label: metrics['revenuePerView']['label'],
                            color: Colors.teal.shade50,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildPeriodButton(String label, int period) {
    return GestureDetector(
      onTap: () => _onPeriodChanged(period),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _selectedPeriod == period ? Colors.blue : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.blue),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: _selectedPeriod == period ? Colors.white : Colors.blue,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _MetricCard({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

// Widget 2: Indicateurs de croissance
class GrowthIndicatorsWidget extends StatefulWidget {
  const GrowthIndicatorsWidget({super.key});

  @override
  State<GrowthIndicatorsWidget> createState() => _GrowthIndicatorsWidgetState();
}

class _GrowthIndicatorsWidgetState extends State<GrowthIndicatorsWidget> {
  int _selectedPeriod = 0; // 0: 7 jours, 1: 30 jours, 2: 3 mois, 3: 1 an
  bool _isLoading = false;

  List<Map<String, dynamic>> get _currentGrowthItems {
    switch (_selectedPeriod) {
      case 0: // 7 jours
        return [
          {'label': 'Nouveaux abonnés', 'value': '+23', 'color': Colors.green},
          {
            'label': 'Commentaires reçus',
            'value': '+47',
            'color': Colors.green,
          },
          {'label': 'Vues totales', 'value': '+156', 'color': Colors.blue},
        ];
      case 1: // 30 jours
        return [
          {'label': 'Nouveaux abonnés', 'value': '+89', 'color': Colors.green},
          {
            'label': 'Commentaires reçus',
            'value': '+234',
            'color': Colors.green,
          },
          {'label': 'Vues totales', 'value': '+1,245', 'color': Colors.blue},
        ];
      case 2: // 3 mois
        return [
          {'label': 'Nouveaux abonnés', 'value': '+345', 'color': Colors.green},
          {
            'label': 'Commentaires reçus',
            'value': '+1,056',
            'color': Colors.green,
          },
          {'label': 'Vues totales', 'value': '+5,678', 'color': Colors.blue},
        ];
      case 3: // 1 an
        return [
          {
            'label': 'Nouveaux abonnés',
            'value': '+1,234',
            'color': Colors.green,
          },
          {
            'label': 'Commentaires reçus',
            'value': '+4,567',
            'color': Colors.green,
          },
          {'label': 'Vues totales', 'value': '+23,456', 'color': Colors.blue},
        ];
      default:
        return [
          {'label': 'Nouveaux abonnés', 'value': '+0', 'color': Colors.green},
          {'label': 'Commentaires reçus', 'value': '+0', 'color': Colors.green},
          {'label': 'Vues totales', 'value': '+0', 'color': Colors.blue},
        ];
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
    final growthItems = _currentGrowthItems;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.trending_up,
                  color: Colors.blue.shade700,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Indicateurs de croissance',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              // Period selector
              Row(
                children: [
                  _buildPeriodButton('7j', 0),
                  const SizedBox(width: 4),
                  _buildPeriodButton('30j', 1),
                  const SizedBox(width: 4),
                  _buildPeriodButton('3m', 2),
                  const SizedBox(width: 4),
                  _buildPeriodButton('1a', 3),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                )
              : Column(
                  children: growthItems.map((item) {
                    return Column(
                      children: [
                        _GrowthItem(
                          label: item['label'],
                          value: item['value'],
                          color: item['color'],
                        ),
                        const SizedBox(height: 16),
                      ],
                    );
                  }).toList(),
                ),
        ],
      ),
    );
  }

  Widget _buildPeriodButton(String label, int period) {
    return GestureDetector(
      onTap: () => _onPeriodChanged(period),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _selectedPeriod == period ? Colors.blue : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.blue),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: _selectedPeriod == period ? Colors.white : Colors.blue,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _GrowthItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _GrowthItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
          Row(
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.arrow_upward, color: color, size: 18),
            ],
          ),
        ],
      ),
    );
  }
}

// Exemple d'utilisation
class StatsExamplePage extends StatelessWidget {
  const StatsExamplePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Statistiques'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: const [
            DetailedStatistics(),
            SizedBox(height: 16),
            GrowthIndicatorsWidget(),
          ],
        ),
      ),
    );
  }
}
