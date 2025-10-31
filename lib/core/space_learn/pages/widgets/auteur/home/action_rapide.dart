import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AuteurActionsRapide extends StatelessWidget {
  const AuteurActionsRapide({super.key});

  @override
  Widget build(BuildContext context) {
    final actions = [
      {
        "icon": Icons.edit,
        "title": "Écrire",
        "subtitle": "Nouveau chapitre",
        "color": Colors.green,
      },
      {
        "icon": Icons.library_books,
        "title": "Mes livres",
        "subtitle": "Gérer publications",
        "color": Colors.blue,
      },
      {
        "icon": Icons.bar_chart,
        "title": "Statistiques",
        "subtitle": "Suivi ventes",
        "color": Colors.orange,
      },
      {
        "icon": Icons.people,
        "title": "Lecteurs",
        "subtitle": "Avis & feedbacks",
        "color": Colors.purple,
      },
    ];

    return RepaintBoundary(
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: actions.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisExtent: 120,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
        ),
        itemBuilder: (context, index) {
          final item = actions[index];
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: (item["color"] as Color).withOpacity(0.1),
                  child: Icon(
                    item["icon"] as IconData,
                    color: item["color"] as Color,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  item["title"] as String,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                Text(
                  item["subtitle"] as String,
                  style: GoogleFonts.poppins(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
