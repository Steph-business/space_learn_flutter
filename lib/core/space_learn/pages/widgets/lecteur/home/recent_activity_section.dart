import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../themes/layout/navBarLecteur.dart';
import '../../../../data/model/activiteModel.dart';

class RecentActivitySection extends StatelessWidget {
  final ReviewModel activity;

  const RecentActivitySection({super.key, required this.activity});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        onTap: () {
          // Navigation vers la bibliothèque ou le détail du livre
          final navBarState = MainNavBar.of(context);
          if (navBarState != null) {
            navBarState.navigateToBibliotheque();
          }
        },
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.chat_bubble_rounded,
            color: Color(0xFFD97706),
            size: 20,
          ),
        ),
        title: Text(
          "Vous avez commenté '${activity.livre?.titre ?? 'un livre'}'",
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1E293B),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          activity.commentaire,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: const Color(0xFF64748B),
            fontWeight: FontWeight.w400,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: Color(0xFF94A3B8),
        ),
      ),
    );
  }
}
