import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/services/tts_service.dart';
import 'package:space_learn_flutter/core/utils/app_notifications.dart';
import 'package:space_learn_flutter/core/themes/app_dimensions.dart';
import 'package:space_learn_flutter/core/services/onboarding_guide_service.dart';
import 'package:space_learn_flutter/core/themes/layout/nav_bar_lecteur.dart';
import 'help_faq_page.dart';

/// Le mode d'emploi de l'application.
///
/// Chacun n'y voit QUE son parcours : un lecteur le sien, un auteur le sien.
///
/// L'auteur voyait les deux, sous prétexte qu'il lit aussi. Mais il ouvre ce
/// guide depuis ses réglages d'auteur, avec une question d'auteur — publier,
/// fixer un prix, se faire payer — et tombait sur « Découvrir et trouver des
/// livres ». Un mode d'emploi qui commence par répondre à côté n'est pas
/// consulté deux fois.
///
/// Avant cela, un ancien `initialIsAuthor` ne décidait que de l'onglet OUVERT :
/// les deux restaient là, et un lecteur n'avait qu'à toucher le second pour
/// lire comment déposer un manuscrit et suivre des ventes qu'il n'aura jamais.
class UserGuidePage extends StatefulWidget {
  final bool estAuteur;

  const UserGuidePage({super.key, this.estAuteur = false});

  @override
  State<UserGuidePage> createState() => _UserGuidePageState();
}

class _UserGuidePageState extends State<UserGuidePage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  /// Titre de la section en cours de lecture, ou null.
  String? _sectionLue;
  final TtsService _tts = TtsService();

  /// Lecture complète du guide : index de la section en cours, ou -1.
  int _lectureTouteIndex = -1;
  List<_GuideSection> _lectureTouteSections = [];

  @override
  void initState() {
    super.initState();
    _tts.addListener(_surEtatVoix);
  }

  void _surEtatVoix() {
    if (!mounted) return;
    // La voix s'est tue d'elle-même : plus aucune section n'est en cours.
    if (_tts.isStopped) {
      _sectionLue = null;
      // En mode « tout le guide », passer à la section suivante.
      if (_lectureTouteIndex >= 0) {
        _lectureTouteIndex++;
        if (_lectureTouteIndex < _lectureTouteSections.length) {
          setState(() {});
          _lireSectionDuGuide(_lectureTouteIndex);
        } else {
          _arreterLectureTotale();
        }
      } else {
        setState(() {});
      }
    }
  }

  @override
  void dispose() {
    // Le service est un singleton : sans ce retrait, l'écouteur survit à
    // l'écran et appelle setState sur un widget détruit. Et la voix doit se
    // taire quand on quitte le guide — sinon elle continue de réciter le mode
    // d'emploi par-dessus l'écran suivant.
    _tts.removeListener(_surEtatVoix);
    _tts.stop();
    _arreterLectureTotale();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AppColors.suivreLeTheme(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = widget.estAuteur
        ? AppColors.secondaryVariant
        : AppColors.accentInk;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.scaffoldBackground
          : AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.scaffoldBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.textPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.estAuteur ? "Guide de l'auteur" : "Guide du lecteur",
          style: GoogleFonts.poppins(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Barre de recherche dans le guide
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusInner,
                    ),
                    border: Border.all(
                      color: AppColors.textHint.withValues(alpha: 0.3),
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) =>
                        setState(() => _searchQuery = v.trim().toLowerCase()),
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: "Rechercher une aide, une fonctionnalité...",
                      hintStyle: GoogleFonts.poppins(
                        fontSize: 13,
                        color: AppColors.textHint,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: accentColor,
                        size: 22,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),

              // Un seul parcours, celui de la personne qui consulte.
              Expanded(
                child: widget.estAuteur
                    ? _buildAuthorGuide(isDark)
                    : _buildReaderGuide(isDark),
              ),
            ],
          ),

          // Mini-player en bas pendant la lecture complète du guide
          if (_lectureTouteIndex >= 0) _buildMiniPlayer(accentColor),
        ],
      ),
    );
  }

  // ───────────────────────── Parcours Lecteur ─────────────────────────
  Widget _buildReaderGuide(bool isDark) {
    final List<_GuideSection> sections = [
      _GuideSection(
        icon: Icons.explore_rounded,
        color: AppColors.accentInk,
        title: "1. Découvrir et trouver des livres",
        shortDesc: "Explorer la boutique, les filtres et les recommandations.",
        steps: [
          "Utilisez la barre de recherche sur la page d'accueil pour chercher par titre ou par nom d'auteur.",
          "Filtrez par thématique (Astronomie, Sciences, Fiction...) via les capsules de catégories.",
          "Consultez les 'Nouveautés' et 'Recommandations pour vous' générées selon vos lectures.",
          "Tapez sur un livre pour ouvrir sa fiche détaillée, lire le résumé, consulter les avis et le prix.",
        ],
        tip:
            "Le cœur met un livre de côté dans vos favoris — c'est un pense-bête, pas un achat : le livre n'entre dans votre bibliothèque qu'une fois acquis.",
      ),
      _GuideSection(
        icon: Icons.auto_stories_rounded,
        color: AppColors.accentInk,
        title: "2. Expérience de lecture (Liseuse)",
        shortDesc: "Personnaliser l'affichage, les thèmes et naviguer.",
        steps: [
          "Ouvrez un livre depuis votre bibliothèque pour lancer la liseuse plein écran.",
          "Glissez horizontalement pour tourner les pages ou utilisez le défilement vertical selon le format.",
          "Touchez le centre de l'écran pour afficher la barre d'outils : ajustez la taille de police, la luminosité et choisissez le thème de fond (Clair, Sombre ou Sépia).",
          "Accédez à la Table des matières pour sauter directement à un chapitre précis.",
        ],
        tip:
            "Votre progression est sauvegardée automatiquement à chaque page lue !",
      ),
      _GuideSection(
        icon: Icons.headphones_rounded,
        color: AppColors.accentInk,
        title: "3. Lecture Audio & Synthèse Vocale (TTS)",
        shortDesc: "Écouter les livres à voix haute même écran éteint.",
        steps: [
          "Dans la liseuse, touchez l'icône de casque pour lancer la synthèse vocale.",
          "Réglez la vitesse d'élocution (1.0x, 1.25x, 1.5x) selon votre rythme de confort.",
          "Contrôlez la lecture depuis l'écran de verrouillage ou via les boutons de vos écouteurs Bluetooth.",
          "La lecture audio continue même si vous mettez l'application en arrière-plan.",
        ],
        tip:
            "Parfait pour continuer à apprendre pendant vos trajets quotidiens ou vos séances de sport.",
      ),
      _GuideSection(
        icon: Icons.download_done_rounded,
        color: AppColors.accentInk,
        title: "4. Lire sans connexion",
        shortDesc:
            "Vos livres restent sur l'appareil après la première ouverture.",
        steps: [
          "Il n'y a rien à télécharger à la main : la première ouverture d'un livre le dépose sur votre appareil.",
          "Les fois suivantes, il s'ouvre directement — même sans réseau.",
          "Retrouvez ce qui occupe de la place dans « Paramètres › Téléchargements », et libérez-en si besoin.",
          "L'aperçu gratuit et le livre acheté sont conservés séparément : lire l'un ne remplace pas l'autre.",
        ],
      ),
      _GuideSection(
        icon: Icons.military_tech_rounded,
        color: AppColors.accentInk,
        title: "5. Objectifs quotidiens & Badges",
        shortDesc: "Mesurer votre temps de lecture et débloquer des trophées.",
        steps: [
          "Chaque minute passée à lire est comptabilisée en direct sur votre page d'accueil.",
          "Atteignez votre objectif quotidien (ex: 20 min/jour) pour maintenir votre série (streak).",
          "Débloquez des badges galactiques (Premier Pas, Grand Lecteur, Marathonien des étoiles).",
          "Consultez vos statistiques globales dans l'onglet Profil.",
        ],
      ),
      _GuideSection(
        icon: Icons.forum_rounded,
        color: AppColors.accentInk,
        title: "6. Communauté & Échanges",
        shortDesc: "Discuter avec les auteurs et d'autres passionnés.",
        steps: [
          "Accédez à l'onglet 'Teams / Communauté' dans la barre de navigation du bas.",
          "Participez aux salons de discussion par thème ou par ouvrage.",
          "Laissez des avis et notes étoilées sur les livres que vous avez terminés.",
          "Suivez vos auteurs favoris pour recevoir une notification dès qu'ils publient un nouvel ouvrage.",
        ],
      ),
      _GuideSection(
        icon: Icons.account_balance_wallet_rounded,
        color: AppColors.accentInk,
        title: "7. Paiements & Sécurité",
        shortDesc: "Acheter des livres en toute confiance.",
        steps: [
          "Avant d'acheter, ouvrez l'aperçu gratuit : il reprend les premières pages du livre.",
          "Les paiements passent par CinetPay : Mobile Money (Orange, MTN, Moov, Wave) et cartes bancaires.",
          "Après confirmation, le livre entre dans votre bibliothèque et y reste : un ouvrage acheté ne se perd pas.",
          "Si un paiement n'aboutit pas, vous en êtes prévenu et pouvez réessayer — rien ne reste bloqué.",
        ],
      ),
    ];

    return _buildGuideList(
      sections: sections,
      isDark: isDark,
      bannerTitle: "Visite Guidée Interactive de l'Accueil",
      bannerSubtitle:
          "Relancer le projecteur guidé pas-à-pas sur l'écran d'accueil.",
      bannerIcon: Icons.rocket_launch_rounded,
      bannerColor: AppColors.accentInk,
      onBannerTap: () async {
        await OnboardingGuideService.resetHomeTour();
        if (mounted) {
          AppNotifications.showSnackBar(
            context,
            message: "Guide interactif activé ! Redirection vers l'accueil...",
            isSuccess: true,
          );
          Navigator.of(context).pop();
          MainNavBar.mainNavBarKey.currentState?.goHome();
        }
      },
    );
  }

  // ───────────────────────── Parcours Auteur ─────────────────────────
  //
  // Ce guide ne dit que des choses vérifiées dans le code. La version
  // précédente promettait un prix « librement » choisi alors qu'un plancher
  // existe, des « coordonnées bancaires » que rien n'accepte, et un
  // basculement entre les modes Lecteur et Auteur qui n'est branché nulle
  // part. Un mode d'emploi qui décrit une application imaginaire fait perdre
  // plus de temps qu'il n'en fait gagner.
  Widget _buildAuthorGuide(bool isDark) {
    final List<_GuideSection> sections = [
      _GuideSection(
        icon: Icons.upload_file_rounded,
        color: AppColors.secondaryVariant,
        title: "1. Publier un livre",
        shortDesc: "Du manuscrit à la mise en vente, étape par étape.",
        steps: [
          "Depuis votre accueil, touchez « Publier un nouveau livre ».",
          "Renseignez le titre, la catégorie, la description, puis l'argumentaire de recommandation à la seconde étape.",
          "Choisissez votre image de couverture, puis votre manuscrit au format PDF ou ePUB.",
          "Tant que les fichiers ne sont pas déposés, le livre reste en brouillon : il n'apparaît pas à la vente.",
          "L'aperçu gratuit est fabriqué automatiquement à partir de votre manuscrit — vous n'avez rien à préparer.",
        ],
        tip:
            "Un manuscrit de moins de dix pages est refusé à la publication, et un même fichier ne peut pas être vendu sous deux titres.",
      ),
      _GuideSection(
        icon: Icons.price_change_rounded,
        color: AppColors.secondaryVariant,
        title: "2. Fixer votre prix",
        shortDesc: "Ce que vous demandez, et ce que vous touchez.",
        steps: [
          "Le prix minimum d'un livre payant est de 2 000 FCFA. En dessous, la commission et les frais d'opérateur ne laisseraient presque rien pour vous.",
          "Vous pouvez aussi publier gratuitement : cochez la case prévue, et le livre s'ajoute directement à la bibliothèque de vos lecteurs.",
          "La plateforme retient 20 % sur chaque vente. Sur un livre à 2 000 FCFA, vous percevez donc 1 600 FCFA.",
          "Le formulaire affiche votre gain en francs pendant que vous saisissez le prix : plus besoin de calculer.",
        ],
        // Le guide présentait les 5 000 F comme un plafond — « la fourchette
        // conseillée va de 2 000 à 5 000 » — et y ajoutait une affirmation de
        // marché que rien n'étaye : « un prix très élevé se vend rarement ».
        //
        // Il n'existe qu'une limite, et c'est le plancher. Le serveur le dit
        // lui-même à côté des deux champs (modules/parametres/controller.go) :
        // la fourchette est « un repérage, pas une limite », alors que « le
        // plancher, lui, est une limite : en dessous, la vente est refusée ».
        // Au-dessus de 2 000 F, l'auteur fixe son prix comme il l'entend.
        tip:
            "Au-dessus de 2 000 FCFA, vous fixez votre prix librement : il n'y a pas de plafond. La fourchette que le formulaire affiche n'est qu'un repère pour situer votre saisie.",
      ),
      _GuideSection(
        icon: Icons.insights_rounded,
        color: AppColors.secondaryVariant,
        title: "3. Suivre vos ventes",
        shortDesc: "Lire vos chiffres sans se tromper de grandeur.",
        steps: [
          "Votre accueil affiche « Mes gains » : ce que vous touchez, commission déjà déduite. Ce n'est pas le montant payé par l'acheteur.",
          "La courbe suit la période choisie — semaine, mois, ou les douze derniers mois — et bascule entre vos gains et vos lectures.",
          "Seules les ventes réellement réglées sont comptées : une commande abandonnée en cours de paiement n'apparaît nulle part.",
          "« Mes gains » dans les réglages détaille chaque vente, à sa date réelle, et l'état de vos retraits.",
        ],
      ),
      _GuideSection(
        icon: Icons.account_balance_wallet_rounded,
        color: AppColors.secondaryVariant,
        title: "4. Recevoir votre argent",
        shortDesc: "Coordonnées Mobile Money et demande de virement.",
        steps: [
          "Renseignez d'abord votre numéro Mobile Money dans « Compte de versement ». Le virement se fait vers ce numéro, et seulement vers lui.",
          "Vous pouvez demander un virement à partir de 1 000 FCFA — soit dès votre première vente au prix plancher.",
          "Le virement est sans frais : vous recevez exactement ce que votre solde annonce.",
          "Une demande reste annulable tant qu'elle n'est pas partie chez l'opérateur.",
        ],
        tip:
            "Votre solde est crédité dès qu'un paiement est confirmé, sans démarche de votre part.",
      ),
      _GuideSection(
        icon: Icons.campaign_rounded,
        color: AppColors.secondaryVariant,
        title: "5. Faire vivre votre communauté",
        shortDesc: "Annonces, événements et échanges avec vos lecteurs.",
        steps: [
          "Publiez une annonce ou créez un événement depuis « Gérer mes annonces & évènements » sur votre accueil.",
          "Un événement daté peut être rappelé à vos lecteurs la veille au soir.",
          "Répondez dans les salons de discussion attachés à vos livres — vous pouvez y modifier ou retirer vos messages.",
          "Consultez vos abonnés depuis l'espace auteur ; ils sont prévenus à chacune de vos publications.",
        ],
        tip:
            "Une annonce quitte le fil des lecteurs au bout de trois mois, un événement passé au bout d'un mois. Rien n'est supprimé : vous les retrouvez dans votre espace.",
      ),
    ];

    return _buildGuideList(
      sections: sections,
      isDark: isDark,
      bannerTitle: "Besoin d'aide pour publier ?",
      bannerSubtitle:
          "Consultez la foire aux questions ou contactez l'équipe éditoriale.",
      bannerIcon: Icons.support_agent_rounded,
      bannerColor: AppColors.secondaryVariant,
      onBannerTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => HelpFaqPage(estAuteur: widget.estAuteur),
          ),
        );
      },
    );
  }

  // ───────────────────────── Liste des fiches du guide ─────────────────────────
  Widget _buildGuideList({
    required List<_GuideSection> sections,
    required bool isDark,
    required String bannerTitle,
    required String bannerSubtitle,
    required IconData bannerIcon,
    required Color bannerColor,
    required VoidCallback onBannerTap,
  }) {
    final filtered = sections.where((sec) {
      if (_searchQuery.isEmpty) return true;
      final matchTitle = sec.title.toLowerCase().contains(_searchQuery);
      final matchDesc = sec.shortDesc.toLowerCase().contains(_searchQuery);
      final matchSteps = sec.steps.any(
        (s) => s.toLowerCase().contains(_searchQuery),
      );
      return matchTitle || matchDesc || matchSteps;
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off_rounded,
                size: 64,
                color: AppColors.textHint,
              ),
              const SizedBox(height: 16),
              Text(
                "Aucun résultat trouvé pour '$_searchQuery'",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        _lectureTouteIndex >= 0 ? 100 : 24,
      ),
      children: [
        // Bouton « Écouter tout le guide »
        _buildBoutonEcouterTout(sections, bannerColor),
        const SizedBox(height: 12),

        // Carte d'action rapide / Démonstration en tête de liste
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                bannerColor.withOpacity(0.2),
                bannerColor.withOpacity(0.06),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
            border: Border.all(
              color: bannerColor.withOpacity(0.35),
              width: 1.2,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onBannerTap,
              borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: bannerColor,
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusInner,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: bannerColor.withOpacity(0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        bannerIcon,
                        color: AppColors.onAccent,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            bannerTitle,
                            style: GoogleFonts.poppins(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: AppColors.onAccent,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            bannerSubtitle,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: bannerColor,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Cartes de sections détaillées
        ...filtered.map((sec) => _buildSectionCard(sec, isDark)),
      ],
    );
  }

  /// Écouter une section plutôt que la lire.
  ///
  /// Un mode d'emploi sert surtout à qui n'est pas à l'aise avec l'écrit, ou
  /// qui découvre l'application sur un petit écran d'entrée de gamme. Le moteur
  /// de synthèse est déjà en place pour les livres : il ne demandait qu'à être
  /// branché ici.
  Widget _boutonEcoute(_GuideSection section) {
    final enCours = _sectionLue == section.title && _tts.isPlaying;

    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () => _basculerEcoute(section),
        icon: Icon(
          enCours ? Icons.stop_circle_outlined : Icons.volume_up_rounded,
          size: 18,
          color: AppColors.accentInk,
        ),
        label: Text(
          enCours ? "Arrêter" : "Écouter cette section",
          style: GoogleFonts.poppins(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: AppColors.accentInk,
          ),
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          minimumSize: const Size(0, 36),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }

  Future<void> _basculerEcoute(_GuideSection section) async {
    if (_sectionLue == section.title && _tts.isPlaying) {
      await _tts.stop();
      return;
    }

    if (!_tts.voixFrancaiseDisponible && _tts.etatVoix != EtatVoix.inconnu) {
      if (!mounted) return;
      AppNotifications.showSnackBar(
        context,
        message: _tts.etatVoix == EtatVoix.moteurIndisponible
            ? "Cet appareil n'a pas de moteur de synthèse vocale."
            : "Aucune voix française installée. Ajoutez-en une dans "
                  "Paramètres › Accessibilité › Synthèse vocale.",
        isError: true,
      );
      return;
    }

    setState(() => _sectionLue = section.title);
    // `speak` arrête d'abord ce qui parle : passer d'une section à l'autre ne
    // superpose pas deux voix.
    await _tts.speak(_texteDe(section), apercu: true);
  }

  /// Le texte d'une section, mis en forme pour l'oreille.
  ///
  /// Les numéros d'étape sont énoncés — « Étape 1 » — sans quoi la voix enchaîne
  /// les consignes sans qu'on sache où l'une finit et où la suivante commence.
  String _texteDe(_GuideSection section) {
    final morceaux = <String>[section.title, section.shortDesc];
    for (var i = 0; i < section.steps.length; i++) {
      morceaux.add("Étape ${i + 1}. ${section.steps[i]}");
    }
    if (section.tip != null && section.tip!.trim().isNotEmpty) {
      morceaux.add("Astuce. ${section.tip}");
    }
    return morceaux.join(". ");
  }

  // ───────────────────── Écouter tout le guide ─────────────────────

  Widget _buildBoutonEcouterTout(
    List<_GuideSection> sections,
    Color accentColor,
  ) {
    final enCours = _lectureTouteIndex >= 0;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: enCours
              ? [accentColor.withOpacity(0.25), accentColor.withOpacity(0.10)]
              : [accentColor.withOpacity(0.12), accentColor.withOpacity(0.04)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(
          color: accentColor.withOpacity(enCours ? 0.5 : 0.25),
          width: 1.2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => enCours
              ? _arreterLectureTotale()
              : _lancerLectureTotale(sections),
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accentColor.withOpacity(0.18),
                    border: Border.all(
                      color: accentColor.withOpacity(0.4),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    enCours ? Icons.stop_rounded : Icons.headphones_rounded,
                    color: accentColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        enCours
                            ? "Arrêter la lecture audio"
                            : "Écouter tout le guide",
                        style: GoogleFonts.poppins(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        enCours
                            ? "Section ${_lectureTouteIndex + 1} / ${_lectureTouteSections.length}"
                            : "La synthèse vocale lit chaque section à la suite.",
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  enCours
                      ? Icons.stop_circle_outlined
                      : Icons.play_circle_fill_rounded,
                  color: accentColor,
                  size: 32,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _lancerLectureTotale(List<_GuideSection> sections) async {
    if (sections.isEmpty) return;

    if (!_tts.voixFrancaiseDisponible && _tts.etatVoix != EtatVoix.inconnu) {
      if (!mounted) return;
      AppNotifications.showSnackBar(
        context,
        message: _tts.etatVoix == EtatVoix.moteurIndisponible
            ? "Cet appareil n'a pas de moteur de synthèse vocale."
            : "Aucune voix française installée. Ajoutez-en une dans "
                  "Paramètres › Accessibilité › Synthèse vocale.",
        isError: true,
      );
      return;
    }

    setState(() {
      _lectureTouteSections = sections;
      _lectureTouteIndex = 0;
    });
    await _lireSectionDuGuide(0);
  }

  Future<void> _lireSectionDuGuide(int index) async {
    if (index < 0 || index >= _lectureTouteSections.length) {
      _arreterLectureTotale();
      return;
    }
    final section = _lectureTouteSections[index];
    setState(() {
      _lectureTouteIndex = index;
      _sectionLue = section.title;
    });
    await _tts.speak(_texteDe(section), apercu: true);
  }

  void _arreterLectureTotale() {
    _tts.stop();
    if (mounted) {
      setState(() {
        _lectureTouteIndex = -1;
        _lectureTouteSections = [];
        _sectionLue = null;
      });
    }
  }

  Widget _buildMiniPlayer(Color accentColor) {
    final sectionTitle =
        _lectureTouteIndex >= 0 &&
            _lectureTouteIndex < _lectureTouteSections.length
        ? _lectureTouteSections[_lectureTouteIndex].title
        : "";
    final isFirst = _lectureTouteIndex <= 0;
    final isLast = _lectureTouteIndex >= _lectureTouteSections.length - 1;

    return Positioned(
      left: 12,
      right: 12,
      bottom: MediaQuery.of(context).padding.bottom + 12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
          border: Border.all(color: accentColor.withOpacity(0.3), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            // Indicateur animé
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentColor.withOpacity(0.15),
              ),
              child: Icon(
                _tts.isPlaying
                    ? Icons.graphic_eq_rounded
                    : Icons.headphones_rounded,
                color: accentColor,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            // Titre de la section
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sectionTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    "${_lectureTouteIndex + 1} / ${_lectureTouteSections.length}",
                    style: GoogleFonts.poppins(
                      fontSize: 10.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            // Contrôles
            IconButton(
              icon: Icon(
                Icons.skip_previous_rounded,
                color: isFirst ? AppColors.textHint : AppColors.textPrimary,
                size: 22,
              ),
              onPressed: isFirst
                  ? null
                  : () => _lireSectionDuGuide(_lectureTouteIndex - 1),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
            IconButton(
              icon: Icon(
                _tts.isPlaying
                    ? Icons.pause_circle_filled_rounded
                    : Icons.play_circle_fill_rounded,
                color: accentColor,
                size: 32,
              ),
              onPressed: () {
                if (_tts.isPlaying) {
                  _tts.pause();
                } else if (_tts.isPaused) {
                  _tts.resume();
                } else {
                  _lireSectionDuGuide(_lectureTouteIndex);
                }
              },
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            ),
            IconButton(
              icon: Icon(
                Icons.skip_next_rounded,
                color: isLast ? AppColors.textHint : AppColors.textPrimary,
                size: 22,
              ),
              onPressed: isLast
                  ? null
                  : () => _lireSectionDuGuide(_lectureTouteIndex + 1),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
            IconButton(
              icon: Icon(
                Icons.close_rounded,
                color: AppColors.textSecondary,
                size: 20,
              ),
              onPressed: _arreterLectureTotale,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(_GuideSection section, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(color: AppColors.textHint.withValues(alpha: 0.12)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: _searchQuery.isNotEmpty,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: section.color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(AppDimensions.radiusInner),
            ),
            child: Icon(section.icon, color: section.color, size: 22),
          ),
          title: Text(
            section.title,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 14.5,
              color: AppColors.textPrimary,
            ),
          ),
          subtitle: Text(
            section.shortDesc,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(height: 20, thickness: 0.8),
            _boutonEcoute(section),
            ...section.steps.asMap().entries.map((entry) {
              final idx = entry.key + 1;
              final text = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 20,
                      width: 20,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: section.color.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        "$idx",
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: section.color,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        text,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (section.tip != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: section.color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(
                    AppDimensions.radiusInner,
                  ),
                  border: Border.all(color: section.color.withOpacity(0.25)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lightbulb_outline_rounded,
                      color: section.color,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        section.tip!,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.textPrimary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GuideSection {
  final IconData icon;
  final Color color;
  final String title;
  final String shortDesc;
  final List<String> steps;
  final String? tip;

  _GuideSection({
    required this.icon,
    required this.color,
    required this.title,
    required this.shortDesc,
    required this.steps,
    this.tip,
  });
}
