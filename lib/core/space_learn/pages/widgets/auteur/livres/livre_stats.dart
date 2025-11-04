import 'package:flutter/material.dart';

class LivreStatsSection extends StatelessWidget {
  const LivreStatsSection({super.key});

  Widget _buildStatCard(String label, [String value = "0"]) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF2E3A59),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(color: Colors.grey[300], fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _buildStatCard("Tous", "12"),
        _buildStatCard("Publiés", "8"),
        _buildStatCard("Brouillons", "3"),
        _buildStatCard("En révision", "1"),
      ],
    );
  }
}
