import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/themes/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:space_learn_flutter/core/themes/app_dimensions.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class LivreCard extends StatelessWidget {
  final String titre;
  final String auteur;
  final String? categorie;
  final int progression;
  final List<Color> couleurs;
  final String? imageUrl;
  final DateTime? dateAcquisition;

  /// Ce que fait le bouton rond, a droite de la carte.
  ///
  /// Il n'etait qu'un dessin : un Container avec une icone, sans le moindre
  /// geste attache. Appuyer dessus ouvrait la fiche du livre — le geste du
  /// parent — alors que sa fleche promettait de lancer quelque chose.
  final VoidCallback? onEcouter;

  /// L'etat de l'ecoute pour CE livre : rien, en preparation, en cours.
  final bool enEcoute;
  final bool enPreparation;

  const LivreCard({
    super.key,
    required this.titre,
    required this.auteur,
    this.categorie,
    required this.progression,
    required this.couleurs,
    this.imageUrl,
    this.dateAcquisition,
    this.onEcouter,
    this.enEcoute = false,
    this.enPreparation = false,
  });

  @override
  Widget build(BuildContext context) {
    AppColors.suivreLeTheme(context);
    return Container(
      margin: EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppDimensions.radiusXs),

        border: Border.all(color: Colors.transparent, width: 0),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
        child: Material(
          color: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                // Book Cover with depth
                Container(
                  width: 85,
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
                    child:
                        imageUrl != null &&
                            imageUrl!.isNotEmpty &&
                            !imageUrl!.contains('example.com')
                        ? Image.network(
                            imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                _buildPlaceholder(),
                          )
                        : _buildPlaceholder(),
                  ),
                ),
                SizedBox(width: 20),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titre,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: AppColors.textPrimary,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      Text(
                        auteur,
                        style: GoogleFonts.poppins(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (categorie != null && categorie!.isNotEmpty) ...[
                        SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.scaffoldBackground,
                            borderRadius: BorderRadius.circular(
                              AppDimensions.radiusSmall,
                            ),
                          ),
                          child: Text(
                            categorie!,
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                      if (dateAcquisition != null) ...[
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 10,
                              color: AppColors.accentInk.withOpacity(0.7),
                            ),
                            SizedBox(width: 4),
                            Text(
                              "Ajouté le ${DateFormat('dd MMM yyyy').format(dateAcquisition!)}",
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w400,
                                color: AppColors.textSecondary,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ],
                      SizedBox(height: 16),
                      // Progress Section
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "Progression",
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    Text(
                                      "$progression%",
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.accentInk,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 6),
                                Stack(
                                  children: [
                                    Container(
                                      height: 6,
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: AppColors.scaffoldBackground,
                                        borderRadius: BorderRadius.circular(
                                          AppDimensions.radiusXs,
                                        ),
                                      ),
                                    ),
                                    FractionallySizedBox(
                                      widthFactor: progression / 100,
                                      child: Container(
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: AppColors.primary,
                                          borderRadius: BorderRadius.circular(
                                            3,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 12),
                          // Action Icon
                          // Ecouter le livre, sans l'ouvrir.
                          //
                          // La lecture a voix haute n'existait qu'a l'interieur
                          // du lecteur : il fallait ouvrir l'ouvrage, attendre
                          // le rendu du PDF, puis lancer l'audio, et garder
                          // l'ecran sur cette page.
                          //
                          // L'icone suit l'etat : une fleche au repos, deux
                          // barres pendant l'ecoute. Sans cela, rien ne dirait
                          // qu'un second appui met en pause plutot que de tout
                          // reprendre au debut.
                          Material(
                            color: Colors.transparent,
                            shape: const CircleBorder(),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: onEcouter,
                              child: Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: enEcoute
                                      ? AppColors.primary
                                      : AppColors.primary.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: enPreparation
                                    ? SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.accentInk,
                                        ),
                                      )
                                    : Icon(
                                        enEcoute
                                            ? Icons.pause_rounded
                                            : Icons.play_arrow_rounded,
                                        // Sur l'aplat plein de l'ecoute en
                                        // cours, seul onAccent garantit le
                                        // contraste dans les deux themes.
                                        color: enEcoute
                                            ? AppColors.onAccent
                                            : AppColors.accentInk,
                                        size: 20,
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: couleurs,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          titre.isNotEmpty ? titre[0].toUpperCase() : "?",
          style: TextStyle(
            color: AppColors.onAccent,
            fontWeight: FontWeight.bold,
            fontSize: 32,
          ),
        ),
      ),
    );
  }
}

class LivreGridCard extends StatelessWidget {
  final String titre;
  final String auteur;
  final int progression;
  final List<Color> couleurs;
  final String? imageUrl;

  const LivreGridCard({
    super.key,
    required this.titre,
    required this.auteur,
    required this.progression,
    required this.couleurs,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    AppColors.suivreLeTheme(context);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppDimensions.radiusInner),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimensions.radiusInner),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover
            Expanded(
              flex: 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  imageUrl != null &&
                          imageUrl!.isNotEmpty &&
                          !imageUrl!.contains('example.com')
                      ? Image.network(imageUrl!, fit: BoxFit.cover)
                      : Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: couleurs,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              titre.isNotEmpty ? titre[0].toUpperCase() : "?",
                              style: TextStyle(
                                color: AppColors.onAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 32,
                              ),
                            ),
                          ),
                        ),
                  // Progress Overlay
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: progression / 100,
                        child: Container(color: AppColors.primary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Details
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      titre,
                      style: AppTextStyles.cardTitle12W700,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 2),
                    Text(
                      auteur,
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
