import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/themes/app_dimensions.dart';

/// En-tête commun aux écrans d'authentification.
///
/// Les cinq écrans empilaient verticalement un logo de 110 px, un titre de
/// page, la marque en 32 ou 36 px et une accroche : plus de 300 px avant le
/// premier champ. Sur un téléphone courant, le formulaire d'inscription
/// débordait dès le quatrième champ et le bouton passait sous la ligne de
/// flottaison — on ne voyait pas ce qu'on remplissait.
///
/// Le logo et la marque tiennent désormais sur une seule ligne. L'en-tête
/// occupe une centaine de pixels, et les cinq écrans partagent la même
/// composition.
class EnTeteAuth extends StatelessWidget {
  /// Ce que l'écran demande à l'utilisateur, en une phrase.
  final String accroche;

  /// Titre de l'écran, quand il porte une information que l'accroche ne donne
  /// pas — « Nouveau mot de passe », « Vérification ». Inutile là où l'écran
  /// se comprend seul.
  final String? titre;

  const EnTeteAuth({super.key, required this.accroche, this.titre});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Image.asset(
              'asset/logo_space_learn.png',
              width: 46,
              height: 46,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: AppDimensions.spaceMd),
            // Sur un écran de 320 px, la marque en 26 px ne tient pas à côté
            // du logo : elle débordait de 54 px. FittedBox la réduit au lieu
            // de la laisser dépasser, et ne fait rien tant que la place est
            // suffisante.
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'Space',
                        style: GoogleFonts.poppins(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                          height: 1.1,
                        ),
                      ),
                      TextSpan(
                        text: 'Learn',
                        style: GoogleFonts.poppins(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: AppColors.accentInk,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        if (titre != null) ...[
          const SizedBox(height: AppDimensions.spaceMd),
          Text(
            titre!,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.2,
            ),
          ),
        ],
        const SizedBox(height: AppDimensions.spaceSm),
        Text(
          accroche,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 13.5,
            height: 1.35,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
