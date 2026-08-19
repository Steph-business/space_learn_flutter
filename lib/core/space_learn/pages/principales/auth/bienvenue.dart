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
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (contraintes.maxHeight - marge * 2).clamp(
                    0.0,
                    double.infinity,
                  ),
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Spacer(flex: 2),

                      // ── Logo ──────────────────────────────────────────────
                      Center(
                        child: Image.asset(
                          'asset/logo_sp.png',
                          width: 130,
                          fit: BoxFit.contain,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ── Accroche ──────────────────────────────────────────
                      Text(
                        'La bibliothèque des auteurs\nafricains, dans votre poche.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          height: 1.45,
                          color: AppColors.textPrimary,
                        ),
                      ),

                      const SizedBox(height: 6),

                      Text(
                        'Lisez, publiez et payez en toute simplicité.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          height: 1.4,
                          color: AppColors.textSecondary,
                        ),
                      ),

                      const Spacer(flex: 2),

                      // ── Promesses ─────────────────────────────────────────
                      const _Promesse(
                        icone: Icons.download_done_rounded,
                        titre: 'Lisez partout',
                        detail: 'Vos livres restent lisibles hors connexion',
                      ),
                      const SizedBox(height: 12),
                      const _Promesse(
                        icone: Icons.auto_stories_rounded,
                        titre: 'Publiez vos œuvres',
                        detail:
                            'Suivez vos ventes et vos lecteurs au jour le jour',
                      ),
                      const SizedBox(height: 12),
                      const _Promesse(
                        icone: Icons.verified_user_rounded,
                        titre: 'Payez en toute sécurité',
                        detail: 'Orange Money, MTN, Moov et Wave',
                      ),

                      const Spacer(flex: 3),

                      // ── Bouton connexion ──────────────────────────────────
                      SizedBox(
                        height: 54,
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const LoginPage(),
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.onAccent,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppDimensions.radiusInner,
                              ),
                            ),
                          ),
                          child: Text(
                            'Se connecter',
                            style: GoogleFonts.poppins(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // ── Lien inscription ──────────────────────────────────
                      Center(
                        child: TextButton(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ProfilPage(),
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text.rich(
                            textAlign: TextAlign.center,
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: "Pas encore de compte ? ",
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
                          fontSize: 11,
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

// ── Widget promesse ────────────────────────────────────────────────────────────

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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(
          color: AppColors.textPrimary.withValues(alpha: 0.07),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppDimensions.radiusInner),
            ),
            alignment: Alignment.center,
            child: Icon(icone, size: 22, color: AppColors.accentInk),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titre,
                  style: GoogleFonts.poppins(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    height: 1.4,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
