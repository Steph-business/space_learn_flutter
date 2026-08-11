import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/themes/app_dimensions.dart';

import 'login.dart';
import 'profil.dart';

/// Premier écran de l'application.
///
/// C'était auparavant le choix du profil : on demandait « Qui êtes-vous ? » à
/// quelqu'un qui n'avait encore rien vu du produit, et un lecteur déjà inscrit
/// devait traverser cette question avant de pouvoir se connecter.
///
/// L'écran présente d'abord ce qu'est Space Learn, puis propose deux chemins.
/// Le choix du profil arrive plus tard, au moment où il sert vraiment : juste
/// avant de créer le compte.
class BienvenuePage extends StatelessWidget {
  const BienvenuePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, contraintes) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.spaceXl,
                vertical: AppDimensions.spaceXl,
              ),
              // Spacer exige une hauteur bornée, ce qu'une zone défilante ne
              // donne pas. IntrinsicHeight la fixe à la hauteur de l'écran
              // quand le contenu tient, et le laisse défiler sinon : la page
              // reste équilibrée sur un grand écran sans rien tronquer sur un
              // petit.
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: contraintes.maxHeight - AppDimensions.spaceXl * 2,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Spacer(flex: 2),

                      Image.asset(
                        'asset/logo_space_learn.png',
                        width: 128,
                        height: 128,
                        fit: BoxFit.contain,
                      ),

                      const SizedBox(height: AppDimensions.spaceXl),

                      RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: 'Space',
                              style: GoogleFonts.poppins(
                                fontSize: 38,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textPrimary,
                                height: 1.1,
                              ),
                            ),
                            TextSpan(
                              text: 'Learn',
                              style: GoogleFonts.poppins(
                                fontSize: 38,
                                fontWeight: FontWeight.w900,
                                color: AppColors.accentInk,
                                height: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppDimensions.spaceMd),

                      Text(
                        'La bibliothèque des auteurs africains,\ndans votre poche.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          height: 1.5,
                          color: AppColors.textSecondary,
                        ),
                      ),

                      const SizedBox(height: AppDimensions.spaceXl),

                      // Trois promesses, pas un argumentaire. Ce que quelqu'un
                      // qui découvre l'application a besoin de savoir avant de
                      // décider s'il crée un compte.
                      const _Promesse(
                        icone: Icons.menu_book_outlined,
                        texte: 'Lisez hors connexion, où que vous soyez',
                      ),
                      const SizedBox(height: AppDimensions.spaceMd),
                      const _Promesse(
                        icone: Icons.edit_outlined,
                        texte: 'Publiez vos œuvres et suivez vos ventes',
                      ),
                      const SizedBox(height: AppDimensions.spaceMd),
                      const _Promesse(
                        icone: Icons.lock_outline,
                        texte: 'Paiement mobile money sécurisé',
                      ),

                      const Spacer(flex: 3),

                      ElevatedButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const LoginPage()),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                        ),
                        child: Text(
                          'Se connecter',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.onAccent,
                          ),
                        ),
                      ),

                      const SizedBox(height: AppDimensions.spaceMd),

                      OutlinedButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ProfilPage()),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                        ),
                        child: Text(
                          'Créer un compte',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.accentInk,
                          ),
                        ),
                      ),

                      const SizedBox(height: AppDimensions.spaceLg),

                      Text(
                        "En continuant, vous acceptez nos conditions d'utilisation.",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 11.5,
                          height: 1.4,
                          color: AppColors.textHint,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Promesse extends StatelessWidget {
  final IconData icone;
  final String texte;

  const _Promesse({required this.icone, required this.texte});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icone, size: 20, color: AppColors.accentInk),
        const SizedBox(width: AppDimensions.spaceMd),
        Expanded(
          child: Text(
            texte,
            style: GoogleFonts.poppins(
              fontSize: 14,
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
