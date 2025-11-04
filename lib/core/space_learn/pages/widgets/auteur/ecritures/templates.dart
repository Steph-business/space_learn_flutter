import 'package:flutter/material.dart';

class TemplatesWidget extends StatelessWidget {
  const TemplatesWidget({super.key});

  Widget _templateCard(String name, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(width: 12),
          Text(name, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Templates disponibles",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 16),
        _templateCard("Roman classique", Icons.book_rounded, Colors.blue),
        _templateCard("Article de blog", Icons.article_rounded, Colors.orange),
        _templateCard("Essai académique", Icons.school_rounded, Colors.purple),
      ],
    );
  }
}
