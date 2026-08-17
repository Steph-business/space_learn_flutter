import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/themes/app_dimensions.dart';
import 'package:space_learn_flutter/core/utils/app_notifications.dart';
import 'package:space_learn_flutter/core/services/onboarding_guide_service.dart';
import 'package:space_learn_flutter/core/themes/layout/nav_bar_lecteur.dart';
import 'help_faq_page.dart';

/// Page complète du Guide Utilisateur (Manuel Interactif)
/// Couvrant à la fois le Parcours Lecteur et le Parcours Auteur.
class UserGuidePage extends StatefulWidget {
  final bool initialIsAuthor;

  const UserGuidePage({super.key, this.initialIsAuthor = false});

  @override
  State<UserGuidePage> createState() => _UserGuidePageState();
}

class _UserGuidePageState extends State<UserGuidePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialIsAuthor ? 1 : 0,
    );
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AppColors.suivreLeTheme(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAuthorTab = _tabController.index == 1;
    final accentColor =
        isAuthorTab ? AppColors.secondaryVariant : AppColors.purple;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.scaffoldBackground
          : const Color(0xFFF7F8FC),
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
          "Guide d'utilisation",
          style: GoogleFonts.poppins(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2128) : const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(AppDimensions.radiusInner),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withOpacity(0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              labelColor: Colors.white,
              unselectedLabelColor:
                  isDark ? Colors.white60 : const Color(0xFF4B5563),
              labelStyle: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(
                  iconMargin: EdgeInsets.only(bottom: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.menu_book_rounded, size: 18),
                      SizedBox(width: 8),
                      Text("Parcours Lecteur"),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.edit_note_rounded, size: 20),
                      SizedBox(width: 8),
                      Text("Parcours Auteur"),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Barre de recherche dans le guide
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(AppDimensions.radiusInner),
                border: Border.all(
                  color: isDark ? Colors.white12 : Colors.black12,
                ),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: "Rechercher une aide, une fonctionnalité...",
                  hintStyle: GoogleFonts.poppins(
                    fontSize: 13,
                    color: isDark ? Colors.white38 : Colors.black38,
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

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildReaderGuide(isDark),
                _buildAuthorGuide(isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────── Parcours Lecteur ─────────────────────────
  Widget _buildReaderGuide(bool isDark) {
    final List<_GuideSection> sections = [
      _GuideSection(
        icon: Icons.explore_rounded,
        color: AppColors.purple,
        title: "1. Découvrir et trouver des livres",
        shortDesc: "Explorer la boutique, les filtres et les recommandations.",
        steps: [
          "Utilisez la barre de recherche sur la page d'accueil pour chercher par titre ou par nom d'auteur.",
          "Filtrez par thématique (Astronomie, Sciences, Fiction...) via les capsules de catégories.",
          "Consultez les 'Nouveautés' et 'Recommandations pour vous' générées selon vos lectures.",
          "Tapez sur un livre pour ouvrir sa fiche détaillée, lire le résumé, consulter les avis et le prix.",
        ],
        tip: "Ajoutez un livre en favori d'un tap sur le cœur pour le retrouver plus tard dans votre bibliothèque !",
      ),
      _GuideSection(
        icon: Icons.auto_stories_rounded,
        color: const Color(0xFF00B4D8),
        title: "2. Expérience de lecture (Liseuse)",
        shortDesc: "Personnaliser l'affichage, les thèmes et naviguer.",
        steps: [
          "Ouvrez un livre depuis votre bibliothèque pour lancer la liseuse plein écran.",
          "Glissez horizontalement pour tourner les pages ou utilisez le défilement vertical selon le format.",
          "Touchez le centre de l'écran pour afficher la barre d'outils : ajustez la taille de police, la luminosité et choisissez le thème de fond (Clair, Sombre ou Sépia).",
          "Accédez à la Table des matières pour sauter directement à un chapitre précis.",
        ],
        tip: "Votre progression est sauvegardée automatiquement à chaque page lue !",
      ),
      _GuideSection(
        icon: Icons.headphones_rounded,
        color: const Color(0xFF9D4EDD),
        title: "3. Lecture Audio & Synthèse Vocale (TTS)",
        shortDesc: "Écouter les livres à voix haute même écran éteint.",
        steps: [
          "Dans la liseuse, touchez l'icône de casque pour lancer la synthèse vocale.",
          "Réglez la vitesse d'élocution (1.0x, 1.25x, 1.5x) selon votre rythme de confort.",
          "Contrôlez la lecture depuis l'écran de verrouillage ou via les boutons de vos écouteurs Bluetooth.",
          "La lecture audio continue même si vous mettez l'application en arrière-plan.",
        ],
        tip: "Parfait pour continuer à apprendre pendant vos trajets quotidiens ou vos séances de sport.",
      ),
      _GuideSection(
        icon: Icons.download_done_rounded,
        color: const Color(0xFF06D6A0),
        title: "4. Mode Hors-ligne & Téléchargements",
        shortDesc: "Télécharger pour lire sans connexion internet.",
        steps: [
          "Sur la fiche d'un livre acquis, cliquez sur 'Télécharger pour lecture hors-ligne'.",
          "Retrouvez tous vos fichiers téléchargés dans 'Paramètres > Téléchargements'.",
          "Vous pouvez lire tous vos livres hors-ligne n'importe où, même sans réseau.",
        ],
      ),
      _GuideSection(
        icon: Icons.military_tech_rounded,
        color: const Color(0xFFFFB703),
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
        color: const Color(0xFFF72585),
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
        color: const Color(0xFF4361EE),
        title: "7. Paiements & Sécurité",
        shortDesc: "Acheter des livres en toute confiance.",
        steps: [
          "Les paiements sont sécurisés par notre partenaire CinetPay.",
          "Moyens acceptés : Mobile Money (Orange Money, MTN Moov, Wave) et Cartes bancaires.",
          "Après confirmation, le livre est instantanément et définitivement ajouté à votre bibliothèque.",
        ],
      ),
    ];

    return _buildGuideList(
      sections: sections,
      isDark: isDark,
      bannerTitle: "Visite Guidée Interactive de l'Accueil",
      bannerSubtitle: "Relancer le projecteur guidé pas-à-pas sur l'écran d'accueil.",
      bannerIcon: Icons.rocket_launch_rounded,
      bannerColor: AppColors.purple,
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
  Widget _buildAuthorGuide(bool isDark) {
    final List<_GuideSection> sections = [
      _GuideSection(
        icon: Icons.upload_file_rounded,
        color: AppColors.secondaryVariant,
        title: "1. Publier un nouveau livre (PDF / ePUB)",
        shortDesc: "Mettre en ligne votre manuscrit étape par étape.",
        steps: [
          "Rendez-vous sur votre tableau de bord Auteur et cliquez sur 'Ajouter un livre' ou 'Publier'.",
          "Renseignez les informations de base : Titre, Sous-titre, Catégorie et Résumé accrocheur.",
          "Téléversez votre image de couverture haute définition au format portrait.",
          "Uploadez votre manuscrit finalisé au format PDF ou ePUB.",
          "Vérifiez l'aperçu et confirmez la publication pour rendre l'ouvrage disponible dans la boutique.",
        ],
        tip: "Une couverture soignée et un résumé captivant augmentent vos lectures de plus de 60% !",
      ),
      _GuideSection(
        icon: Icons.price_change_rounded,
        color: const Color(0xFF10B981),
        title: "2. Fixation des prix & Droits d'auteur",
        shortDesc: "Modèle de rémunération et tarification.",
        steps: [
          "Vous choisissez librement le prix de vente de votre livre (ou gratuit pour promouvoir vos écrits).",
          "Vos royalties sont créditées directement après chaque achat réussi.",
          "Vous conservez l'intégralité de votre propriété intellectuelle et de vos droits d'auteur.",
        ],
      ),
      _GuideSection(
        icon: Icons.insights_rounded,
        color: const Color(0xFF6366F1),
        title: "3. Tableau de bord & Statistiques de vente",
        shortDesc: "Suivre vos performances et vos lecteurs en temps réel.",
        steps: [
          "Accédez à 'Rapports de ventes' depuis vos paramètres auteur.",
          "Visualisez vos revenus cumulés, vos ventes par période et le taux de complétion de vos livres.",
          "Identifiez vos chapitres les plus lus pour mieux comprendre votre audience.",
        ],
      ),
      _GuideSection(
        icon: Icons.account_balance_rounded,
        color: const Color(0xFFF59E0B),
        title: "4. Retrait des gains & Paiements",
        shortDesc: "Configurer vos coordonnées pour recevoir vos royalties.",
        steps: [
          "Rendez-vous dans 'Informations de paiement' dans les paramètres.",
          "Renseignez votre numéro Mobile Money ou vos coordonnées bancaires.",
          "Demandez un virement de vos gains dès que le seuil minimum de retrait est atteint.",
        ],
      ),
      _GuideSection(
        icon: Icons.campaign_rounded,
        color: const Color(0xFFEC4899),
        title: "5. Fidéliser et engager votre communauté",
        shortDesc: "Interagir avec vos lecteurs et vos abonnés.",
        steps: [
          "Consultez la liste de vos abonnés dans 'Espace Auteur > Abonnés'.",
          "Répondez aux commentaires et aux avis laissés sous vos livres.",
          "Publiez des annonces ou créez des fils de discussion dans le Forum communautaire.",
        ],
      ),
      _GuideSection(
        icon: Icons.swap_horiz_rounded,
        color: const Color(0xFF3B82F6),
        title: "6. Basculer entre le mode Lecteur et Auteur",
        shortDesc: "Un compte unique pour lire et écrire.",
        steps: [
          "Vous pouvez à tout moment passer du mode Auteur au mode Lecteur depuis le menu de profil.",
          "Votre progression de lecture et vos publications d'auteur restent synchronisées sur le même compte.",
        ],
      ),
    ];

    return _buildGuideList(
      sections: sections,
      isDark: isDark,
      bannerTitle: "Besoin d'aide pour publier ?",
      bannerSubtitle: "Consultez la foire aux questions ou contactez l'équipe éditoriale.",
      bannerIcon: Icons.support_agent_rounded,
      bannerColor: AppColors.secondaryVariant,
      onBannerTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const HelpFaqPage()),
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
      final matchSteps =
          sec.steps.any((s) => s.toLowerCase().contains(_searchQuery));
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
                color: isDark ? Colors.white30 : Colors.black26,
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
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
                        borderRadius: BorderRadius.circular(AppDimensions.radiusInner),
                        boxShadow: [
                          BoxShadow(
                            color: bannerColor.withOpacity(0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(bannerIcon, color: Colors.white, size: 24),
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
                              color: AppColors.textPrimary,
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

  Widget _buildSectionCard(_GuideSection section, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04),
        ),
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
                          color: isDark ? Colors.white70 : const Color(0xFF374151),
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
                  borderRadius: BorderRadius.circular(AppDimensions.radiusInner),
                  border: Border.all(
                    color: section.color.withOpacity(0.25),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lightbulb_outline_rounded,
                        color: section.color, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        section.tip!,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: isDark ? Colors.white70 : const Color(0xFF1F2937),
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
