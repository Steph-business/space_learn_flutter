// Garde-fou du système de couleurs.
//
// Ces règles ne sont pas des préférences de style : chacune correspond à un
// contraste mesuré sous le seuil WCAG AA, constaté dans l'application.
// Le test échoue en nommant le fichier et la ligne fautive.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _racine = 'lib';

/// Aplats d'accent : constantes claires, qui ne changent pas avec le thème.
const _aplats = [
  'primary',
  'primaryLight',
  'primaryDark',
  'secondary',
  'secondaryVariant',
  'orange',
  'blueRoyal',
];

/// Encres qui ne tiennent pas sur un aplat d'accent — soit parce qu'elles
/// s'inversent avec le thème, soit parce qu'elles sont blanches.
final _encresInterdites = RegExp(
  r'\b(color|foregroundColor)\s*:\s*(AppColors\.textPrimary|AppColors\.textOnDark|'
  r'AppColors\.textOnLight|Colors\.white|Colors\.black87|Colors\.black)\b(?!\s*\.)',
);

final _fondAccent = RegExp(
  '(backgroundColor|color)\\s*:\\s*AppColors\\.(${_aplats.join('|')})\\b(?!\\s*\\.)',
);

final _appel = RegExp(r'([A-Za-z_][A-Za-z0-9_.]*)\s*\($');

/// Objets de style : l'aplat s'y déclare, mais l'encre vit chez le parent.
const _objetsDeStyle = {
  'styleFrom',
  'BoxDecoration',
  'ShapeDecoration',
  'copyWith',
  'IconThemeData',
};

List<File> _fichiersDart() {
  final dossier = Directory(_racine);
  if (!dossier.existsSync()) {
    fail('Répertoire $_racine introuvable — le test doit tourner à la racine du projet.');
  }
  return dossier
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();
}

/// Position de la parenthèse ouvrant la liste d'arguments contenant [pos],
/// et nom du constructeur correspondant.
(int?, String?) _ouvrePortee(String texte, int pos) {
  var profondeur = 0;
  for (var i = pos - 1; i >= 0; i--) {
    final c = texte[i];
    if (')]}'.contains(c)) {
      profondeur++;
    } else if ('([{'.contains(c)) {
      if (profondeur == 0) {
        if (c != '(') return (null, null);
        final debut = i - 80 < 0 ? 0 : i - 80;
        final m = _appel.firstMatch(texte.substring(debut, i + 1));
        return (i, m == null ? null : m.group(1)!.split('.').last);
      }
      profondeur--;
    }
  }
  return (null, null);
}

int _ferme(String texte, int ouvrante) {
  var profondeur = 0;
  for (var i = ouvrante; i < texte.length; i++) {
    final c = texte[i];
    if ('([{'.contains(c)) {
      profondeur++;
    } else if (')]}'.contains(c)) {
      profondeur--;
      if (profondeur == 0) return i;
    }
  }
  return texte.length;
}

int _ligneDe(String texte, int index) => '\n'.allMatches(texte.substring(0, index)).length + 1;

void main() {
  // ── Règle 1 ────────────────────────────────────────────────────────────
  // AppColors.primary vaut #FFB156 dans les deux thèmes. Poser dessus une
  // encre qui, elle, suit le thème donne un résultat qui s'inverse : lisible
  // dans un mode, illisible dans l'autre (1,80:1 pour du blanc sur #FFB156).
  // AppColors.onAccent tient de 7,2:1 à 11,1:1 sur toute la gamme d'accent.
  test('aucune encre dépendante du thème ni de blanc sur un aplat d\'accent', () {
    final fautes = <String>[];

    for (final fichier in _fichiersDart()) {
      if (fichier.path.replaceAll(r'\', '/').endsWith('core/themes/app_colors.dart')) {
        continue;
      }
      final texte = fichier.readAsStringSync();

      for (final fond in _fondAccent.allMatches(texte)) {
        final debutLigne = texte.lastIndexOf('\n', fond.start) + 1;
        var finLigne = texte.indexOf('\n', fond.start);
        if (finLigne < 0) finLigne = texte.length;
        final ligne = texte.substring(debutLigne, finLigne);
        // Un aplat translucide ne porte pas de texte à plein contraste.
        if (ligne.contains('withValues') || ligne.contains('withOpacity')) continue;

        var (ouv, ctor) = _ouvrePortee(texte, fond.start);
        if (ouv == null) continue;
        if (_objetsDeStyle.contains(ctor)) {
          final (parent, _) = _ouvrePortee(texte, ouv);
          if (parent != null) ouv = parent;
        }
        final fin = _ferme(texte, ouv);

        for (final e in _encresInterdites.allMatches(texte.substring(ouv, fin))) {
          fautes.add('${fichier.path}:${_ligneDe(texte, ouv + e.start)} '
              '— ${e.group(2)} posé sur AppColors.${fond.group(2)} '
              '(utiliser AppColors.onAccent)');
        }
      }
    }

    expect(fautes, isEmpty,
        reason: '${fautes.length} encre(s) illisible(s) sur un aplat d\'accent :\n'
            '${fautes.join('\n')}');
  });

  // ── Règle 2 ────────────────────────────────────────────────────────────
  // Un fond écrit en dur ne suit aucun thème. C'est ce qui rendait les
  // notifications d'erreur (#1E1B1B) et le dialogue de paiement (#1E1E2E)
  // invisibles en mode clair : noir sur noir, 1,23:1.
  test('aucune surface flottante ne porte de fond écrit en dur', () {
    final surfaceEnDur = RegExp(r'backgroundColor\s*:\s*(const\s+)?Color\(0x');
    final fautes = <String>[];

    for (final fichier in _fichiersDart()) {
      final lignes = fichier.readAsLinesSync();
      for (var i = 0; i < lignes.length; i++) {
        if (surfaceEnDur.hasMatch(lignes[i])) {
          fautes.add('${fichier.path}:${i + 1} — ${lignes[i].trim()}');
        }
      }
    }

    expect(fautes, isEmpty,
        reason: 'Fond(s) hors palette :\n${fautes.join('\n')}');
  });

  // ── Règle 3 ────────────────────────────────────────────────────────────
  // Les bandeaux passent tous par AppNotifications. Les appels directs à
  // ScaffoldMessenger portaient 12 fonds différents pour deux états, et
  // 16 d'entre eux n'en fixaient aucun : Flutter retombait alors sur
  // inverseSurface, un brun #372F27 étranger à la palette du produit.
  test('les bandeaux passent tous par AppNotifications', () {
    final appelDirect = RegExp(r'(?<!AppNotifications)\.\s*showSnackBar\s*\(');
    final fautes = <String>[];

    for (final fichier in _fichiersDart()) {
      final chemin = fichier.path.replaceAll(r'\', '/');
      if (chemin.endsWith('core/utils/app_notifications.dart')) continue;

      final lignes = fichier.readAsLinesSync();
      for (var i = 0; i < lignes.length; i++) {
        if (appelDirect.hasMatch(lignes[i])) {
          fautes.add('${fichier.path}:${i + 1} — ${lignes[i].trim()}');
        }
      }
    }

    expect(fautes, isEmpty,
        reason: 'Bandeau(x) hors AppNotifications :\n${fautes.join('\n')}');
  });
}
