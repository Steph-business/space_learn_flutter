import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/details/book_detail_page.dart';
import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/themes/app_dimensions.dart';

import '../../../../data/model/book_model.dart';

/// Une carte de la boutique.
///
/// La couverture y était posée dans un `Expanded` : sa hauteur dépendait de ce
/// que le texte laissait, et `BoxFit.cover` rognait le reste. Le titre d'un
/// ouvrage se retrouvait coupé en haut de son propre visuel, ce qui, dans une
/// boutique, revient à mal présenter la marchandise.
///
/// Elle occupe maintenant un rapport fixe de deux tiers — la proportion d'une
/// couverture de livre — et le texte se place dessous, avec une hauteur qu'on
/// peut donc calculer. [hauteurTexte] dit ce qu'il faut réserver, pour que la
/// grille s'accorde à la carte plutôt que l'inverse.
class LivreCard extends StatelessWidget {
  final BookModel book;
  final bool isOwned;

  const LivreCard({super.key, required this.book, this.isOwned = false});

  /// Proportion d'une couverture : deux de large pour trois de haut.
  static const double rapportCouverture = 2 / 3;

  /// Hauteur du bloc de texte sous la couverture.
  ///
  /// Titre sur deux lignes, auteur, note, prix, plus les marges. Fixée ici
  /// pour que la grille calcule son rapport à partir d'une seule source.
  /// Hauteur du bloc de texte sous la couverture (désormais 0 car le texte est sur la couverture).
  static const double hauteurTexte = 0;

  /// Hauteur totale d'une carte pour une largeur donnée.
  ///
  /// La carte occupe son rapport d'aspect 2/3 complet, les informations étant
  /// incrustées directement sur l'image avec un dégradé sombre en bas.
  static double hauteurPour(double largeur) =>
      largeur / rapportCouverture + hauteurTexte;

  bool get _estGratuit => book.prix <= 0;

  @override
  Widget build(BuildContext context) {
    AppColors.suivreLeTheme(context);
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BookDetailPage(book: book, isOwned: isOwned),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: AspectRatio(
          aspectRatio: rapportCouverture,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(color: AppColors.surfaceVariant, child: _couverture()),
              // Dégradé sombre progressif en bas pour garantir une lisibilité optimale
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.25, 0.6, 1.0],
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.45),
                        Colors.black.withOpacity(0.88),
                      ],
                    ),
                  ),
                ),
              ),
              // Étiquttes du haut (GRATUIT / DANS VOTRE BIBLIOTHÈQUE)
              if (_estGratuit)
                Positioned(
                  top: 8,
                  left: 8,
                  child: _etiquette(
                    "GRATUIT",
                    AppColors.success,
                    AppColors.onAccent,
                  ),
                ),
              if (isOwned)
                Positioned(
                  top: 8,
                  right: 8,
                  child: _etiquette(
                    "DANS VOTRE BIBLIOTHÈQUE",
                    AppColors.primary,
                    AppColors.onAccent,
                    icone: Iconsax.book_saved,
                    compacte: true,
                  ),
                ),
              // Informations sur le livre incrustées en bas
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.titre,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Colors.white,
                        height: 1.2,
                        shadows: const [
                          Shadow(
                            color: Colors.black54,
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      book.authorName,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w500,
                        fontSize: 10.5,
                        color: Colors.white.withOpacity(0.85),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _estGratuit ? "Gratuit" : "${book.prix} FCFA",
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: _estGratuit
                                  ? const Color(0xFF4CAF50)
                                  : const Color(0xFFFFD700),
                              shadows: const [
                                Shadow(color: Colors.black87, blurRadius: 4),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (book.noteMoyenne > 0) ...[
                          const Icon(
                            Icons.star_rounded,
                            color: AppColors.warning,
                            size: 13,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            book.noteMoyenne.toStringAsFixed(1),
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _couverture() {
    final url = book.imageCouverture;
    final utilisable =
        url != null && url.isNotEmpty && !url.contains('example.com');
    if (!utilisable) return _placeholder();

    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => _placeholder(),
      loadingBuilder: (context, enfant, avancement) {
        if (avancement == null) return enfant;
        // Un fond calme plutôt qu'une roue : une grille de six cartes qui
        // tournent toutes en même temps est plus agitée qu'informative.
        return Container(color: AppColors.surfaceVariant);
      },
    );
  }

  Widget _etiquette(
    String texte,
    Color fond,
    Color encre, {
    IconData? icone,
    bool compacte = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compacte ? 6 : 8, vertical: 4),
      decoration: BoxDecoration(
        color: fond,
        borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
      ),
      child: compacte && icone != null
          ? Icon(icone, size: 13, color: encre)
          : Text(
              texte,
              style: GoogleFonts.poppins(
                color: encre,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
    );
  }

  Widget _placeholder() {
    return Center(
      child: Icon(Icons.book_rounded, color: AppColors.textHint, size: 36),
    );
  }
}
