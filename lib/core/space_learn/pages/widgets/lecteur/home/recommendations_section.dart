import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../data/model/bookModel.dart';
import '../markeplace/livre_card.dart';

class RecommendationsSection extends StatelessWidget {
  final List<BookModel> books;

  const RecommendationsSection({super.key, required this.books});

  @override
  Widget build(BuildContext context) {
    if (books.isEmpty) {
      return Container(
        height: 100,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFFF1F5F9)),
        ),
        child: Center(
          child: Text(
            "Aucune recommandation pour le moment",
            style: GoogleFonts.poppins(
              color: const Color(0xFF64748B),
              fontSize: 13,
            ),
          ),
        ),
      );
    }

    // Matching the height used in MarketplacePage for the taller cards
    return SizedBox(
      height: 200, // Reduced from 320
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: books.length,
        // Removed padding to align with section headers or allow bleed if desired,
        // but keeping right padding for elements spacing.
        itemBuilder: (context, index) {
          final book = books[index];
          return Container(
            width: 120, // Reduced from 150
            margin: const EdgeInsets.only(right: 12),
            child: LivreCard(book: book),
          );
        },
      ),
    );
  }
}
