import 'package:flutter/material.dart';

class OutilsEcritureSection extends StatelessWidget {
  final Function(String) onToolSelected;

  const OutilsEcritureSection({super.key, required this.onToolSelected});

  Widget _buildToolCard(IconData icon, String title, String key) {
    return GestureDetector(
      onTap: () => onToolSelected(key),
      child: Container(
        width: 120,
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.green, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Outils d'écriture",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildToolCard(Icons.edit_note_rounded, "Nouveau livre", "livre"),
              _buildToolCard(Icons.note_add_rounded, "Nouveau chapitre", "chapitre"),
              _buildToolCard(Icons.palette_rounded, "Templates", "template"),
            ],
          ),
        ),
      ],
    );
  }
}
