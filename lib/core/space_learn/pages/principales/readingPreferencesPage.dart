import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:space_learn_flutter/core/services/preferences_lecture.dart';
import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/themes/app_dimensions.dart';
import 'package:space_learn_flutter/core/utils/app_notifications.dart';

/// Réglages de confort de lecture, avant d'ouvrir un livre.
///
/// Cette page proposait une police, une taille de texte, un mode nuit et un
/// thème — quatre réglages enregistrés sous des clés que **rien** dans
/// l'application ne lisait. On choisissait, on appuyait sur « Sauvegarder », et
/// aucun de ces choix n'atteignait le lecteur, qui lisait de son côté quatre
/// autres clés. Deux écrans qui semblaient régler la même chose, dont un seul
/// avait un effet.
///
/// Elle règle désormais exactement ce que le lecteur applique, par les mêmes
/// clés (cf. [PreferencesLecture]). Ce qu'on choisit ici, on le retrouve en
/// ouvrant un livre, et inversement.
///
/// La police disparaît : rien dans le lecteur ne sait l'appliquer. Proposer un
/// choix sans effet est précisément le défaut qu'on corrige.
class ReadingPreferencesPage extends StatefulWidget {
  const ReadingPreferencesPage({super.key});

  @override
  State<ReadingPreferencesPage> createState() => _ReadingPreferencesPageState();
}

class _ReadingPreferencesPageState extends State<ReadingPreferencesPage> {
  Reglages _reglages = Reglages.defaut;
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final r = await PreferencesLecture.charger();
    if (mounted) {
      setState(() {
        _reglages = r;
        _chargement = false;
      });
    }
  }

  /// Enregistre à chaque geste.
  ///
  /// L'ancienne page exigeait d'appuyer sur « Sauvegarder » : quitter l'écran
  /// autrement perdait tout, sans avertissement.
  Future<void> _appliquer(Reglages nouveau) async {
    setState(() => _reglages = nouveau);
    await PreferencesLecture.enregistrer(nouveau);
  }

  @override
  Widget build(BuildContext context) {
    AppColors.suivreLeTheme(context);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: Text(
          'Confort de lecture',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppDimensions.screenPadding),
              children: [
                _Apercu(reglages: _reglages),
                const SizedBox(height: AppDimensions.spaceXl),

                _titre('Fond de page'),
                const SizedBox(height: AppDimensions.spaceSm),
                Row(
                  children: [
                    for (final fond in PreferencesLecture.fondsDePage) ...[
                      Expanded(
                        child: _VignetteFond(
                          nom: fond.nom,
                          fond: fond.fond,
                          texte: fond.texte,
                          choisi:
                              _reglages.fondDePage.toARGB32() ==
                              fond.fond.toARGB32(),
                          onTap: () => _appliquer(
                            _reglages.copier(fondDePage: fond.fond),
                          ),
                        ),
                      ),
                      if (fond != PreferencesLecture.fondsDePage.last)
                        const SizedBox(width: AppDimensions.spaceMd),
                    ],
                  ],
                ),

                const SizedBox(height: AppDimensions.spaceXl),

                _titre('Luminosité'),
                _curseur(
                  valeur: _reglages.luminosite,
                  min: 0.25,
                  max: 1.0,
                  iconeMin: Icons.brightness_low,
                  iconeMax: Icons.brightness_high,
                  onChanged: (v) => _appliquer(_reglages.copier(luminosite: v)),
                ),

                const SizedBox(height: AppDimensions.spaceXl),

                _titre('Agrandissement'),
                _curseur(
                  valeur: _reglages.agrandissement,
                  min: 0.5,
                  max: 3.0,
                  iconeMin: Icons.zoom_out,
                  iconeMax: Icons.zoom_in,
                  onChanged: (v) =>
                      _appliquer(_reglages.copier(agrandissement: v)),
                ),

                const SizedBox(height: AppDimensions.spaceXl),

                _titre('Sens de lecture'),
                const SizedBox(height: AppDimensions.spaceSm),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: false,
                      label: Text('Vertical'),
                      icon: Icon(Icons.swap_vert),
                    ),
                    ButtonSegment(
                      value: true,
                      label: Text('Horizontal'),
                      icon: Icon(Icons.swap_horiz),
                    ),
                  ],
                  selected: {_reglages.sensHorizontal},
                  onSelectionChanged: (s) =>
                      _appliquer(_reglages.copier(sensHorizontal: s.first)),
                ),

                const SizedBox(height: AppDimensions.spaceXl * 2),

                Center(
                  child: TextButton.icon(
                    onPressed: () async {
                      await _appliquer(Reglages.defaut);
                      if (mounted) {
                        AppNotifications.showSnackBar(
                          context,
                          message: 'Réglages de lecture réinitialisés',
                          isSuccess: true,
                        );
                      }
                    },
                    icon: const Icon(Icons.restart_alt, size: 18),
                    label: const Text('Rétablir les valeurs par défaut'),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _titre(String texte) {
    return Text(
      texte.toUpperCase(),
      style: GoogleFonts.poppins(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: AppColors.textSecondary,
      ),
    );
  }

  Widget _curseur({
    required double valeur,
    required double min,
    required double max,
    required IconData iconeMin,
    required IconData iconeMax,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        Icon(iconeMin, size: 18, color: AppColors.textSecondary),
        Expanded(
          child: Slider(
            value: valeur,
            min: min,
            max: max,
            divisions: 15,
            label: '${(valeur * 100).round()} %',
            onChanged: onChanged,
          ),
        ),
        Icon(iconeMax, size: 22, color: AppColors.textSecondary),
        const SizedBox(width: AppDimensions.spaceMd),
        SizedBox(
          width: 48,
          child: Text(
            '${(valeur * 100).round()} %',
            textAlign: TextAlign.end,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.accentInk,
            ),
          ),
        ),
      ],
    );
  }
}

/// Aperçu de ce que donneront les réglages, avec du vrai texte.
///
/// L'ancienne page en avait un, mais il montrait une police et une taille sans
/// effet réel. Celui-ci applique le fond et la luminosité tels que le lecteur
/// les appliquera.
class _Apercu extends StatelessWidget {
  final Reglages reglages;

  const _Apercu({required this.reglages});

  @override
  Widget build(BuildContext context) {
    AppColors.suivreLeTheme(context);
    final couleurTexte = PreferencesLecture.fondsDePage
        .firstWhere(
          (f) => f.fond.toARGB32() == reglages.fondDePage.toARGB32(),
          orElse: () => PreferencesLecture.fondsDePage.first,
        )
        .texte;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            color: reglages.fondDePage,
            padding: const EdgeInsets.all(AppDimensions.spaceXl),
            child: Text(
              "Le soleil se levait à peine sur la lagune lorsque Awa "
              "referma le carnet de son grand-père. Il lui restait une "
              "page, et toute une vie pour la comprendre.",
              style: GoogleFonts.lora(
                color: couleurTexte,
                fontSize: 15 * reglages.agrandissement.clamp(0.7, 1.6),
                height: 1.6,
              ),
            ),
          ),
          if (reglages.luminosite < 1.0)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: Colors.black.withValues(
                    alpha: (1.0 - reglages.luminosite) * 0.72,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _VignetteFond extends StatelessWidget {
  final String nom;
  final Color fond;
  final Color texte;
  final bool choisi;
  final VoidCallback onTap;

  const _VignetteFond({
    required this.nom,
    required this.fond,
    required this.texte,
    required this.choisi,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    AppColors.suivreLeTheme(context);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 76,
            decoration: BoxDecoration(
              color: fond,
              borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
              border: Border.all(
                color: choisi ? AppColors.accentInk : AppColors.border,
                width: choisi ? 2.5 : 1,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              'Aa',
              style: GoogleFonts.poppins(
                color: texte,
                fontSize: 24,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.spaceSm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (choisi) ...[
                Icon(Icons.check_circle, size: 13, color: AppColors.accentInk),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  nom,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: choisi
                        ? AppColors.accentInk
                        : AppColors.textSecondary,
                    fontWeight: choisi ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
