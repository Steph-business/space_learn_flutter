import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app_colors.dart';
import '../app_dimensions.dart';

/// Sélecteur segmenté (deux ou plusieurs onglets côte à côte).
///
/// Remplace les implémentations locales qui codaient leurs couleurs en dur :
/// celle du tableau de bord auteur peignait une piste bleu nuit avec un libellé
/// actif en `Colors.white` sur une pastille quasi blanche — le texte
/// disparaissait complètement en mode clair.
class AppSegmentedControl extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final double height;

  const AppSegmentedControl({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
    this.height = 42,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(AppDimensions.spaceXs),
      decoration: BoxDecoration(
        color: AppColors.segmentTrack,
        borderRadius: BorderRadius.circular(AppDimensions.radiusInner),
      ),
      child: Row(
        children: List.generate(labels.length, (index) {
          final isSelected = index == selectedIndex;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(index),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.segmentThumb : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
                ),
                alignment: Alignment.center,
                child: Text(
                  labels[index],
                  style: GoogleFonts.poppins(
                    color: isSelected
                        ? AppColors.segmentLabelActive
                        : AppColors.segmentLabelInactive,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
