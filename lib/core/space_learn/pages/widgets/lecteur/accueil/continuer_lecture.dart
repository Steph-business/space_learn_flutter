import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../themes/app_colors.dart';
import '../../../../../themes/app_dimensions.dart';
import '../../../../data/model/book_model.dart';

/// La reprise de lecture, en tête de l'accueil.
///
/// L'accueil ouvrait sur un objectif quotidien — « Lire au moins 15 minutes
/// aujourd'hui », 0 %, « Commencez votre défi ! ». Un encouragement, mais pas
/// une porte : le lecteur qui revient devait passer par la bibliothèque, la
/// filtrer, retrouver son livre, l'ouvrir. Quatre gestes pour reprendre là où
/// il s'était arrêté, à l'endroit même où l'application aurait pu le lui
/// proposer.
///
/// Cette carte reprend cette place quand une lecture est en cours, et emmène
/// directement à la bonne page.
class ContinuerLecture extends StatelessWidget {
  const ContinuerLecture({
    super.key,
    required this.livre,
    required this.onReprendre,
    required this.onEcouter,
    this.enEcoute = false,
    this.enPreparation = false,
  });

  final BookModel livre;

  /// Ouvrir le livre, déclenché par le corps de la carte.
  final VoidCallback onReprendre;

  /// Lancer ou suspendre l'écoute, déclenché par le seul bouton rond.
  ///
  /// Les deux gestes sont distincts, comme sur les cartes de la bibliothèque :
  /// l'icône de lecture promet une voix, pas une page. La faire ouvrir la
  /// liseuse tromperait sur ce qu'elle fait.
  final VoidCallback onEcouter;

  final bool enEcoute;
  final bool enPreparation;

  /// La progression du lecteur sur ce livre, ou null.
  _Avancement get _avancement {
    final p = livre.progressions;
    if (p == null || p.isEmpty) return const _Avancement(0, 0, 0);
    final a = p.first;
    return _Avancement(
      a.pourcentage.toDouble().clamp(0, 100),
      a.lastPage,
      a.totalPages,
    );
  }

  @override
  Widget build(BuildContext context) {
    AppColors.suivreLeTheme(context);
    final avancement = _avancement;

    return GestureDetector(
      onTap: onReprendre,
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _couverture(),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "CONTINUER LA LECTURE",
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: AppColors.accentInk,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        livre.titre,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        livre.authorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Le bouton écoute ; le corps de la carte ouvre le livre.
                //
                // Trois états, comme sur les cartes de la bibliothèque : une
                // roue pendant que le fichier se prépare — c'est l'attente la
                // plus longue, il faut la montrer —, deux barres pendant la
                // lecture, une flèche au repos.
                Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: enPreparation ? null : onEcouter,
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.primaryDark, AppColors.primary],
                        ),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: enPreparation
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: AppColors.onAccent,
                              ),
                            )
                          : Icon(
                              enEcoute
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: AppColors.onAccent,
                              size: 26,
                            ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _barre(avancement.pourcentage / 100),
            const SizedBox(height: 8),
            Text(
              avancement.legende,
              style: GoogleFonts.poppins(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _couverture() {
    const largeur = 56.0, hauteur = 80.0;
    final url = livre.imageCouverture;

    Widget repli() => Container(
      width: largeur,
      height: hauteur,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryDark, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppDimensions.radiusInner),
      ),
      alignment: Alignment.center,
      child: Text(
        livre.titre.isNotEmpty ? livre.titre[0].toUpperCase() : "?",
        style: GoogleFonts.poppins(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: AppColors.onAccent,
        ),
      ),
    );

    if (url == null || url.isEmpty) return repli();

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppDimensions.radiusInner),
      child: Image.network(
        url,
        width: largeur,
        height: hauteur,
        fit: BoxFit.cover,
        // Une couverture injoignable ne doit pas laisser l'icône d'image
        // cassée du système : le repli dessine une vignette sobre.
        errorBuilder: (_, _, _) => repli(),
      ),
    );
  }

  Widget _barre(double fraction) {
    return Stack(
      children: [
        Container(
          height: 6,
          decoration: BoxDecoration(
            color: AppColors.scaffoldBackground,
            borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
          ),
        ),
        FractionallySizedBox(
          widthFactor: fraction.clamp(0.0, 1.0),
          child: Container(
            height: 6,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primaryDark, AppColors.primary],
              ),
              borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
            ),
          ),
        ),
      ],
    );
  }
}

/// Ce qu'on sait de l'avancement, et comment on le dit.
class _Avancement {
  const _Avancement(this.pourcentage, this.page, this.total);

  final double pourcentage;
  final int page;
  final int total;

  /// « Page 87 sur 210 · 41 % », ou ce qu'on peut en dire.
  ///
  /// La pagination n'est pas toujours connue — un EPUB n'a pas de pages fixes,
  /// et un livre à peine ouvert n'a pas encore de total. On ne montre alors que
  /// ce qui est vrai, plutôt qu'un « sur 0 » ou une pagination inventée.
  String get legende {
    final pourcent = "${pourcentage.round()} %";
    if (total > 0 && page > 0) {
      return "Page $page sur $total · $pourcent";
    }
    if (pourcentage > 0) return "Repris à $pourcent";
    return "Vous n'avez pas encore commencé";
  }
}
