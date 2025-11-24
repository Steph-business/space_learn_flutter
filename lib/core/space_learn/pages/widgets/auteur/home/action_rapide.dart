import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/ecrivain/livrePage.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/ecrivain/statsPage.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/ecrivain/teamsPage.dart';

class AuteurActionsRapide extends StatelessWidget {
  const AuteurActionsRapide({super.key});

  @override
  Widget build(BuildContext context) {
    final actions = [
      {
        "icon": Icons.library_books,
        "title": "Mes livres",
        "subtitle": "Gérer publications",
        "color": Colors.blue,
        "page": const LivresPage(),
      },
      {
        "icon": Icons.bar_chart,
        "title": "Statistiques",
        "subtitle": "Suivi ventes",
        "color": Colors.orange,
        "page": const StatsPage(),
      },
      {
        "icon": Icons.people,
        "title": "Teams",
        "subtitle": "Collaborer",
        "color": Colors.purple,
        "page": TeamsPage(),
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
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => item["page"] as Widget),
              );
            },
            child: Container(
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
            ),
          );
        },
      ),
    );
  }
}
