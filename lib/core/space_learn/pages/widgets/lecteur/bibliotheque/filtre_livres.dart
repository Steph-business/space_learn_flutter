import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FiltreLivres extends StatelessWidget {
  final String filtreActif;
  final ValueChanged<String> onFiltreChange;

  const FiltreLivres({
    super.key,
    required this.filtreActif,
    required this.onFiltreChange,
  });

  @override
  Widget build(BuildContext context) {
    final filtres = [
      "Tous",
      "Business",
      "Informatique",
      "Science",
      "Littérature",
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: filtres.map((f) {
          final actif = f == filtreActif;
          return GestureDetector(
            onTap: () => onFiltreChange(f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: actif ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: actif
                    ? [
                        BoxShadow(
                          color: const Color(0xFF1E293B).withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        )
                      ],
                border: Border.all(
                  color: actif ? Colors.transparent : const Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
              child: Text(
                f,
                style: GoogleFonts.poppins(
                  color: actif ? Colors.white : const Color(0xFF64748B),
                  fontWeight: actif ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
