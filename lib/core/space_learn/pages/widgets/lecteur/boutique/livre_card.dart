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
  static const double hauteurTexte = 104;

  /// Hauteur totale d'une carte pour une largeur donnée.
  ///
  /// Une carte trop courte rogne la couverture ou fait déborder le texte, et
  /// rien ne le signale à la compilation — un débordement ne se voit qu'à
  /// l'écran. Chaque endroit qui pose une carte demande donc sa hauteur ici,
  /// plutôt que de deviner un nombre : la grille de la boutique comme les
  /// carrousels de l'accueil.
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
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: rapportCouverture,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: AppColors.surfaceVariant,
                    child: _couverture(),
                  ),
                  // L'étiquette du gratuit, sur la couverture.
                  //
                  // C'est l'argument le plus fort d'une fiche : il doit se voir
                  // depuis la grille, sans avoir à lire le prix.
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
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Deux lignes. Sur une seule, « L'histoire du monde »
                    // devenait « L'histoire du mon… » — on ne sait plus de quel
                    // ouvrage il s'agit.
                    Text(
                      book.titre,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        color: AppColors.textPrimary,
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      book.authorName,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w500,
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _estGratuit ? "Gratuit" : "${book.prix} FCFA",
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: _estGratuit
                                  ? AppColors.success
                                  : AppColors.accentInk,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (book.noteMoyenne > 0) ...[
                          Icon(
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
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
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
