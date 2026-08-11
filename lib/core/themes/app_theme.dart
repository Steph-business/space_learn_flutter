import 'package:flutter/material.dart';

import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/themes/app_dimensions.dart';

/// Les deux ThemeData de l'application.
///
/// Ils vivaient dans `main.dart`, ce qui les rendait intestables et laissait
/// chaque ecran rehabiller ses composants faute de pouvoir verifier ce que le
/// theme fournissait deja.
///
/// Regle unique : **chaque theme decrit sa propre palette**. Rien ici ne doit
/// lire `AppColors.isDark` ni les getters qui en dependent — ils decrivent le
/// theme *actif*, alors qu'on construit ici les deux, dont celui qui n'est pas
/// affiche. Les couleurs se deduisent du parametre `brightness`.
class AppTheme {
  AppTheme._();

  /// Theme clair — celui par defaut de l'application.
  static ThemeData get clair => _construire(
    brightness: Brightness.light,
    scaffold: AppColors.scaffoldLight,
    surface: AppColors.cardLight,
    onSurface: AppColors.textOnLight,
  );

  /// Theme sombre.
  static ThemeData get sombre => _construire(
    brightness: Brightness.dark,
    scaffold: AppColors.scaffoldDark,
    surface: AppColors.cardDark,
    onSurface: AppColors.textOnDark,
  );

  /// Construit un ThemeData complet pour une luminosité donnée.
  ///
  /// Les surfaces et couleurs de texte sont fixées explicitement : plusieurs
  /// écrans lisent `Theme.of(context)` plutôt que `AppColors`, et les deux
  /// doivent décrire exactement la même palette pour éviter qu'une partie de
  /// l'interface reste sombre alors que l'autre est passée en clair.
  static ThemeData _construire({
    required Brightness brightness,
    required Color scaffold,
    required Color surface,
    required Color onSurface,
  }) {
    // L'encre d'accent se déduit de la luminosité *demandée*, jamais de
    // `AppColors.accentInk` : ce getter décrit le thème actif, alors qu'on
    // construit ici les deux ThemeData, dont celui qui n'est pas affiché.
    final accentInk = brightness == Brightness.dark
        ? AppColors.primary
        : AppColors.amberDark;

    // onPrimary et onSecondary doivent être imposés.
    //
    // `fromSeed` les déduit du germe, et sa déduction s'inverse d'un thème à
    // l'autre : blanc en clair, brun sombre en sombre. Or nos accents sont des
    // oranges clairs qui ne changent pas avec le thème. Le blanc déduit tenait
    // donc 1,80:1 sur #FFB156 — illisible — et tout ce qui lit le ColorScheme
    // en héritait : FilledButton, FAB, Chip, Switch, Slider, indicateurs de
    // progression. onAccent tient de 7,2:1 à 11,1:1 sur toute la gamme.
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
      primary: AppColors.primary,
      onPrimary: AppColors.onAccent,
      secondary: AppColors.secondary,
      onSecondary: AppColors.onAccent,
      surface: surface,
      onSurface: onSurface,
    );

    // WCAG 1.4.11 : un trait qui sert à *identifier* un composant — bordure de
    // champ, piste d'interrupteur au repos, côté de case à cocher — demande
    // 3:1 contre son fond. À 16 % d'opacité on était à 1,45:1 : le champ
    // n'était visible que si on savait déjà où il se trouvait.
    final traitVisible = onSurface.withValues(alpha: 0.45);

    return ThemeData(
      brightness: brightness,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: scaffold,
      colorScheme: colorScheme,
      canvasColor: scaffold,
      cardColor: surface,
      dividerColor: onSurface.withValues(alpha: 0.08),
      iconTheme: IconThemeData(color: onSurface),
      appBarTheme: AppBarTheme(
        backgroundColor: scaffold,
        foregroundColor: onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: onSurface),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: scaffold,
        // Encre sur le fond de l'écran, pas aplat : accentInk, sans quoi
        // l'onglet actif tient 1,80:1 en mode clair.
        selectedItemColor: accentInk,
        unselectedItemColor: onSurface.withValues(alpha: 0.55),
        elevation: 0,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: TextStyle(
          color: onSurface.withValues(alpha: 0.75),
          fontSize: 14,
          height: 1.5,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        ),
      ),

      // ── Ce qui suit était absent, et c'est ce qui obligeait chaque écran à
      // se rhabiller lui-même. Sans thème de bouton, chaque page redéfinissait
      // ses couleurs — d'où le blanc sur orange ici et le noir sur orange là.

      // Le SnackBar par défaut retombait sur inverseSurface, un brun sombre
      // (#372F27) qui n'appartient à aucune palette du produit : c'est ce que
      // voyaient les 16 appels directs à ScaffoldMessenger.
      snackBarTheme: SnackBarThemeData(
        // Même surface que les dialogues, les feuilles et les menus : une
        // seule couleur pour tout ce qui flotte au-dessus de la page. Une
        // variante teintée a été essayée, elle faisait tomber le libellé
        // d'action à 4,17:1.
        backgroundColor: surface,
        contentTextStyle: TextStyle(color: onSurface, fontSize: 13.5),
        actionTextColor: accentInk,
        behavior: SnackBarBehavior.floating,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onAccent,
          disabledBackgroundColor: onSurface.withValues(alpha: 0.10),
          disabledForegroundColor: onSurface.withValues(alpha: 0.38),
          elevation: 0,
          // Rembourrage vertical seulement. Les boutons de l'application
          // sont pleine largeur : un rembourrage horizontal ne les aère pas,
          // il retire 48 px à leur libellé. « Continuer avec Google »
          // débordait de 64 px sur un écran de 390.
          padding: const EdgeInsets.symmetric(vertical: AppDimensions.spaceLg),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusInner),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accentInk,
          side: BorderSide(color: accentInk.withValues(alpha: 0.55)),
          // Rembourrage vertical seulement. Les boutons de l'application
          // sont pleine largeur : un rembourrage horizontal ne les aère pas,
          // il retire 48 px à leur libellé. « Continuer avec Google »
          // débordait de 64 px sur un écran de 390.
          padding: const EdgeInsets.symmetric(vertical: AppDimensions.spaceLg),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusInner),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accentInk,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onAccent,
        elevation: 2,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: TextStyle(color: onSurface.withValues(alpha: 0.45)),
        labelStyle: TextStyle(color: onSurface.withValues(alpha: 0.70)),
        floatingLabelStyle: TextStyle(color: accentInk),
        prefixIconColor: onSurface.withValues(alpha: 0.60),
        suffixIconColor: onSurface.withValues(alpha: 0.60),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spaceLg,
          vertical: AppDimensions.spaceLg,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusInner),
          borderSide: BorderSide(color: traitVisible),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusInner),
          borderSide: BorderSide(color: traitVisible),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusInner),
          borderSide: BorderSide(color: accentInk, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusInner),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusInner),
          borderSide: const BorderSide(color: AppColors.error, width: 1.6),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: Color.alphaBlend(
          onSurface.withValues(alpha: 0.05),
          surface,
        ),
        selectedColor: AppColors.primary,
        checkmarkColor: AppColors.onAccent,
        labelStyle: TextStyle(color: onSurface, fontSize: 13),
        secondaryLabelStyle: const TextStyle(
          color: AppColors.onAccent,
          fontSize: 13,
        ),
        side: BorderSide(color: onSurface.withValues(alpha: 0.12)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
        ),
      ),

      // Les widgets à état utilisent WidgetStateProperty : sans résolution
      // explicite, l'état sélectionné retombe sur le ColorScheme et l'état au
      // repos sur un gris Material étranger à la palette.
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (etats) => etats.contains(WidgetState.selected)
              ? AppColors.onAccent
              : surface,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (etats) => etats.contains(WidgetState.selected)
              ? AppColors.primary
              : onSurface.withValues(alpha: 0.45),
        ),
        trackOutlineColor: WidgetStateProperty.all(traitVisible),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (etats) => etats.contains(WidgetState.selected)
              ? AppColors.primary
              : Colors.transparent,
        ),
        checkColor: WidgetStateProperty.all(AppColors.onAccent),
        side: BorderSide(color: traitVisible, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (etats) => etats.contains(WidgetState.selected)
              ? accentInk
              : onSurface.withValues(alpha: 0.40),
        ),
      ),
      sliderTheme: SliderThemeData(
        // La piste active identifie la valeur choisie : c'est un trait sur le
        // fond de l'écran, donc accentInk. En primary elle tenait 1,80:1.
        activeTrackColor: accentInk,
        inactiveTrackColor: onSurface.withValues(alpha: 0.14),
        thumbColor: accentInk,
        overlayColor: AppColors.primary.withValues(alpha: 0.16),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: accentInk,
        linearTrackColor: onSurface.withValues(alpha: 0.10),
        circularTrackColor: Colors.transparent,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: accentInk,
        unselectedLabelColor: onSurface.withValues(alpha: 0.55),
        indicatorColor: accentInk,
        dividerColor: Colors.transparent,
      ),
      dividerTheme: DividerThemeData(
        color: onSurface.withValues(alpha: 0.08),
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: onSurface.withValues(alpha: 0.70),
        textColor: onSurface,
        selectedColor: accentInk,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusInner),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        textStyle: TextStyle(color: onSurface, fontSize: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusInner),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: Color.alphaBlend(onSurface.withValues(alpha: 0.90), surface),
          borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
        ),
        textStyle: TextStyle(color: surface, fontSize: 12),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: accentInk,
        selectionColor: AppColors.primary.withValues(alpha: 0.35),
        selectionHandleColor: accentInk,
      ),
    );
  }
}
