import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

import 'package:space_learn_flutter/core/space_learn/data/model/evenementModel.dart';
import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/themes/app_dimensions.dart';
import 'package:space_learn_flutter/core/themes/app_text_styles.dart';
import 'package:space_learn_flutter/core/services/rappel_evenement.dart';
import 'package:space_learn_flutter/core/utils/app_notifications.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/lecteur/communaute/proximite_evenement.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/lecteur/communaute/temps_relatif.dart';

/// Une annonce ou un événement, tel qu'il apparaît dans une liste.
///
/// La même carte était écrite deux fois, dans la page communauté du lecteur et
/// dans celle de l'auteur, avec des divergences qui s'installaient à chaque
/// retouche. Une troisième copie s'ajoutait avec la page listant tout : c'est
/// le moment de n'en garder qu'une.
class CarteEvenement extends StatefulWidget {
  const CarteEvenement({
    super.key,
    required this.evenement,
    required this.onTap,
    this.signature,
  });

  final Evenement evenement;
  final VoidCallback onTap;

  /// Ligne du bas. Le nom de l'auteur quand on le connaît.
  ///
  /// Elle affichait « Événement Communauté » sur chaque carte, quelle que soit
  /// la publication et quel qu'en soit l'auteur — une signature qui ne signe
  /// rien. Sans valeur, la ligne disparaît plutôt que de meubler.
  final String? signature;

  @override
  State<CarteEvenement> createState() => _CarteEvenementState();
}

class _CarteEvenementState extends State<CarteEvenement> {
  /// Un rappel est-il posé pour ce rendez-vous ?
  ///
  /// L'état vit dans la carte plutôt que chez ses trois appelants : chacun
  /// devrait sinon le charger, le suivre et le passer, et le jour où l'un
  /// oublie, le bouton ment sur un seul écran.
  bool _rappelPose = false;
  bool _enCours = false;

  Evenement get evenement => widget.evenement;
  String? get signature => widget.signature;

  @override
  void initState() {
    super.initState();
    if (_peutRappeler) _lireLEtatDuRappel();
  }

  /// Un rappel n'a de sens que pour un rendez-vous encore devant nous.
  ///
  /// C'est ce qui sépare un événement d'une annonce : une annonce se lit ou
  /// pas, un rendez-vous se manque. Proposer le geste sur une annonce n'aurait
  /// rien à rappeler ; le proposer sur un rendez-vous passé promettrait une
  /// notification qui ne partirait jamais.
  bool get _peutRappeler =>
      !evenement.passe &&
      RappelEvenement.encorePossible(evenement.dateEvenement);

  Future<void> _lireLEtatDuRappel() async {
    final pose = await RappelEvenement.estPose(evenement.id);
    if (mounted && pose != _rappelPose) setState(() => _rappelPose = pose);
  }

  Future<void> _basculerLeRappel() async {
    if (_enCours) return;
    setState(() => _enCours = true);

    try {
      if (_rappelPose) {
        await RappelEvenement.retirer(evenement.id);
        if (mounted) setState(() => _rappelPose = false);
        return;
      }

      final pose = await RappelEvenement.poser(
        evenementId: evenement.id,
        titre: evenement.titre,
        dateEvenement: evenement.dateEvenement!,
      );
      if (!mounted) return;
      setState(() => _rappelPose = pose);

      AppNotifications.showSnackBar(
        context,
        message: pose
            ? "Nous vous préviendrons la veille."
            : "Ce rendez-vous est trop proche pour être rappelé.",
        isError: !pose,
      );
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  bool get _estAnnonce =>
      evenement.typePublication.toLowerCase().trim() == 'annonce';

  /// L'étiquette du haut : la catégorie si le serveur en donne une, le type
  /// sinon. « ÉVÉNEMENT » seul ne dit rien de ce qu'on va lire.
  String get _etiquette {
    final categorie = evenement.categorie?.trim();
    if (categorie != null && categorie.isNotEmpty) {
      return categorie.toUpperCase();
    }
    return evenement.typePublication.toUpperCase();
  }

  /// Poser ou retirer le rappel.
  ///
  /// Un seul bouton pour les deux gestes, et son apparence dit lequel : cloche
  /// creuse et texte discret quand rien n'est posé, cloche pleine et accent
  /// quand le rappel existe. Sans ce contraste, on ne saurait pas si l'on
  /// s'apprête à poser ou à retirer.
  Widget _boutonRappel(Color accent) {
    final couleur = _rappelPose ? accent : AppColors.textSecondary;

    return InkWell(
      onTap: _enCours ? null : _basculerLeRappel,
      borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_enCours)
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.6,
                  color: couleur,
                ),
              )
            else
              Icon(
                _rappelPose ? Iconsax.notification5 : Iconsax.notification,
                size: 13,
                color: couleur,
              ),
            const SizedBox(width: 4),
            Text(
              _rappelPose ? "Rappel posé" : "Me le rappeler",
              style: GoogleFonts.poppins(
                color: couleur,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    AppColors.suivreLeTheme(context);

    // AppColors.success est la couleur de confirmation. L'employer en décor lui
    // retire son sens partout ailleurs : quand un vrai succès s'affiche, il ne
    // se distingue plus de rien. L'icône suffit à séparer les deux formes.
    final accent = AppColors.accentInk;
    final icone = _estAnnonce ? Iconsax.notification : Iconsax.calendar;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          border: Border.all(color: accent.withValues(alpha: 0.3)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // « Terminé » : l'événement a eu lieu.
                //
                // Sans cette mention, une rencontre passée et une rencontre à
                // venir se ressemblent trait pour trait — seule la date les
                // distingue, et il faut la lire puis la comparer à celle du
                // jour. Le serveur les range maintenant en bas de liste ; ceci
                // dit pourquoi.
                if (evenement.passe) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.textHint.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusXs,
                      ),
                    ),
                    child: Text(
                      "Terminé",
                      style: GoogleFonts.poppins(
                        color: AppColors.textSecondary,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                // Badge visio : indique d'un coup d'œil que la rencontre est en
                // ligne. Inutile une fois la rencontre passée : le lien ne mène
                // plus nulle part.
                if (!evenement.passe &&
                    evenement.lienVisio != null &&
                    evenement.lienVisio!.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusXs,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Iconsax.video, size: 10, color: AppColors.success),
                        const SizedBox(width: 3),
                        Text(
                          "Visio",
                          style: GoogleFonts.poppins(
                            color: AppColors.success,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                // La date du RENDEZ-VOUS, et elle seule.
                //
                // Deux dates s'affichaient sans etiquette : celle-ci en haut,
                // et « Publie le … » en bas. Pour une annonce — qui n'a pas de
                // date d'evenement — la premiere retombait sur la date de
                // publication : la meme date, ecrite deux fois sur la meme
                // carte, l'une nue et l'autre nommee. Impossible de savoir ce
                // que la premiere voulait dire, ni pourquoi elle differait
                // parfois de la seconde.
                //
                // Une annonce n'a donc plus qu'une date, celle du bas. Un
                // evenement en garde deux, mais celle-ci porte desormais son
                // nom et se detache : c'est la seule qui engage le lecteur a
                // se deplacer.
                // Souple, et non rigide.
                //
                // Le badge s'est allongé — « Dans 2 semaines · 9 sept. 2026 »
                // là où il n'y avait qu'une date. Sur un écran étroit et avec
                // une catégorie au nom long, un Container rigide déborderait de
                // sa rangée. Flexible le laisse rendre la main : c'est la fin
                // de la date qui s'abrège, pas la mise en page qui casse.
                if (evenement.dateEvenement != null)
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: evenement.passe
                            ? AppColors.textHint.withValues(alpha: 0.12)
                            : accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusXs,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Iconsax.calendar_1,
                            size: 10,
                            color: evenement.passe
                                ? AppColors.textSecondary
                                : accent,
                          ),
                          const SizedBox(width: 4),
                          // La distance d'abord, la date ensuite.
                          //
                          // « 17 août 2026 » dit la même chose le jour de la
                          // publication et trois semaines plus tard : c'est au
                          // lecteur de calculer si ça le concerne, et personne
                          // ne calcule. « Demain » se lit sans effort et change
                          // tout seul à mesure que la date approche.
                          //
                          // La date exacte reste : elle seule permet de noter le
                          // rendez-vous quelque part.
                          Flexible(
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: proximiteEvenement(
                                      evenement.dateEvenement!,
                                    ),
                                    style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  TextSpan(
                                    text:
                                        " · ${DateFormat('d MMM yyyy', 'fr_FR').format(evenement.dateEvenement!)}",
                                    style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              style: TextStyle(
                                color: evenement.passe
                                    ? AppColors.textSecondary
                                    : accent,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              evenement.titre,
              style: GoogleFonts.poppins(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              evenement.contenu,
              style: AppTextStyles.grey12,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Builder(
              builder: (context) {
                final nomAuteurEffectif =
                    (signature != null && signature!.trim().isNotEmpty)
                    ? signature!.trim()
                    : (evenement.nomAuteur?.trim().isNotEmpty == true
                          ? evenement.nomAuteur!.trim()
                          : null);

                // Une annonce se date par son âge, un rendez-vous par sa date.
                //
                // « Publié le 25 juil. 2026 » sur une annonce qui dit « très
                // bientôt » se lit comme du frais alors qu'elle a un mois : la
                // date exacte n'a rien de faux, elle ne dit simplement pas
                // qu'elle est vieille. Un rendez-vous, lui, garde la date de
                // publication telle quelle — sa distance à nous est déjà dans
                // le badge du haut, et deux formulations relatives sur la même
                // carte se marcheraient dessus.
                final datePubStr = evenement.creeLe == null
                    ? null
                    : evenement.dateEvenement == null
                    ? "Publié ${tempsRelatif(evenement.creeLe!)}"
                    : "Publié le ${DateFormat('d MMM yyyy', 'fr_FR').format(evenement.creeLe!)}";

                final hasAuthor = nomAuteurEffectif != null;
                final hasPubDate = datePubStr != null;

                return Row(
                  children: [
                    if (hasAuthor || hasPubDate)
                      Expanded(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (hasAuthor) ...[
                              Icon(
                                Icons.person,
                                size: 12,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  nomAuteurEffectif,
                                  style: GoogleFonts.poppins(
                                    color: AppColors.textSecondary,
                                    fontSize: 11,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                            if (hasAuthor && hasPubDate)
                              Text(
                                " • ",
                                style: GoogleFonts.poppins(
                                  color: AppColors.textHint,
                                  fontSize: 11,
                                ),
                              ),
                            if (hasPubDate)
                              Flexible(
                                child: Text(
                                  datePubStr,
                                  style: GoogleFonts.poppins(
                                    color: AppColors.textHint,
                                    fontSize: 11,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                        ),
                      )
                    else
                      const Spacer(),
                    const SizedBox(width: 8),
                    // « Me le rappeler » passe AVANT « Lire » : c'est l'action
                    // propre au rendez-vous, celle qu'on ne peut pas remettre
                    // à plus tard sans risquer de l'oublier.
                    if (_peutRappeler) ...[
                      _boutonRappel(accent),
                      const SizedBox(width: 10),
                    ],
                    Text(
                      "Lire",
                      style: GoogleFonts.poppins(
                        color: accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Icon(Iconsax.arrow_right_3, size: 13, color: accent),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
