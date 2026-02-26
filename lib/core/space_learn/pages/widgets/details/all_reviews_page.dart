import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/book_model.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/review_model.dart';

class AllReviewsPage extends StatelessWidget {
  final BookModel book;
  final List<ReviewModel> reviews;

  const AllReviewsPage({super.key, required this.book, required this.reviews});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111827),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        elevation: 0,
        title: Text(
          "AVIS : ${book.titre.toUpperCase()}",
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: reviews.isEmpty
          ? Center(
              child: Text(
                "Aucun avis pour le moment.",
                style: GoogleFonts.poppins(color: Colors.grey, fontSize: 14),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: reviews.length,
              itemBuilder: (context, index) {
                final r = reviews[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildReviewCard(
                    r.nomUtilisateur ?? "Avis vérifié",
                    r.creeLe != null
                        ? DateFormat('dd MMM yyyy').format(r.creeLe!)
                        : "Récemment",
                    r.note,
                    r.commentaire ?? "",
                    r.photoProfil,
                  ),
                );
              },
            ),
    );
  }

  Widget _buildReviewCard(
    String name,
    String time,
    int stars,
    String comment, [
    String? photoUrl,
  ]) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF06B6D4).withOpacity(0.2),
                backgroundImage:
                    (photoUrl != null &&
                        photoUrl.isNotEmpty &&
                        !photoUrl.contains('example.com'))
                    ? NetworkImage(photoUrl)
                    : null,
                child:
                    (photoUrl == null ||
                        photoUrl.isEmpty ||
                        photoUrl.contains('example.com'))
                    ? const Icon(
                        Icons.person,
                        color: Color(0xFF06B6D4),
                        size: 18,
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      time,
                      style: GoogleFonts.poppins(
                        color: Colors.grey[500],
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: List.generate(5, (index) {
                  return Icon(
                    index < stars
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: const Color(0xFFF59E0B),
                    size: 16,
                  );
                }),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            comment,
            style: GoogleFonts.poppins(
              color: Colors.grey[300],
              fontStyle: FontStyle.italic,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
