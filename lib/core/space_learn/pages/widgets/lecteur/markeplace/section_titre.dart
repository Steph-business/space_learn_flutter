import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SectionTitle extends StatelessWidget {
  final String title;
  const SectionTitle({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1E293B),
          ),
        ),
        Row(
          children: const [
            Icon(Icons.grid_view, color: Color(0xFF1E293B)),
            SizedBox(width: 6),
            Icon(Icons.list, color: Color(0xFF94A3B8)),
          ],
        ),
      ],
    );
  }
}
