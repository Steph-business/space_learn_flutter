// Vérifie le contraste de chaque paire fond/encre que les deux ThemeData
// fournissent réellement, en les construisant.
//
// Les valeurs ne sont pas relues dans la palette : elles sortent des ThemeData,
// donc le test attrape aussi bien une palette modifiée qu'un thème de composant
// mal câblé — c'est exactement ce qui était arrivé à `onPrimary`, déduit par
// Material à #FFFFFF sur un accent #FFB156, soit 1,80:1.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/themes/app_theme.dart';

/// Seuil WCAG AA pour du texte de taille courante.
const double seuilTexte = 4.5;

/// Seuil WCAG AA pour un élément d'interface non textuel (trait, bordure,
/// indicateur, piste de curseur).
const double seuilElement = 3.0;

double _lineariser(double canal) => canal <= 0.03928
    ? canal / 12.92
    : math.pow((canal + 0.055) / 1.055, 2.4).toDouble();

double _luminance(Color c) =>
    0.2126 * _lineariser(c.r) +
    0.7152 * _lineariser(c.g) +
    0.0722 * _lineariser(c.b);

double contraste(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// Aplatit une couleur translucide sur son fond, sans quoi le calcul de
/// contraste porte sur une couleur qui n'est jamais affichée telle quelle.
Color _sur(Color premierPlan, Color fond) =>
    Color.alphaBlend(premierPlan, fond);

void main() {
  for (final cas in [
    (nom: 'clair', theme: AppTheme.clair),
    (nom: 'sombre', theme: AppTheme.sombre),
  ]) {
    group('thème ${cas.nom}', () {
      final t = cas.theme;
      final cs = t.colorScheme;
      final fond = t.scaffoldBackgroundColor;

      void verifier(String quoi, Color encre, Color surface, double seuil) {
        final r = contraste(_sur(encre, surface), surface);
        expect(
          r,
          greaterThanOrEqualTo(seuil),
          reason:
              '$quoi : ${_hex(encre)} sur ${_hex(surface)} '
              '= ${r.toStringAsFixed(2)}:1, seuil ${seuil.toStringAsFixed(1)}:1',
        );
      }

      test('paires du ColorScheme', () {
        verifier('onPrimary sur primary', cs.onPrimary, cs.primary, seuilTexte);
        verifier(
          'onSecondary sur secondary',
          cs.onSecondary,
          cs.secondary,
          seuilTexte,
        );
        verifier('onSurface sur surface', cs.onSurface, cs.surface, seuilTexte);
        verifier('onError sur error', cs.onError, cs.error, seuilTexte);
      });

      test('boutons', () {
        final plein = t.elevatedButtonTheme.style!;
        verifier(
          'libellé du bouton plein',
          plein.foregroundColor!.resolve({})!,
          plein.backgroundColor!.resolve({})!,
          seuilTexte,
        );
        verifier(
          'libellé du bouton contour',
          t.outlinedButtonTheme.style!.foregroundColor!.resolve({})!,
          fond,
          seuilTexte,
        );
        verifier(
          'libellé du bouton plat',
          t.textButtonTheme.style!.foregroundColor!.resolve({})!,
          fond,
          seuilTexte,
        );
        verifier(
          'icône du bouton flottant',
          t.floatingActionButtonTheme.foregroundColor!,
          t.floatingActionButtonTheme.backgroundColor!,
          seuilTexte,
        );
      });

      test('surfaces flottantes', () {
        final snack = t.snackBarTheme;
        verifier(
          'message du bandeau',
          snack.contentTextStyle!.color!,
          snack.backgroundColor!,
          seuilTexte,
        );
        verifier(
          'action du bandeau',
          snack.actionTextColor!,
          snack.backgroundColor!,
          seuilTexte,
        );

        final dialogue = t.dialogTheme;
        verifier(
          'titre du dialogue',
          dialogue.titleTextStyle!.color!,
          dialogue.backgroundColor!,
          seuilTexte,
        );
        verifier(
          'corps du dialogue',
          dialogue.contentTextStyle!.color!,
          dialogue.backgroundColor!,
          seuilTexte,
        );

        verifier(
          'menu contextuel',
          t.popupMenuTheme.textStyle!.color!,
          t.popupMenuTheme.color!,
          seuilTexte,
        );
      });

      test('champs de saisie', () {
        final champ = t.inputDecorationTheme;
        verifier(
          'libellé du champ',
          champ.labelStyle!.color!,
          champ.fillColor!,
          seuilTexte,
        );
        verifier(
          'bordure au repos',
          (champ.enabledBorder! as OutlineInputBorder).borderSide.color,
          champ.fillColor!,
          seuilElement,
        );
        verifier(
          'bordure au focus',
          (champ.focusedBorder! as OutlineInputBorder).borderSide.color,
          champ.fillColor!,
          seuilElement,
        );
      });

      test('éléments à état et indicateurs', () {
        const selectionne = {WidgetState.selected};

        verifier(
          'pastille de l\'interrupteur actif',
          t.switchTheme.thumbColor!.resolve(selectionne)!,
          t.switchTheme.trackColor!.resolve(selectionne)!,
          seuilElement,
        );
        verifier(
          'piste de l\'interrupteur au repos',
          t.switchTheme.trackColor!.resolve({})!,
          fond,
          seuilElement,
        );

        verifier(
          'coche de la case',
          t.checkboxTheme.checkColor!.resolve(selectionne)!,
          t.checkboxTheme.fillColor!.resolve(selectionne)!,
          seuilElement,
        );

        verifier(
          'indicateur de progression',
          t.progressIndicatorTheme.color!,
          fond,
          seuilElement,
        );
        verifier(
          'piste active du curseur',
          t.sliderTheme.activeTrackColor!,
          fond,
          seuilElement,
        );

        verifier('onglet actif', t.tabBarTheme.labelColor!, fond, seuilTexte);
        verifier(
          'élément de navigation actif',
          t.bottomNavigationBarTheme.selectedItemColor!,
          fond,
          seuilTexte,
        );
      });
    });
  }

  // ── L'échelle de gris d'AppColors ─────────────────────────────────────
  //
  // Ces valeurs avaient été réglées pour un fond noir et jamais revues au
  // passage en clair : textMuted tenait 2,56:1 sur blanc, textHint 3,54:1.
  // Le test les mesure dans les deux thèmes, sur le fond d'écran comme sur la
  // carte — un texte n'est pas toujours posé sur la même surface.
  group('échelle de gris', () {
    late bool sombreInitial;

    setUp(() => sombreInitial = AppColors.isDark);
    tearDown(() => AppColors.isDark = sombreInitial);

    void mesurer(String mode, bool sombre) {
      test('textes discrets lisibles en mode $mode', () {
        AppColors.isDark = sombre;
        final fond = AppColors.scaffoldBackground;
        final carte = AppColors.cardBackground;

        for (final e in {
          'textPrimary': AppColors.textPrimary,
          'textSecondary': AppColors.textSecondary,
          'textHint': AppColors.textHint,
          'textMuted': AppColors.textMuted,
        }.entries) {
          for (final surface in {'fond': fond, 'carte': carte}.entries) {
            final r = contraste(e.value, surface.value);
            expect(
              r,
              greaterThanOrEqualTo(seuilTexte),
              reason:
                  '${e.key} sur ${surface.key} : ${_hex(e.value)} sur '
                  '${_hex(surface.value)} = ${r.toStringAsFixed(2)}:1',
            );
          }
        }
      });

      test('la carte se distingue du fond en mode $mode', () {
        AppColors.isDark = sombre;
        final r = contraste(
          AppColors.cardBackground,
          AppColors.scaffoldBackground,
        );
        // Une carte n'est pas un texte : le seuil n'est pas celui de WCAG, mais
        // une carte à 1,05:1 est simplement invisible.
        expect(
          r,
          greaterThanOrEqualTo(1.06),
          reason:
              'carte ${_hex(AppColors.cardBackground)} sur fond '
              '${_hex(AppColors.scaffoldBackground)} = ${r.toStringAsFixed(3)}:1',
        );
      });
    }

    mesurer('clair', false);
    mesurer('sombre', true);
  });

  // Les deux thèmes doivent décrire des palettes distinctes : c'est le défaut
  // qui laissait le mode clair avec un fond noir.
  test('les deux thèmes ne partagent pas leurs surfaces', () {
    expect(
      AppTheme.clair.scaffoldBackgroundColor,
      isNot(AppTheme.sombre.scaffoldBackgroundColor),
    );
    expect(
      AppTheme.clair.colorScheme.onSurface,
      isNot(AppTheme.sombre.colorScheme.onSurface),
    );
  });
}
