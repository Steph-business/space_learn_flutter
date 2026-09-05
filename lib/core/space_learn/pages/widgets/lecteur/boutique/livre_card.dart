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

  /// La note que CE lecteur a donnée au livre, de 1 à 5 — nulle s'il ne l'a
  /// pas noté.
  ///
  /// Elle arrivait autrefois écrite dans `book.noteMoyenne` : la boutique la
  /// versait dans le livre avant de le passer ici, et l'étoile ci-dessous, qui
  /// dit la moyenne de l'ouvrage, affichait en réalité la note du lecteur —
  /// « 2,0 » sur un livre moyenné 4,3. Un chiffre en remplaçait un autre sans
  /// le dire. Elle voyage désormais à part, et la carte la NOMME.
  final int? noteDuLecteur;

  const LivreCard({
    super.key,
    required this.book,
    this.isOwned = false,
    this.noteDuLecteur,
  });

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

  static String formatPrix(int prix) {
    if (prix <= 0) return "Gratuit";
    return "$prix FCFA";
  }

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
              // Étiqettes du haut
              if (_estGratuit)
                Positioned(
                  top: 8,
                  right: 8,
                  child: _etiquette(
                    "GRATUIT",
                    AppColors.primary,
                    AppColors.onAccent,
                  ),
                )
              else if (isOwned)
                Positioned(
                  top: 8,
                  right: 8,
                  child: _etiquette(
                    "ACQUIS",
                    AppColors.primary,
                    AppColors.onAccent,
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
                            _estGratuit
                                ? "Gratuit"
                                : LivreCard.formatPrix(book.prix),
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
                        // La moyenne du livre, telle que le serveur la rend.
                        // Absente ou nulle, on n'affiche rien : « 0,0 » se
                        // lirait comme un mauvais livre alors que personne ne
                        // l'a encore noté.
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
                    // Sa propre note, dite comme telle et sur une ligne à
                    // elle : une carte de boutique reste petite, une mention
                    // courte suffit à la distinguer de la moyenne ci-dessus.
                    // Un livre que le lecteur n'a pas noté n'affiche rien de
                    // plus qu'avant.
                    if (noteDuLecteur != null) ...[
                      const SizedBox(height: 3),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Blanc atténué, et non l'or de la moyenne : la
                          // couleur elle-même dit qu'il ne s'agit pas de la
                          // même note.
                          const Icon(
                            Icons.star_rounded,
                            color: Colors.white70,
                            size: 11,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            "Votre note $noteDuLecteur/5",
                            style: GoogleFonts.poppins(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w500,
                              color: Colors.white70,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ],
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

/// Carte sous forme de liste horizontale pour la boutique.
class LivreListCard extends StatelessWidget {
  final BookModel book;
  final bool isOwned;

  /// La note de ce lecteur, de 1 à 5 — voir [LivreCard.noteDuLecteur].
  ///
  /// La liste souffrait du même défaut que la grille : le livre lui arrivait
  /// avec sa moyenne déjà remplacée, plus haut dans la boutique.
  final int? noteDuLecteur;

  const LivreListCard({
    super.key,
    required this.book,
    this.isOwned = false,
    this.noteDuLecteur,
  });

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
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Couverture du livre
            ClipRRect(
              borderRadius: BorderRadius.circular(AppDimensions.radiusInner),
              child: SizedBox(width: 75, height: 105, child: _couverture()),
            ),
            const SizedBox(width: 14),
            // Détails du livre
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.titre,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    book.authorName,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (book.categorie != null &&
                      book.categorie!.nom.isNotEmpty) ...[
                    const SizedBox(height: 4),
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
                        book.categorie!.nom,
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _estGratuit
                            ? "Gratuit"
                            : LivreCard.formatPrix(book.prix),
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: _estGratuit
                              ? const Color(0xFF4CAF50)
                              : AppColors.accentInk,
                        ),
                      ),
                      if (isOwned)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(
                              AppDimensions.radiusPill,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Iconsax.book_saved,
                                size: 12,
                                color: AppColors.accentInk,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                "Acquis",
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.accentInk,
                                ),
                              ),
                            ],
                          ),
                        )
                      // Comme en grille : la moyenne du serveur, et rien
                      // quand il n'y en a pas encore.
                      else if (book.noteMoyenne > 0)
                        Row(
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              color: AppColors.warning,
                              size: 14,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              book.noteMoyenne.toStringAsFixed(1),
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  // Sa propre note, nommée — jamais à la place de la moyenne.
                  if (noteDuLecteur != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.star_rounded,
                          color: AppColors.warning,
                          size: 12,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          "Votre note $noteDuLecteur/5",
                          style: GoogleFonts.poppins(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ],
                ],
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
    );
  }

  Widget _placeholder() {
    return Container(
      color: AppColors.surfaceVariant,
      child: Center(
        child: Icon(Icons.book_rounded, color: AppColors.textHint, size: 28),
      ),
    );
  }
}
