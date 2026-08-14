import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/themes/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:space_learn_flutter/core/themes/app_dimensions.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/lecteur/recherche_page.dart';

class CustomSearchBar extends StatelessWidget {
  final ValueChanged<String>? onChanged;
  final TextEditingController? controller;
  final VoidCallback? onFilterTap;

  const CustomSearchBar({
    super.key,
    this.onChanged,
    this.controller,
    this.onFilterTap,
  });

  @override
  Widget build(BuildContext context) {
    AppColors.suivreLeTheme(context);
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.cardBackground.withOpacity(0.8),
              borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
              border: Border.all(
                color: AppColors.textPrimary.withOpacity(0.05),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(
                  Icons.search_rounded,
                  color: AppColors.accentInk,
                  size: 20,
                ),
                SizedBox(width: 12),
                // Le champ occupe toute la hauteur et centre son texte.
                //
                // Il etait pose avec `isDense` et une marge nulle dans une
                // barre de 48 px : la ligne de base tombait trop haut, et
                // l'invite paraissait rognee par le bord superieur.
                Expanded(
                  child: TextField(
                    controller: controller,
                    onChanged: onChanged,
                    readOnly: onChanged == null,
                    textAlignVertical: TextAlignVertical.center,
                    onTap: onChanged == null
                        ? () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const RecherchePage(),
                              ),
                            );
                          }
                        : null,
                    style: AppTextStyles.body,
                    decoration: InputDecoration(
                      hintText: "Rechercher des livres...",
                      hintStyle: GoogleFonts.poppins(
                        color: AppColors.textPrimary.withOpacity(0.4),
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      isCollapsed: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                // Effacer, sans avoir a viser la petite croix du clavier.
                if (controller != null && onChanged != null)
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: controller!,
                    builder: (context, valeur, _) {
                      if (valeur.text.isEmpty) return const SizedBox.shrink();
                      return GestureDetector(
                        onTap: () {
                          controller!.clear();
                          onChanged!('');
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
