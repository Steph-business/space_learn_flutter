import 'package:flutter/material.dart';
import 'package:space_learn_flutter/core/themes/app_colors.dart';

/// L'écran d'attente pendant que l'application relit la session.
///
/// Il prend la suite du splash natif, qui affiche déjà le logo. Le passage de
/// l'un à l'autre ne doit pas se voir : même fond, même logo, même taille, au
/// même endroit. Le logo n'est donc ni animé ni redimensionné ici — il l'était,
/// et on le voyait pâlir puis grossir de moitié au démarrage. Seul l'indicateur
/// de chargement apparaît, puisque lui n'existait pas avant.
///
/// D'où l'image affichée : splash_icon.png, le carré que le splash natif montre
/// déjà, plutôt que logo_sp.png. Le logo livré porte un tiers de bordure
/// transparente, si bien qu'une largeur donnée en Dart n'était pas celle du
/// dessin ; en reprenant le même carré, les 176 dp ci-dessous rendent les
/// 150 dp de logo du splash natif, au pixel près (cf. tool/generer_icones.py).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AppColors.suivreLeTheme(context);

    return Scaffold(
      // Le même fond que le splash natif (cf. flutter_native_splash dans
      // pubspec.yaml) et que la page qui suit.
      backgroundColor: AppColors.scaffoldBackground,
      body: Stack(
        children: [
          // Centré, comme le logo du splash natif : décalé de 0,15 vers le
          // haut, il sautait à l'écran suivant.
          Center(
            child: Image.asset(
              'asset/splash_icon.png',
              width: 176,
              fit: BoxFit.contain,
            ),
          ),

          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Center(
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(
                    strokeWidth: 3.0,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
