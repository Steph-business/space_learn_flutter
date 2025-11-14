import 'package:flutter/material.dart';

class OutilsEcritureSection extends StatelessWidget {
  final Function(String) onToolSelected;

  const OutilsEcritureSection({super.key, required this.onToolSelected});

  Widget _buildToolCard(IconData icon, String title, String key) {
    return GestureDetector(
      onTap: () => onToolSelected(key),
      child: Container(
        width: 130,
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(color: Colors.grey.withOpacity(0.1), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: key == 'livre'
                      ? [const Color(0xFF6366F1), const Color(0xFF8B5CF6)]
                      : key == 'chapitre'
                      ? [const Color(0xFF10B981), const Color(0xFF059669)]
                      : [const Color(0xFFF59E0B), const Color(0xFFD97706)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Colors.grey[800],
              ),
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
              _buildToolCard(
                Icons.note_add_rounded,
                "Nouveau chapitre",
                "chapitre",
              ),
              _buildToolCard(Icons.palette_rounded, "Templates", "template"),
            ],
          ),
        ),
      ],
    );
  }
}
