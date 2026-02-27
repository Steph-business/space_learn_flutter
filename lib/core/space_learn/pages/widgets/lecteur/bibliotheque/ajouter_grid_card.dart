import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AjouterGridCard extends StatelessWidget {
  final VoidCallback onTap;

  const AjouterGridCard({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.scaffoldBackground, // Darker background
                borderRadius: BorderRadius.circular(12),
                // Dashed border is tricky without a specific package,
                // but we can simulate it or just use a solid thin border for simplicity
                border: Border.all(
                  color: AppColors.border,
                  width: 1.5,
                  style: BorderStyle.solid,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.slateLight, // Muted grey/blue
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.add,
                        color: AppColors.scaffoldBackground,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Ajouter",
                      style: GoogleFonts.poppins(
                        color: AppColors.slateLight,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Empty space to match the height of title/author
          // in LivreGridCard
          Text("", style: GoogleFonts.poppins(fontSize: 14)),
          const SizedBox(height: 2),
          Text("", style: GoogleFonts.poppins(fontSize: 12)),
        ],
      ),
    );
  }
}
