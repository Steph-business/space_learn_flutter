import 'package:flutter/material.dart';
import '../../../../../themes/app_colors.dart';

class StatsSection extends StatelessWidget {
  const StatsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color.fromARGB(255, 253, 201, 134),
            const Color.fromARGB(255, 253, 210, 154),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Première ligne : 2 statistiques
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.book_outlined,
                  iconColor: Colors.white,
                  title: '12',
                  subtitle: 'Livres lus',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.access_time_outlined,
                  iconColor: Colors.white,
                  title: '2h45m',
                  subtitle: 'Temps de lecture',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Deuxième ligne : 2 statistiques
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.trending_up,
                  iconColor: Colors.white,
                  title: '89%',
                  subtitle: 'Objectif mensuel',
                  extra: LinearProgressIndicator(
                    value: 0.89,
                    backgroundColor: Colors.white.withOpacity(0.3),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    minHeight: 4,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.local_fire_department,
                  iconColor: Colors.white,
                  title: '5',
                  subtitle: 'Série de jours',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    Widget? extra,
  }) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 32, color: AppColors.primary),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color.fromARGB(255, 69, 69, 69),
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: const Color.fromARGB(255, 69, 69, 69),
            ),
            textAlign: TextAlign.center,
          ),
          if (extra != null) ...[const SizedBox(height: 8), extra],
        ],
      ),
    );
  }
}
