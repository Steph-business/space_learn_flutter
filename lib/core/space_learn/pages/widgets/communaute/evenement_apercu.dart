import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

import 'package:space_learn_flutter/core/space_learn/data/model/evenementModel.dart';
import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/themes/app_dimensions.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/communaute/carte_evenement.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/lecteur/communaute/proximite_evenement.dart';

/// Ouvre une annonce ou un événement en feuille, sans quitter la page.
///
/// Côté lecteur, il n'y a rien à faire d'une publication qu'on ne peut ni
/// modifier ni supprimer : la lire, puis revenir. Une page entière pour cela
/// impose une navigation, un écran qui s'ouvre, un retour — trois gestes là où
/// un seul suffit. La feuille garde la liste visible derrière elle.
///
/// L'auteur, lui, continue d'ouvrir la page : c'est là que se trouvent les
/// boutons de modification et de suppression.
Future<void> afficherEvenement(BuildContext context, Evenement evenement) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => _FeuilleEvenement(evenement: evenement),
  );
}

class _FeuilleEvenement extends StatelessWidget {
  const _FeuilleEvenement({required this.evenement});

  final Evenement evenement;

  bool get _estAnnonce =>
      evenement.typePublication.toLowerCase().trim() == 'annonce';

  String get _etiquette {
    final categorie = evenement.categorie?.trim();
    if (categorie != null && categorie.isNotEmpty) {
      return categorie.toUpperCase();
    }
    return evenement.typePublication.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    AppColors.suivreLeTheme(context);
    final accent = AppColors.accentInk;
    final icone = _estAnnonce ? Iconsax.notification : Iconsax.calendar;

    return DraggableScrollableSheet(
      // Assez haut pour qu'on lise sans faire glisser, assez bas pour qu'on
      // voie qu'il s'agit d'une feuille et non d'un écran.
      initialChildSize: 0.62,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, controleur) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppDimensions.radiusPill),
            ),
          ),
          child: Column(
            children: [
              // La poignée : elle dit qu'on peut tirer, et qu'on peut refermer.
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textHint.withValues(alpha: 0.4),
                    // Une pastille : le rayon depasse la demi-hauteur, donc
                    // les extremites sont rondes quoi qu'il arrive.
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusPill,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: controleur,
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
                  children: [
                    if (evenement.imageUrl != null &&
                        evenement.imageUrl!.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusCard,
                        ),
                        child: Image.network(
                          evenement.imageUrl!,
                          height: 170,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          // Sans repli, une image retirée du stockage laisse un
                          // vide et une exception.
                          errorBuilder: (context, error, stack) =>
                              const SizedBox.shrink(),
                        ),
                      ),
                    if (evenement.imageUrl != null &&
                        evenement.imageUrl!.isNotEmpty)
                      const SizedBox(height: 20),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(
                              AppDimensions.radiusSmall,
                            ),
                          ),
                          child: Icon(icone, color: accent, size: 16),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _etiquette,
                            style: GoogleFonts.poppins(
                              color: accent,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      evenement.titre,
                      style: GoogleFonts.poppins(
                        color: AppColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                      ),
                    ),
                    if (evenement.dateEvenement != null) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(
                            Iconsax.calendar_1,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          // Même règle que sur la carte : la distance d'abord,
                          // la date complète ensuite. C'est ici qu'on décide
                          // d'y aller ou non, donc c'est ici que « Demain »
                          // compte le plus.
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: proximiteEvenement(
                                      evenement.dateEvenement!,
                                    ),
                                    style: GoogleFonts.poppins(
                                      color: AppColors.textPrimary,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  TextSpan(
                                    text:
                                        " · ${DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(evenement.dateEvenement!)}",
                                    style: GoogleFonts.poppins(
                                      color: AppColors.textSecondary,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    // Les mêmes gestes que sur la carte, par les mêmes
                    // widgets (carte_evenement) — une seule implémentation.
                    //
                    // Cette feuille est le SEUL écran atteint depuis la
                    // notification « Nouvel événement de l'auteur »
                    // (notificationService → afficherEvenement) : sans ces
                    // boutons, un lecteur prévenu d'un live en visio arrivait
                    // sur un écran d'où il ne pouvait ni rejoindre la
                    // rencontre ni se faire rappeler — l'action principale de
                    // l'événement était inaccessible depuis le chemin le plus
                    // fréquent, alors que lien_visio voyage dans le modèle.
                    if (!evenement.passe && lienVisioDe(evenement) != null) ...[
                      const SizedBox(height: 16),
                      BoutonRejoindreVisio(evenement: evenement),
                    ],
                    if (peutRappeler(evenement)) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        // `dansUneFeuille` : la confirmation se peignait par
                        // ScaffoldMessenger, tout en bas de l'écran — donc
                        // SOUS cette feuille, qui en occupe les deux tiers.
                        // Le geste restait sans retour visible, et un refus
                        // (« rendez-vous trop proche ») passait inaperçu.
                        child: BoutonRappelEvenement(
                          evenement: evenement,
                          dansUneFeuille: true,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    // Le texte entier. C'est tout l'objet de cette feuille :
                    // dans la liste il s'arrête à trois lignes, souvent au
                    // milieu d'une phrase.
                    Text(
                      evenement.contenu,
                      style: GoogleFonts.poppins(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
