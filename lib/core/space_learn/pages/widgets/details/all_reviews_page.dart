import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/themes/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:space_learn_flutter/core/themes/app_dimensions.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/book_model.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/review_model.dart';
import 'package:space_learn_flutter/core/utils/image_reseau.dart';

class AllReviewsPage extends StatelessWidget {
  final BookModel book;
  final List<ReviewModel> reviews;

  const AllReviewsPage({super.key, required this.book, required this.reviews});

  /// Le serveur en compte-t-il plus que ce qu'on nous a passé ?
  ///
  /// `nombreAvis` vient du livre, pas de la liste : c'est le seul des deux
  /// chiffres qui reste exact quand la liste est bornée.
  bool get _ilEnManque =>
      book.nombreAvis > reviews.length && reviews.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    AppColors.suivreLeTheme(context);
    return Scaffold(
      backgroundColor: AppColors.darkSurface,
      appBar: AppBar(
        backgroundColor: AppColors.darkSurface,
        elevation: 0,
        title: Text(
          "AVIS : ${book.titre.toUpperCase()}",
          style: AppTextStyles.cardTitle,
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: AppColors.textPrimary,
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: reviews.isEmpty
          ? Center(
              child: Text(
                "Aucun avis pour le moment.",
                style: AppTextStyles.greyBody14,
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              // CETTE PAGE MONTRE UNE TRANCHE, ET ELLE DOIT LE DIRE.
              //
              // GET /api/reviews/book/:livre_id rend au plus cent avis, les
              // plus récents (space_learn_livres, modules/avis : la liste est
              // nominative — noms et photos — et se téléchargeait sans borne).
              // S'intituler « Tous les avis » en en montrant cent sur trois
              // cents serait un silence qui trompe. Le nombre exact, lui, vient
              // du livre : `nombre_avis` est rendu par le serveur et ne dépend
              // pas de la longueur de cette liste.
              //
              // Une ligne de plus quand il en manque, aucune sinon.
              itemCount: reviews.length + (_ilEnManque ? 1 : 0),
              itemBuilder: (context, index) {
                if (_ilEnManque && index == reviews.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 24),
                    child: Text(
                      "Les ${reviews.length} avis les plus récents, "
                      "sur ${book.nombreAvis} au total.",
                      textAlign: TextAlign.center,
                      style: AppTextStyles.greyBody14,
                    ),
                  );
                }
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
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(color: AppColors.textPrimary.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primary.withOpacity(0.2),
                backgroundImage:
                    (photoUrl != null &&
                        photoUrl.isNotEmpty &&
                        !photoUrl.contains('example.com'))
                    ? imageReseau(photoUrl)
                    : null,
                child:
                    (photoUrl == null ||
                        photoUrl.isEmpty ||
                        photoUrl.contains('example.com'))
                    ? Icon(Icons.person, color: AppColors.accentInk, size: 18)
                    : null,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: AppTextStyles.cardTitleSmall),
                    Text(
                      time,
                      style: GoogleFonts.poppins(
                        color: AppColors.textSecondary,
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
                    color: AppColors.warning,
                    size: 16,
                  );
                }),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            comment,
            style: GoogleFonts.poppins(
              color: AppColors.textSecondary,
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
