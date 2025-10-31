import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class Statistique extends StatelessWidget {
  const Statistique({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(18),
          bottomRight: Radius.circular(18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Statistiques
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStat("12", "Livres"),
              _buildStat("1,284", "Lecteurs"),
              _buildStat("4.8", "Note"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13),
        ),
      ],
    );
  }
}
