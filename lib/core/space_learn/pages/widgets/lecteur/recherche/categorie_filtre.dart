import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../themes/app_colors.dart';

class CategorieFiltres extends StatelessWidget {
  const CategorieFiltres({super.key});

  @override
  Widget build(BuildContext context) {
    final categories = ["Romans", "Business", "Science", "Informatique"];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: categories.map((cat) {
          return Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Text(
              cat,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
