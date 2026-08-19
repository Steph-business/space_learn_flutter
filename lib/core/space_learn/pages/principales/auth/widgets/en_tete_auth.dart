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
/// Le logo porte la marque : un seul bloc de 62 px remplace l'empilement.
/// L'en-tête occupe une centaine de pixels, et les cinq écrans partagent la
/// même composition.
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
    AppColors.suivreLeTheme(context);
    return Column(
      children: [
        // Le nom de la marque n'est plus composé en Poppins à côté du logo :
        // il s'affichait alors dans une typographie qui n'est pas celle du
        // logo. Attention, logo_sp.png ne porte pas d'écriture — l'en-tête ne
        // dit donc plus « Space Learn » ; c'est asset/sp_logo.png qui le
        // porte.
        Image.asset('asset/logo_sp.png', height: 90, fit: BoxFit.contain),
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
