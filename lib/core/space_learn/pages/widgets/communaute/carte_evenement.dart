import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

import 'package:space_learn_flutter/core/space_learn/data/model/evenementModel.dart';
import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/themes/app_dimensions.dart';
import 'package:space_learn_flutter/core/themes/app_text_styles.dart';

/// Une annonce ou un événement, tel qu'il apparaît dans une liste.
///
/// La même carte était écrite deux fois, dans la page communauté du lecteur et
/// dans celle de l'auteur, avec des divergences qui s'installaient à chaque
/// retouche. Une troisième copie s'ajoutait avec la page listant tout : c'est
/// le moment de n'en garder qu'une.
class CarteEvenement extends StatelessWidget {
  const CarteEvenement({
    super.key,
    required this.evenement,
    required this.onTap,
    this.signature,
  });

  final Evenement evenement;
  final VoidCallback onTap;

  /// Ligne du bas. Le nom de l'auteur quand on le connaît.
  ///
  /// Elle affichait « Événement Communauté » sur chaque carte, quelle que soit
  /// la publication et quel qu'en soit l'auteur — une signature qui ne signe
  /// rien. Sans valeur, la ligne disparaît plutôt que de meubler.
  final String? signature;

  bool get _estAnnonce =>
      evenement.typePublication.toLowerCase().trim() == 'annonce';

  /// L'étiquette du haut : la catégorie si le serveur en donne une, le type
  /// sinon. « ÉVÉNEMENT » seul ne dit rien de ce qu'on va lire.
  String get _etiquette {
    final categorie = evenement.categorie?.trim();
    if (categorie != null && categorie.isNotEmpty)
      return categorie.toUpperCase();
    return evenement.typePublication.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    AppColors.suivreLeTheme(context);

    // AppColors.success est la couleur de confirmation. L'employer en décor lui
    // retire son sens partout ailleurs : quand un vrai succès s'affiche, il ne
    // se distingue plus de rien. L'icône suffit à séparer les deux formes.
    final accent = AppColors.accentInk;
    final icone = _estAnnonce ? Iconsax.notification : Iconsax.calendar;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          border: Border.all(color: accent.withValues(alpha: 0.3)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusSmall,
                    ),
                  ),
                  child: Icon(icone, color: accent, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _etiquette,
                    style: GoogleFonts.poppins(
                      color: accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (evenement.dateEvenement != null)
                  Text(
                    DateFormat(
                      'd MMM yyyy',
                      'fr_FR',
                    ).format(evenement.dateEvenement!),
                    style: GoogleFonts.poppins(
                      color: AppColors.textHint,
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              evenement.titre,
              style: GoogleFonts.poppins(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              evenement.contenu,
              style: AppTextStyles.grey12,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                if (signature != null && signature!.trim().isNotEmpty) ...[
                  Icon(Icons.person, size: 12, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      signature!.trim(),
                      style: GoogleFonts.poppins(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ] else
                  const Spacer(),
                Text(
                  "Lire",
                  style: GoogleFonts.poppins(
                    color: accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Icon(Iconsax.arrow_right_3, size: 13, color: accent),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
