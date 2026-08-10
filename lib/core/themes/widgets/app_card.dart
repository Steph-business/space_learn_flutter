import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_dimensions.dart';

/// Carte standard de l'application.
///
/// Centralise le fond, le rayon, la bordure et la marge intérieure pour que
/// toutes les surfaces se ressemblent d'un écran à l'autre. Auparavant chaque
/// widget composait son propre `Container` + `BoxDecoration`, avec des rayons
/// de 10, 16 ou 20 et des marges de 16 ou 20 sur un même écran.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  /// Affiche une bordure discrète. Utile en mode clair, où le fond de carte est
  /// très proche du fond d'écran et la carte se détacherait mal sans elle.
  final bool bordered;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.bordered = true,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: padding ?? const EdgeInsets.all(AppDimensions.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: bordered
            ? Border.all(color: AppColors.borderLight, width: 1)
            : null,
      ),
      child: child,
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        child: content,
      ),
    );
  }
}
