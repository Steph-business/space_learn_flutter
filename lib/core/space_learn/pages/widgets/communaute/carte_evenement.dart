import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:space_learn_flutter/core/space_learn/data/model/evenementModel.dart';
import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/themes/app_dimensions.dart';
import 'package:space_learn_flutter/core/themes/app_text_styles.dart';
import 'package:space_learn_flutter/core/services/rappel_evenement.dart';
import 'package:space_learn_flutter/core/utils/app_notifications.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/lecteur/communaute/proximite_evenement.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/lecteur/communaute/temps_relatif.dart';

/// Un rappel n'a de sens que pour un rendez-vous encore devant nous.
///
/// C'est ce qui sépare un événement d'une annonce : une annonce se lit ou
/// pas, un rendez-vous se manque. Proposer le geste sur une annonce n'aurait
/// rien à rappeler ; le proposer sur un rendez-vous passé promettrait une
/// notification qui ne partirait jamais.
bool peutRappeler(Evenement evenement) =>
    !evenement.passe && RappelEvenement.encorePossible(evenement.dateEvenement);

/// Le lien de visio nettoyé — null quand il n'y a rien à ouvrir.
///
/// Le champ vient d'un formulaire : un espace collé par mégarde suffisait à
/// faire apparaître le badge sans qu'aucun lien n'existe vraiment.
String? lienVisioDe(Evenement evenement) {
  final lien = evenement.lienVisio?.trim();
  return (lien == null || lien.isEmpty) ? null : lien;
}

/// Une annonce ou un événement, tel qu'il apparaît dans une liste.
///
/// La même carte était écrite deux fois, dans la page communauté du lecteur et
/// dans celle de l'auteur, avec des divergences qui s'installaient à chaque
/// retouche. Une troisième copie s'ajoutait avec la page listant tout : c'est
/// le moment de n'en garder qu'une.
class CarteEvenement extends StatelessWidget {
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

  // La carte n'a plus d'état propre : le rappel vit dans BoutonRappelEvenement
  // et la visio dans BoutonRejoindreVisio, partagés avec la feuille
  // (evenement_apercu). L'état « rappel posé » logé ici se recyclait d'un
  // événement à l'autre — le pourquoi est documenté sur BoutonRappelEvenement.

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

  @override
  Widget build(BuildContext context) {
    AppColors.suivreLeTheme(context);

    final lienVisio = lienVisioDe(evenement);

    // AppColors.success est la couleur de confirmation. L'employer en décor lui
    // retire son sens partout ailleurs : quand un vrai succès s'affiche, il ne
    // se distingue plus de rien. L'icône suffit à séparer les deux formes.
    final accent = AppColors.accentInk;
    final icone = _estAnnonce ? Iconsax.notification : Iconsax.calendar;

    return GestureDetector(
      onTap: onTap,
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
                // plus nulle part. Le lien lui-même s'ouvre par le bouton
                // « Rejoindre la visio », en bas de carte.
                if (!evenement.passe && lienVisio != null) ...[
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
                          //
                          // Les deux travaillent sur l'heure LOCALE du lecteur,
                          // parce que le modèle a déjà converti l'instant reçu
                          // (evenementModel) : rien n'est reconverti ici. Le
                          // `DateTime.utc` qu'on trouve dans
                          // `proximiteEvenement` n'est pas un passage en UTC
                          // mais un compteur de jours civils — il numérote la
                          // journée locale, il ne la déplace pas.
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
                    if (peutRappeler(evenement)) ...[
                      BoutonRappelEvenement(evenement: evenement),
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
            // L'événement passé ne montre pas le bouton : un lien mort n'est
            // pas une action, seul le badge du haut disparaît avec lui.
            if (!evenement.passe && lienVisio != null) ...[
              const SizedBox(height: 10),
              BoutonRejoindreVisio(evenement: evenement),
            ],
          ],
        ),
      ),
    );
  }
}

/// Poser ou retirer le rappel d'un rendez-vous.
///
/// Un seul bouton pour les deux gestes, et son apparence dit lequel : cloche
/// creuse et texte discret quand rien n'est posé, cloche pleine et accent
/// quand le rappel existe. Sans ce contraste, on ne saurait pas si l'on
/// s'apprête à poser ou à retirer.
///
/// Widget autonome, et non méthode de la carte : la feuille
/// (evenement_apercu) — seul écran atteint depuis une notification
/// « Nouvel événement » — doit offrir le même geste sans le réécrire.
class BoutonRappelEvenement extends StatefulWidget {
  const BoutonRappelEvenement({
    super.key,
    required this.evenement,
    this.dansUneFeuille = false,
  });

  final Evenement evenement;

  /// Le bouton est-il rendu à l'intérieur d'une feuille modale ?
  ///
  /// La confirmation passait par AppNotifications.showSnackBar, donc par
  /// ScaffoldMessenger : la bannière se peint tout en bas de l'ÉCRAN, sous la
  /// feuille d'événement, qui en occupe les deux tiers. Le lecteur venu d'une
  /// notification tapait « Me le rappeler », ne voyait qu'un changement
  /// d'icône, et sur refus — « ce rendez-vous est trop proche » — ne voyait
  /// rien du tout. Dans une feuille, le message se rend donc EN LIGNE, sous le
  /// bouton, là où le doigt vient de se poser.
  final bool dansUneFeuille;

  @override
  State<BoutonRappelEvenement> createState() => _BoutonRappelEvenementState();
}

class _BoutonRappelEvenementState extends State<BoutonRappelEvenement> {
  /// Un rappel est-il posé pour ce rendez-vous ?
  ///
  /// L'état vit ici plutôt que chez les appelants : chacun devrait sinon le
  /// charger, le suivre et le passer, et le jour où l'un oublie, le bouton
  /// ment sur un seul écran.
  bool _rappelPose = false;
  bool _enCours = false;

  /// Le retour du dernier geste, quand il ne peut pas passer par une bannière.
  /// Voir [BoutonRappelEvenement.dansUneFeuille].
  String? _message;
  bool _messageEstUnRefus = false;

  Evenement get evenement => widget.evenement;

  @override
  void initState() {
    super.initState();
    _lireLEtatDuRappel();
  }

  /// L'état suit l'ÉVÉNEMENT, pas la position dans la liste.
  ///
  /// `_rappelPose` n'était lu qu'à initState, et les listes qui affichent les
  /// cartes ne posent aucune Key : quand elles changent — filtre « Tout » →
  /// « Événements », rafraîchissement qui réordonne — Flutter réutilise le
  /// State par position, et l'événement B s'affichait avec le « Rappel posé »
  /// de l'événement A. Le lecteur croyait qu'on le préviendrait la veille et
  /// personne ne le prévenait ; ou il « retirait » un rappel affiché qui
  /// n'existait pas.
  @override
  void didUpdateWidget(BoutonRappelEvenement ancien) {
    super.didUpdateWidget(ancien);
    if (ancien.evenement.id != widget.evenement.id) {
      _rappelPose = false;
      // Le message aussi appartient à l'événement d'avant : le garder ferait
      // lire « Nous vous préviendrons la veille » sous un autre rendez-vous.
      _message = null;
      _lireLEtatDuRappel();
    }
  }

  Future<void> _lireLEtatDuRappel() async {
    final id = evenement.id;
    final pose = await RappelEvenement.estPose(id);
    // La réponse d'un ANCIEN événement peut arriver après le recyclage : elle
    // n'a pas le droit d'écraser l'état du nouveau.
    if (!mounted || id != widget.evenement.id) return;
    if (pose != _rappelPose) setState(() => _rappelPose = pose);
  }

  Future<void> _basculerLeRappel() async {
    if (_enCours) return;
    setState(() {
      _enCours = true;
      _message = null;
    });

    // L'événement d'AVANT l'attente.
    //
    // `zonedSchedule` n'est pas instantané, et les listes qui affichent ces
    // boutons ne posent aucune Key : si elles se réordonnent pendant cette
    // attente, Flutter recycle le State sur un AUTRE événement. Le seul test
    // `mounted` laissait alors écrire le résultat de l'ancien sur le nouveau —
    // « Nous vous préviendrons la veille » à côté d'une carte sans rappel.
    // Le State n'a le droit d'écrire que si c'est toujours le même rendez-vous.
    final id = evenement.id;

    try {
      if (_rappelPose) {
        await RappelEvenement.retirer(id);
        if (!mounted) return;
        if (id != widget.evenement.id) return;
        setState(() => _rappelPose = false);
        return;
      }

      final pose = await RappelEvenement.poser(
        evenementId: id,
        titre: evenement.titre,
        dateEvenement: evenement.dateEvenement!,
      );
      if (!mounted) return;
      if (id != widget.evenement.id) return;
      setState(() => _rappelPose = pose);

      final message = pose
          ? "Nous vous préviendrons la veille."
          : "Ce rendez-vous est trop proche pour être rappelé.";

      if (widget.dansUneFeuille) {
        // Sous une feuille modale, une bannière ScaffoldMessenger se peint
        // hors de vue : on répond à l'endroit du geste.
        setState(() {
          _message = message;
          _messageEstUnRefus = !pose;
        });
      } else {
        AppNotifications.showSnackBar(
          context,
          message: message,
          isError: !pose,
        );
      }
    } finally {
      // Sans condition d'identité, celle-ci : `_enCours` décrit une opération
      // de CE State, pas de cet événement. Le laisser à `true` après un
      // recyclage bloquerait le bouton du rendez-vous suivant sur son
      // indicateur de progression, sans plus rien pour le débloquer.
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    AppColors.suivreLeTheme(context);
    // Ce bouton a quitté la carte pour devenir un widget autonome : il lit
    // désormais la palette pour son propre compte, il doit donc s'abonner au
    // thème lui-même. Sans cet appel, il gardait les couleurs du mode clair
    // après une bascule en mode sombre — la carte, elle, s'était repeinte.

    // Un rendez-vous passé, ou trop proche, n'a rien à rappeler : le bouton
    // s'efface plutôt que de promettre une notification qui ne partira pas.
    if (!peutRappeler(evenement)) return const SizedBox.shrink();

    final couleur = _rappelPose ? AppColors.accentInk : AppColors.textSecondary;

    final bouton = InkWell(
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

    final message = _message;
    if (!widget.dansUneFeuille || message == null) return bouton;

    // Le retour du geste, à l'endroit du geste. Un refus doit se voir : sans
    // lui, taper « Me le rappeler » sur un rendez-vous trop proche ne
    // produisait rien du tout — ni rappel, ni explication.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        bouton,
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              _messageEstUnRefus ? Iconsax.info_circle : Iconsax.tick_circle,
              size: 12,
              color: _messageEstUnRefus
                  ? AppColors.error
                  : AppColors.textSecondary,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                message,
                style: GoogleFonts.poppins(
                  color: _messageEstUnRefus
                      ? AppColors.error
                      : AppColors.textSecondary,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// « Rejoindre la visio » : le badge annonce, ce bouton agit.
///
/// Le lien saisi par l'auteur n'était rendu nulle part — la carte n'en
/// montrait que le badge « Visio », un pictogramme et un mot, et personne ne
/// pouvait le suivre, pas même l'auteur. Même langage visuel que le badge
/// (vert succès, icône vidéo), mais pleine largeur et tapable.
///
/// Partagé entre la carte et la feuille (evenement_apercu), qui n'offrait
/// aucun moyen de rejoindre la rencontre.
class BoutonRejoindreVisio extends StatefulWidget {
  const BoutonRejoindreVisio({super.key, required this.evenement});

  final Evenement evenement;

  @override
  State<BoutonRejoindreVisio> createState() => _BoutonRejoindreVisioState();
}

class _BoutonRejoindreVisioState extends State<BoutonRejoindreVisio> {
  /// Ouvrir la visio dans l'application qui la possède.
  ///
  /// Le lien est saisi à la main : un auteur colle souvent
  /// « meet.google.com/xyz » nu, sans schéma, et un tel Uri est un chemin
  /// relatif que rien ne sait ouvrir — d'où le préfixe https:// quand le
  /// schéma manque. Le mode externe confie ensuite l'URL à l'application qui
  /// la possède (Meet, Zoom…), qui rejoint la salle directement, là où un
  /// navigateur embarqué redemanderait de se connecter.
  Future<void> _rejoindreLaVisio() async {
    final lien = lienVisioDe(widget.evenement);
    if (lien == null) return;

    var uri = Uri.tryParse(lien);
    if (uri != null && !uri.hasScheme) {
      uri = Uri.tryParse('https://$lien');
    }

    var ouvert = false;
    if (uri != null && uri.host.isNotEmpty) {
      try {
        ouvert = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        // launchUrl jette quand aucune application ne répond : même issue
        // qu'un lien illisible, même message.
        ouvert = false;
      }
    }

    // Plutôt qu'un tap qui ne fait rien : dire au lecteur que le lien est en
    // cause, pas son geste.
    if (!ouvert && mounted) {
      AppNotifications.showSnackBar(
        context,
        message: "Ce lien de visio est invalide",
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Même raison que le bouton de rappel : extrait de la carte, ce widget
    // lit la palette seul et doit donc suivre le thème seul.
    AppColors.suivreLeTheme(context);

    // Un lien mort n'est pas une action : l'événement passé, ou sans lien,
    // n'affiche rien.
    if (widget.evenement.passe || lienVisioDe(widget.evenement) == null) {
      return const SizedBox.shrink();
    }

    return InkWell(
      onTap: _rejoindreLaVisio,
      borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Iconsax.video, size: 14, color: AppColors.success),
            const SizedBox(width: 6),
            Text(
              "Rejoindre la visio",
              style: GoogleFonts.poppins(
                color: AppColors.success,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
