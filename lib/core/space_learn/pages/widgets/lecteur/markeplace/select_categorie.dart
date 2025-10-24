import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SelectCategorie extends StatelessWidget {
  const SelectCategorie({super.key});

  @override
  Widget build(BuildContext context) {
    final categories = ["Tout", "Business", "Romans", "Éducation"];

    return SizedBox(
      height: 38,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final selected = index == 0;
          return Container(
            margin: const EdgeInsets.only(right: 10),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFF6D6DFF) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Center(
              child: Text(
                categories[index],
                style: GoogleFonts.poppins(
                  color:
                      selected ? Colors.white : const Color(0xFF1E293B),
                  fontWeight:
                      selected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
