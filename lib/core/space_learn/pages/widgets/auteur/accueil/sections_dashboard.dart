import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TopLivresSection extends StatelessWidget {
  const TopLivresSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Top Livres",
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  Text(
                    "Lectures",
                    style: GoogleFonts.poppins(
                      color: Colors.white38,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Text(
                    "Revenus",
                    style: GoogleFonts.poppins(
                      color: Colors.white38,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildItem("1", "Le Secret des Étoiles", "12,500", "680 €"),
          const Divider(color: Colors.white10, height: 24),
          _buildItem("2", "Chroniques du Vent", "9,800", "420 €"),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () {},
              child: Text(
                "Voir tous mes livres",
                style: GoogleFonts.poppins(
                  color: const Color(0xFF0EA5E9),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(String rank, String title, String views, String revenue) {
    return Row(
      children: [
        Text(
          rank,
          style: GoogleFonts.poppins(color: Colors.white38, fontSize: 13),
        ),
        const SizedBox(width: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Container(
            width: 30,
            height: 38,
            color: Colors.white10,
            child: const Icon(Icons.book, size: 18, color: Colors.white24),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                "$views lectures",
                style: GoogleFonts.poppins(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          revenue,
          style: GoogleFonts.poppins(
            color: const Color(0xFF0EA5E9),
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () {},
          icon: const Icon(
            Icons.edit_note_rounded,
            color: Colors.white54,
            size: 22,
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }
}

class CommentairesRecentsSection extends StatelessWidget {
  const CommentairesRecentsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Commentaires Récents",
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildComment(
            "Sophie L.",
            "J'ai adoré l'intrigue !",
            "https://i.pravatar.cc/150?u=sophie",
          ),
          const Divider(color: Colors.white10, height: 24),
          _buildComment(
            "Marc D.",
            "Un peu lent au début...",
            "https://i.pravatar.cc/150?u=marc",
          ),
        ],
      ),
    );
  }

  Widget _buildComment(String author, String text, String avatarUrl) {
    return Row(
      children: [
        CircleAvatar(radius: 20, backgroundImage: NetworkImage(avatarUrl)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                author,
                style: GoogleFonts.poppins(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
        ),
        ElevatedButton(
          onPressed: () {},
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0EA5E9),
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            "Répondre",
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class ConseilsPublicationSection extends StatelessWidget {
  const ConseilsPublicationSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Conseils de Publication",
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildTip("📣", "Promouvoir sur les réseaux sociaux (FB, Insta)"),
          const SizedBox(height: 12),
          _buildTip("📔", "Créer des couvertures accrocheuses"),
          const SizedBox(height: 12),
          _buildTip("💬", "Participer aux discussions communautaires"),
        ],
      ),
    );
  }

  Widget _buildTip(String icon, String text) {
    return Row(
      children: [
        Text(icon, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
          ),
        ),
      ],
    );
  }
}
