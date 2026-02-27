import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:flutter/material.dart';

class LivreStatsSection extends StatelessWidget {
  final int publications;
  final int views;
  final int revenue;

  const LivreStatsSection({
    super.key,
    this.publications = 0,
    this.views = 0,
    this.revenue = 0,
  });

  Widget _buildSummaryItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        _buildValueWidget(value),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildValueWidget(String value) {
    return Text(
      value,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 18,
        color: Colors.white,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildSummaryItem(
            "Publications",
            publications.toString(),
            Icons.menu_book_rounded,
            AppColors.secondaryVariant,
          ),
          _buildSummaryItem(
            "Vues",
            views >= 1000
                ? "${(views / 1000).toStringAsFixed(1)}k"
                : views.toString(),
            Icons.visibility_rounded,
            Colors.orange,
          ),
          _buildSummaryItem(
            "Revenus",
            "$revenue €",
            Icons.payments_rounded,
            Colors.green,
          ),
        ],
      ),
    );
  }
}
