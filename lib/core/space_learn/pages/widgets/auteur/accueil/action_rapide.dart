import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/themes/app_dimensions.dart';
import 'package:space_learn_flutter/core/themes/widgets/app_card.dart';
import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/ecrivain/livres_page.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/ecrivain/communaute_page.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/ecrivain/ajouter_livre_page.dart';

class AuteurActionsRapide extends StatelessWidget {
  const AuteurActionsRapide({super.key});

  @override
  Widget build(BuildContext context) {
    final actions = [
      {
        "icon": Icons.library_books,
        "title": "Mes livres",
        "subtitle": "Gérer publications",
        "color": AppColors.primary,
        "page": const LivresPage(),
      },
      {
        "icon": Icons.people,
        "title": "Teams",
        "subtitle": "Collaborer",
        "color": Colors.purple,
        "page": TeamsPage(),
      },
      {
        "icon": Icons.add_circle,
        "title": "Ajouter livre",
        "subtitle": "Nouvelle oeuvre",
        "color": Colors.green,
        "page": const AjouterLivrePage(),
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
          // Les rôles étaient inversés ici : `textPrimary` servait de fond et
          // `cardBackground` de couleur de texte, ce qui donnait une carte
          // noire en mode clair et blanche en mode sombre — à contre-courant du
          // reste de l'écran.
          return AppCard(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => item["page"] as Widget),
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: (item["color"] as Color).withOpacity(0.12),
                  child: Icon(
                    item["icon"] as IconData,
                    color: item["color"] as Color,
                  ),
                ),
                const SizedBox(height: AppDimensions.spaceMd),
                Text(
                  item["title"] as String,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  item["subtitle"] as String,
                  style: GoogleFonts.poppins(
                    color: AppColors.textSecondary,
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
