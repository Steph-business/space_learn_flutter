import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../services/lecture_audio_livre.dart';
import '../../../../themes/app_colors.dart';

/// Ce qui se joue, et comment l'arrêter.
///
/// Ce bandeau n'existait que dans la bibliothèque, où il était une méthode
/// privée de l'écran. Or il n'est pas décoratif : c'est le seul moyen, hors
/// notification système, d'arrêter une voix qu'on vient de lancer. Dès qu'un
/// second écran peut démarrer l'écoute — l'accueil, avec sa carte « Continuer
/// la lecture » — le bandeau doit le suivre, sinon le lecteur qui quitte cet
/// écran se retrouve avec une voix et rien pour la faire taire.
///
/// Il est donc sorti là où les deux écrans peuvent le prendre, plutôt que
/// recopié — deux copies d'un même bandeau finissent toujours par diverger.
///
/// Il lit directement le service : celui-ci est unique, et l'écran qui
/// l'affiche s'abonne déjà à ses notifications pour se reconstruire.
class BandeauEcoute extends StatelessWidget {
  const BandeauEcoute({super.key});

  @override
  Widget build(BuildContext context) {
    AppColors.suivreLeTheme(context);
    // Le bandeau flotte au-dessus des écrans, il n'hérite donc pas de leur
    // abonnement : sans cet appel il gardait les couleurs du thème précédent
    // après une bascule clair/sombre, seul élément resté en arrière.

    final audio = LectureAudioLivre.instance;

    return Material(
      color: AppColors.cardBackground,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
          child: Row(
            children: [
              Icon(
                Icons.headphones_rounded,
                color: AppColors.accentInk,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      audio.titre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      audio.preparation
                          ? 'Préparation…'
                          : audio.total > 0
                          ? 'Page ${audio.page} sur ${audio.total}'
                          : 'Écoute en cours',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppColors.textHint,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: audio.preparation
                    ? null
                    : () => audio.enLecture ? audio.pause() : audio.reprendre(),
                icon: Icon(
                  audio.enLecture
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  color: AppColors.accentInk,
                ),
              ),
              IconButton(
                onPressed: audio.arreter,
                icon: Icon(Icons.close_rounded, color: AppColors.textHint),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
