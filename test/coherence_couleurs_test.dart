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

/// Widgets dont le paramètre `color` peint l'objet lui-même, et non un fond
/// derrière du texte.
///
/// La couleur d'un RefreshIndicator est celle de son arc. La règle la lisait
/// comme un aplat, puis inspectait tout ce que l'indicateur contient — donc la
/// page entière — et signalait chaque encre qui s'y trouvait. Deux titres de la
/// page communauté étaient accusés de reposer sur un fond qui n'existe pas.
const _couleursDObjet = {
  'RefreshIndicator',
  'CircularProgressIndicator',
  'LinearProgressIndicator',
  'Icon',
  'Divider',
  'VerticalDivider',
  'TextStyle',
  'poppins',
  'inter',
};

List<File> _fichiersDart() {
  final dossier = Directory(_racine);
  if (!dossier.existsSync()) {
    fail(
      'Répertoire $_racine introuvable — le test doit tourner à la racine du projet.',
    );
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

int _ligneDe(String texte, int index) =>
    '\n'.allMatches(texte.substring(0, index)).length + 1;

void main() {
  // ── Règle 1 ────────────────────────────────────────────────────────────
  // AppColors.primary vaut #FFB156 dans les deux thèmes. Poser dessus une
  // encre qui, elle, suit le thème donne un résultat qui s'inverse : lisible
  // dans un mode, illisible dans l'autre (1,80:1 pour du blanc sur #FFB156).
  // AppColors.onAccent tient de 7,2:1 à 11,1:1 sur toute la gamme d'accent.
  test(
    'aucune encre dépendante du thème ni de blanc sur un aplat d\'accent',
    () {
      final fautes = <String>[];

      for (final fichier in _fichiersDart()) {
        if (fichier.path
            .replaceAll(r'\', '/')
            .endsWith('core/themes/app_colors.dart')) {
          continue;
        }
        final texte = fichier.readAsStringSync();

        for (final fond in _fondAccent.allMatches(texte)) {
          final debutLigne = texte.lastIndexOf('\n', fond.start) + 1;
          var finLigne = texte.indexOf('\n', fond.start);
          if (finLigne < 0) finLigne = texte.length;
          final ligne = texte.substring(debutLigne, finLigne);
          // Un aplat translucide ne porte pas de texte à plein contraste.
          if (ligne.contains('withValues') || ligne.contains('withOpacity'))
            continue;

          var (ouv, ctor) = _ouvrePortee(texte, fond.start);
          if (ouv == null) continue;
          // `color:` peint parfois l'objet et non le fond derrière lui.
          if (fond.group(1) == 'color' && _couleursDObjet.contains(ctor)) {
            continue;
          }
          if (_objetsDeStyle.contains(ctor)) {
            final (parent, _) = _ouvrePortee(texte, ouv);
            if (parent != null) ouv = parent;
          }
          final fin = _ferme(texte, ouv);

          for (final e in _encresInterdites.allMatches(
            texte.substring(ouv, fin),
          )) {
            fautes.add(
              '${fichier.path}:${_ligneDe(texte, ouv + e.start)} '
              '— ${e.group(2)} posé sur AppColors.${fond.group(2)} '
              '(utiliser AppColors.onAccent)',
            );
          }
        }
      }

      expect(
        fautes,
        isEmpty,
        reason:
            '${fautes.length} encre(s) illisible(s) sur un aplat d\'accent :\n'
            '${fautes.join('\n')}',
      );
    },
  );

  // ── Règle 1 bis ────────────────────────────────────────────────────────
  // Un dégradé est un aplat, lui aussi.
  //
  // La règle 1 ne voit que `backgroundColor:` et `color:` posés sur une
  // couleur d'accent nommée. Les cartes de citations de l'accueil peignaient
  // leur fond avec `gradient: LinearGradient(colors: …)`, dont la liste venait
  // d'une donnée : rien à lire dans le source, donc rien à signaler. Toute leur
  // encre — étoiles, citation, nom du lecteur — utilisait
  // `AppColors.textPrimary`, qui suit le fond de la PAGE et non celui de la
  // carte. En thème clair l'encre sombre passait par chance sur l'orange ;
  // en thème sombre elle devient claire, et la carte entière s'efface.
  //
  // On ne cherche donc plus la couleur du fond, mais le simple fait qu'il y en
  // ait un : dès qu'une décoration porte un `gradient:`, l'encre de ce qu'elle
  // contient doit être `onAccent`.
  test('aucune encre dépendante du thème sur un dégradé', () {
    final fautes = <String>[];

    for (final fichier in _fichiersDart()) {
      final chemin = fichier.path.replaceAll(r'\\', '/');
      if (chemin.endsWith('core/themes/app_colors.dart')) continue;

      final texte = fichier.readAsStringSync();

      for (final degrade in RegExp(r'\bgradient\s*:').allMatches(texte)) {
        // La décoration qui porte ce dégradé, puis le widget qu'elle habille :
        // l'encre vit chez l'enfant, pas dans la décoration.
        var (ouv, _) = _ouvrePortee(texte, degrade.start);
        if (ouv == null) continue;
        final (parent, _) = _ouvrePortee(texte, ouv);
        if (parent != null) ouv = parent;

        final fin = _ferme(texte, ouv);

        for (final e in _encresInterdites.allMatches(
          texte.substring(ouv, fin),
        )) {
          fautes.add(
            '${fichier.path}:${_ligneDe(texte, ouv + e.start)} '
            '— ${e.group(2)} posé sur un dégradé (utiliser AppColors.onAccent)',
          );
        }
      }
    }

    expect(
      fautes,
      isEmpty,
      reason:
          '${fautes.length} encre(s) illisible(s) sur un dégradé :\n'
          '${fautes.join('\n')}',
    );
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

    expect(
      fautes,
      isEmpty,
      reason: 'Fond(s) hors palette :\n${fautes.join('\n')}',
    );
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

    expect(
      fautes,
      isEmpty,
      reason: 'Bandeau(x) hors AppNotifications :\n${fautes.join('\n')}',
    );
  });

  // ── Règle 4 ────────────────────────────────────────────────────────────
  // Deux familles, deux rôles : Poppins porte l'interface, Lora le texte des
  // livres. Le code en comptait quatre — Hanken Grotesk n'existait que dans
  // AppTextStyles et Outfit n'apparaissait que par accident, sept fois.
  test('deux familles de police, et seulement deux', () {
    const autorisees = {'poppins', 'lora'};
    final usage = RegExp(r'GoogleFonts\.(\w+)');
    final fautes = <String>[];

    for (final fichier in _fichiersDart()) {
      final lignes = fichier.readAsLinesSync();
      for (var i = 0; i < lignes.length; i++) {
        for (final m in usage.allMatches(lignes[i])) {
          final famille = m.group(1)!;
          if (!autorisees.contains(famille)) {
            fautes.add('${fichier.path}:${i + 1} — GoogleFonts.$famille');
          }
        }
      }
    }

    expect(
      fautes,
      isEmpty,
      reason: 'Police(s) hors système :\n${fautes.join('\n')}',
    );
  });

  // ── Règle 4 bis ────────────────────────────────────────────────────────
  // Une couleur de texte n'est pas une surface.
  //
  // La barre de recherche du lecteur peignait son fond en AppColors
  // .textPrimary — la couleur la plus contrastée de la palette, faite pour
  // être LUE sur un fond, jamais pour en être un — puis y posait du texte
  // noir. En thème clair, textPrimary est presque noir : on tapait donc du
  // noir sur du noir, sans voir ce qu'on cherchait. La feuille du sommaire
  // faisait la même chose sur toute sa hauteur.
  //
  // La règle ne vise que textPrimary à pleine intensité : une teinte à faible
  // opacité fait une surface discrète légitime, et textHint ou textSecondary
  // servent parfois de trait — une poignée, une piste de progression.
  test('aucune couleur de texte ne sert de surface', () {
    // La règle ne regardait que `BoxDecoration(color: textPrimary)`.
    //
    // Elle a laissé passer `fillColor: AppColors.textHint` sur le champ de
    // l'écran « Commençons par votre nom » : une boîte gris foncé sur un
    // écran clair, portant un texte presque noir. Trois angles morts d'un
    // coup — la propriété (`fillColor`), le jeton (`textHint`), et le fait
    // que ce n'était pas une `BoxDecoration`.
    //
    // Elle couvre désormais les trois propriétés qui posent une surface, et
    // tous les jetons de texte.
    // Seuls les usages à PLEINE opacité sont fautifs.
    //
    // `AppColors.textPrimary.withOpacity(0.12)` est un voile teinté : il suit
    // le thème, reste discret, et sert légitimement de filet ou de fond de
    // pastille. C'est la couleur pleine qui pose problème — elle est faite
    // pour être lue, pas pour porter du texte.
    final surfaces = RegExp(
      r'(?:BoxDecoration\(\s*color|fillColor|backgroundColor)'
      r':\s*AppColors\.(textPrimary|textSecondary|textHint)\b(?!\s*\.with)',
      multiLine: true,
    );
    final fautes = <String>[];

    for (final fichier in _fichiersDart()) {
      final source = fichier.readAsStringSync();
      for (final m in surfaces.allMatches(source)) {
        final ligne = source.substring(0, m.start).split('\n').length;
        fautes.add('${fichier.path}:$ligne — AppColors.${m.group(1)} en fond');
      }
    }

    expect(
      fautes,
      isEmpty,
      reason:
          'Une couleur de TEXTE employée comme fond : le contenu posé dessus '
          'devient illisible, et la surface ne suit plus le thème. Utiliser '
          'cardBackground, surfaceVariant ou scaffoldBackground :\n'
          '${fautes.join('\n')}',
    );
  });

  // ── Règle 5 ────────────────────────────────────────────────────────────
  // Quatorze rayons distincts circulaient (2, 3, 4, 6, 8, 10, 12, 14, 15, 16,
  // 20, 24, 28, 30) : deux cartes voisines n'avaient pas le même arrondi.
  // L'échelle vit dans AppDimensions.
  test('aucun rayon écrit en dur', () {
    final rayonLitteral = RegExp(r'BorderRadius\.circular\(\s*\d');
    final fautes = <String>[];

    for (final fichier in _fichiersDart()) {
      final lignes = fichier.readAsLinesSync();
      for (var i = 0; i < lignes.length; i++) {
        if (rayonLitteral.hasMatch(lignes[i])) {
          fautes.add('${fichier.path}:${i + 1} — ${lignes[i].trim()}');
        }
      }
    }

    expect(
      fautes,
      isEmpty,
      reason: 'Rayon(s) hors AppDimensions :\n${fautes.join('\n')}',
    );
  });

  // ── Règle 5 bis ────────────────────────────────────────────────────────
  // Une feuille est une route à part, et doit s'abonner comme les autres.
  //
  // La règle 6 ne regarde que les méthodes `build`. Le corps d'un
  // `showModalBottomSheet` n'en est pas une : il lisait donc la palette laissée
  // par le dernier écran construit, et gardait cette teinte tant qu'il restait
  // ouvert. Le sommaire du lecteur s'affichait noir au-dessus d'une page
  // claire. Les six feuilles du dépôt étaient dans ce cas — aucune n'était
  // abonnée.
  //
  // Seules comptent celles dont le CORPS lit la palette : `backgroundColor:
  // AppColors.x` passé en argument est évalué dans le contexte appelant, qui
  // est abonné, lui.
  test('les feuilles modales s\'abonnent au thème', () {
    final fautes = <String>[];

    for (final fichier in _fichiersDart()) {
      final texte = fichier.readAsStringSync();
      var i = 0;
      while (true) {
        i = texte.indexOf('showModalBottomSheet(', i);
        if (i < 0) break;

        // Fin de l'appel : la parenthèse qui referme.
        var profondeur = 0;
        var j = i + 'showModalBottomSheet'.length;
        while (j < texte.length) {
          if (texte[j] == '(') profondeur++;
          if (texte[j] == ')') {
            profondeur--;
            if (profondeur == 0) break;
          }
          j++;
        }

        final appel = texte.substring(i, j);
        final debutCorps = appel.indexOf('builder:');
        final corps = debutCorps >= 0 ? appel.substring(debutCorps) : '';

        if (corps.contains('AppColors.') && !corps.contains('suivreLeTheme')) {
          final ligne = '\n'.allMatches(texte.substring(0, i)).length + 1;
          fautes.add('${fichier.path}:$ligne');
        }
        i = j;
      }
    }

    expect(
      fautes,
      isEmpty,
      reason:
          'Feuille(s) lisant la palette sans AppColors.suivreLeTheme(context) '
          'en tête de leur builder :\n${fautes.join('\n')}',
    );
  });

  // ── Règle 6 ────────────────────────────────────────────────────────────
  // Tout écran qui lit la palette doit s'abonner au thème.
  //
  // AppColors.isDark est une variable globale : la lire ne crée aucune
  // dépendance, donc une page déjà à l'écran garde les couleurs qu'elle avait
  // au moment de sa construction. On obtenait un en-tête clair au-dessus d'une
  // page sombre, chacun figé sur le thème actif quand il a été bâti.
  test('les écrans qui lisent la palette s\'abonnent au thème', () {
    final debutBuild = RegExp(r'Widget build\(BuildContext (\w+)\) \{');
    final fautes = <String>[];

    for (final fichier in _fichiersDart()) {
      final chemin = fichier.path.replaceAll(r'\', '/');
      if (chemin.endsWith('core/themes/app_colors.dart')) continue;

      final texte = fichier.readAsStringSync();
      if (!texte.contains('AppColors.')) continue;

      for (final m in debutBuild.allMatches(texte)) {
        // L'abonnement doit être la première chose que fait le build.
        final entete = texte.substring(
          m.end,
          (m.end + 200).clamp(0, texte.length),
        );
        if (!entete.contains('suivreLeTheme')) {
          final ligne = '\n'.allMatches(texte.substring(0, m.start)).length + 1;
          fautes.add('${fichier.path}:$ligne');
        }
      }
    }

    expect(
      fautes,
      isEmpty,
      reason:
          '${fautes.length} écran(s) lisant AppColors sans '
          'AppColors.suivreLeTheme(context) en tête de build :\n'
          '${fautes.join('\n')}',
    );
  });
}
