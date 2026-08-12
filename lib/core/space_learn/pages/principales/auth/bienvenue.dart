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
    AppColors.suivreLeTheme(context);
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, contraintes) {
            const marge = AppDimensions.spaceXl;
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(marge, marge, marge, marge),
              // Spacer exige une hauteur bornée, ce qu'une zone défilante ne
              // donne pas. IntrinsicHeight la fixe à la hauteur de l'écran
              // quand le contenu tient, et le laisse défiler sinon : la page
              // reste équilibrée sur un grand écran sans rien tronquer sur un
              // petit.
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: contraintes.maxHeight - marge * 2,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Spacer(flex: 2),

                      const _MarqueAvecHalo(),

                      const SizedBox(height: AppDimensions.spaceXl),

                      Text(
                        'La bibliothèque des auteurs africains,\ndans votre poche.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 15.5,
                          height: 1.5,
                          color: AppColors.textSecondary,
                        ),
                      ),

                      const Spacer(flex: 2),

                      // Trois promesses, pas un argumentaire. Ce que quelqu'un
                      // qui découvre l'application a besoin de savoir avant de
                      // décider s'il crée un compte.
                      const _Promesse(
                        icone: Icons.download_done_outlined,
                        titre: 'Lisez partout',
                        detail: 'Vos livres restent lisibles hors connexion',
                      ),
                      const SizedBox(height: AppDimensions.spaceLg),
                      const _Promesse(
                        icone: Icons.auto_stories_outlined,
                        titre: 'Publiez vos œuvres',
                        detail:
                            'Suivez vos ventes et vos lecteurs au jour le jour',
                      ),
                      const SizedBox(height: AppDimensions.spaceLg),
                      const _Promesse(
                        icone: Icons.verified_user_outlined,
                        titre: 'Payez en toute sécurité',
                        detail: 'Orange Money, MTN, Moov et Wave',
                      ),

                      const Spacer(flex: 3),

                      ElevatedButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const LoginPage()),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          elevation: 3,
                          shadowColor: AppColors.primary.withValues(
                            alpha: 0.45,
                          ),
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

                      const SizedBox(height: AppDimensions.spaceLg),

                      // Créer un compte n'est plus un bouton : deux boutons de
                      // même poids obligent à choisir entre deux inconnues.
                      // Celui qui a un compte trouve son bouton, celui qui n'en
                      // a pas trouve sa phrase.
                      Center(
                        child: TextButton(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ProfilPage(),
                            ),
                          ),
                          child: Text.rich(
                            textAlign: TextAlign.center,
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: "Vous n'avez pas de compte ? ",
                                  style: GoogleFonts.poppins(
                                    fontSize: 13.5,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                TextSpan(
                                  text: 'Inscrivez-vous',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.accentInk,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: AppDimensions.spaceSm),

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

/// Le logo posé sur un halo de la couleur de la marque.
///
/// Sur un fond uni, le logo seul flottait sans ancrage. Le halo lui donne une
/// assise sans rien ajouter à charger — c'est un dégradé, pas une image.
class _MarqueAvecHalo extends StatelessWidget {
  const _MarqueAvecHalo();

  @override
  Widget build(BuildContext context) {
    AppColors.suivreLeTheme(context);
    return Column(
      children: [
        Container(
          width: 132,
          height: 132,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                AppColors.primary.withValues(alpha: 0.22),
                AppColors.primary.withValues(alpha: 0.06),
                AppColors.primary.withValues(alpha: 0.0),
              ],
              stops: const [0.0, 0.6, 1.0],
            ),
          ),
          alignment: Alignment.center,
          child: Image.asset(
            'asset/logo_space_learn.png',
            width: 88,
            height: 88,
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: AppDimensions.spaceLg),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text.rich(
            textAlign: TextAlign.center,
            TextSpan(
              children: [
                TextSpan(
                  text: 'Space',
                  style: GoogleFonts.poppins(
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                    color: AppColors.textPrimary,
                    height: 1.05,
                  ),
                ),
                TextSpan(
                  text: 'Learn',
                  style: GoogleFonts.poppins(
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                    color: AppColors.accentInk,
                    height: 1.05,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Une promesse : une icône posée sur une pastille teintée, un titre, un détail.
class _Promesse extends StatelessWidget {
  final IconData icone;
  final String titre;
  final String detail;

  const _Promesse({
    required this.icone,
    required this.titre,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    AppColors.suivreLeTheme(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(AppDimensions.radiusInner),
          ),
          alignment: Alignment.center,
          child: Icon(icone, size: 21, color: AppColors.accentInk),
        ),
        const SizedBox(width: AppDimensions.spaceLg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titre,
                style: GoogleFonts.poppins(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                detail,
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  height: 1.4,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
