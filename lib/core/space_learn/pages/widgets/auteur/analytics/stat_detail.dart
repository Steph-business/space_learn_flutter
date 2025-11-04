import 'package:flutter/material.dart';

// Widget 1: Statistiques détaillées
class DetailedStatistics extends StatelessWidget {
  const DetailedStatistics({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
              const Text(
                'Statistiques détaillées',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
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
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  value: '2.3%',
                  label: 'Taux\nconversion',
                  color: Colors.blue.shade50,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  value: '156',
                  label: 'Nouveaux\nlecteurs',
                  color: Colors.purple.shade50,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  value: '89%',
                  label: 'Satisfaction',
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
                  value: '4.2min',
                  label: 'Temps\nlecture',
                  color: Colors.green.shade50,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  value: '67%',
                  label: 'Lecteurs\nrécurrents',
                  color: Colors.orange.shade50,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  value: '€0.37',
                  label: 'Revenu par\nvue',
                  color: Colors.teal.shade50,
                ),
              ),
            ],
          ),
        ],
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
class GrowthIndicatorsWidget extends StatelessWidget {
  const GrowthIndicatorsWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
              const Text(
                'Indicateurs de croissance',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _GrowthItem(
            label: 'Nouveaux abonnés',
            value: '+23',
            color: Colors.green,
          ),
          const SizedBox(height: 16),
          _GrowthItem(
            label: 'Commentaires reçus',
            value: '+47',
            color: Colors.green,
          ),
        ],
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
  const StatsExamplePage({Key? key}) : super(key: key);

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
