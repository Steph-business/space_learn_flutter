import 'package:flutter/material.dart';

class LivreStatsSection extends StatelessWidget {
  const LivreStatsSection({super.key});

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
            color: Colors.grey[600],
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildValueWidget(String value) {
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
          style: const TextStyle(fontSize: 16, color: Color(0xFF2D3142)),
        ),
      );
    }
    return Text(
      value,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 16,
        color: Color(0xFF2D3142),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
            "12",
            Icons.menu_book_rounded,
            Colors.blue,
          ),
          _buildSummaryItem(
            "Vues",
            "3.5k",
            Icons.visibility_rounded,
            Colors.orange,
          ),
          _buildSummaryItem(
            "Revenus",
            "1.2k FCFA",
            Icons.payments_rounded,
            Colors.green,
          ),
        ],
      ),
    );
  }
}
