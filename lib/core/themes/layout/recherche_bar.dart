import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/themes/app_text_styles.dart';
import 'package:flutter/material.dart';
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
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.cardBackground.withOpacity(0.8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.textPrimary.withOpacity(0.05)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(
                  Icons.search_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: controller,
                    onChanged: onChanged,
                    readOnly: onChanged == null,
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
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}