import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/themes/app_dimensions.dart';
import 'package:space_learn_flutter/core/themes/app_text_styles.dart';
import '../../../../utils/token_storage.dart';
import '../../../data/dataServices/badgeService.dart';
import '../../../data/dataServices/libraryService.dart';
import '../../../data/dataServices/readerStatsService.dart';
import '../../../data/dataServices/readingProgressService.dart';
import '../../../data/dataServices/reading_time_storage.dart';
import '../../../data/model/badgeModel.dart';
import '../../../data/model/goalModel.dart';
import '../../../data/model/readingActivityModel.dart';

class BadgesPage extends StatefulWidget {
  final String userId;

  const BadgesPage({super.key, required this.userId});

  @override
  State<BadgesPage> createState() => _BadgesPageState();
}

class _BadgesPageState extends State<BadgesPage>
    with SingleTickerProviderStateMixin {
  final BadgeService _badgeService = BadgeService();
  final ReadingProgressService _progressService = ReadingProgressService();
  final LibraryService _libraryService = LibraryService();

  List<BadgeModel> _badges = [];

  /// Jours de lecture consécutifs. Zéro si la série est rompue.
  int _serieJours = 0;
  List<GoalModel> _goals = [];
  int _totalReadingMinutes = 0;
  bool _isLoading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    try {
      final token = await TokenStorage.getToken();
      final totalMin = await ReadingTimeStorage.getTotalReadingMinutes(
        widget.userId,
      );
      final todayMin = await ReadingTimeStorage.getTodayReadingMinutes(
        widget.userId,
      );

      List<ReadingActivityModel> allProgress = [];
      int libraryCount = 0;
      if (token != null) {
        try {
          allProgress = await _progressService.getAllProgressions(token);
          final lib = await _libraryService.getUserLibrary(token);
          libraryCount = lib.length;
        } catch (_) {}
      }

      int finishedBooks = allProgress
          .where(
            (p) =>
                p.pourcentage >= 100 ||
                (p.lastPage >= p.totalPages && p.totalPages > 0),
          )
          .length;

      final backendBadges = await _badgeService.getUserBadges();
      final backendGoals = await _badgeService.getGoals();

      // Le serveur fait foi quand il répond : son compte suit le lecteur d'un
      // appareil à l'autre. Le comptage local reste tenu en parallèle et sert
      // de repli hors ligne — c'est le seul cas où il décide encore.
      // Le serveur fait foi DÈS QU'IL A QUELQUE CHOSE À DIRE.
      //
      // `??` ne se déclenche que sur null : une table `jours_de_lecture` encore
      // vide renvoie 0, et zéro l'emportait alors sur les 72 minutes comptées
      // par le téléphone. L'écran des badges affichait « 0m » et « 0 jour »
      // pendant que l'accueil affichait « 1h12m » — deux écrans, deux vérités.
      //
      // Tant que le serveur n'a rien enregistré, le comptage local reste la
      // seule source ; il devient un simple cache dès qu'il en a.
      final bilan = await ReaderStatsService().lireBilan();
      final serveurRenseigne = (bilan?['total'] ?? 0) > 0;

      final serieLocale = await ReadingTimeStorage.getReadingStreak(
        widget.userId,
      );
      final serie = serveurRenseigne ? (bilan?['serie'] ?? 0) : serieLocale;
      final totalMinutes = serveurRenseigne ? bilan!['total']! : totalMin;
      final minutesJour = serveurRenseigne ? bilan!['jour']! : todayMin;

      final smartGoals = ReadingTimeStorage.computeSmartGoals(
        booksRead: finishedBooks,
        totalMinutes: totalMinutes,
        todayMinutes: minutesJour,
        libraryCount: libraryCount,
        serieJours: serie,
      );

      // Les deux origines se complètent, elles ne se remplacent pas.
      //
      // Le serveur sait ce qu'il possède : livres terminés, taille de la
      // bibliothèque — et il le sait quel que soit l'appareil. Il ne sait pas
      // le temps de lecture ni la série de jours, que seul le téléphone
      // enregistre. L'ancien « l'un OU l'autre » faisait donc disparaître la
      // série dès que le serveur répondait quoi que ce soit.
      // Une seule valeur par métrique, et c'est le serveur qui l'emporte.
      //
      // Le dédoublonnage se faisait par TITRE : or le serveur écrit « Livres
      // terminés » quand il en compte six, et le calcul local « Premier
      // chef-d'œuvre » quand il en compte zéro. Deux titres, donc deux cartes,
      // qui se contredisaient sur le même écran — 60 % d'un côté, 0 % de
      // l'autre. La clé est désormais l'identifiant de l'objectif, partagé
      // entre les deux origines.
      final clesServeur = backendGoals.map((g) => g.id).toSet();
      final List<GoalModel> finalGoals = [
        ...backendGoals,
        ...smartGoals.where((g) => !clesServeur.contains(g.id)),
      ];

      // Les badges viennent du serveur, et de lui seul.
      //
      // L'écran rejouait ici ses propres règles par-dessus la réponse :
      // « FIRST_STEP si totalMin > 0 », « COLLECTION_2 si libraryCount >= 2 ».
      // Des codes que le serveur ne connaissait pas, des seuils choisis à part.
      // Deux jeux de règles pour une même collection : le téléphone déverrouillait
      // ce que le serveur laissait fermé, et l'écran suivant, qui lisait le
      // serveur, retirait le badge sans explication.
      //
      // Le serveur évalue désormais tout le catalogue à chaque appel — c'est
      // même ce qui déclenche les badges d'assiduité, qui n'ont aucun autre
      // moment pour se débloquer.
      if (mounted) {
        setState(() {
          _totalReadingMinutes = totalMinutes;
          _serieJours = serie;
          _badges = backendBadges;
          _goals = finalGoals;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    AppColors.suivreLeTheme(context);
    final unlockedCount = _badges.where((b) => b.debloqueLe != null).length;
    final formattedTime = ReadingTimeStorage.formatMinutes(
      _totalReadingMinutes,
    );

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.cardBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Statistiques & Récompenses",
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.accentInk,
          unselectedLabelColor: AppColors.textHint,
          labelStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          tabs: const [
            Tab(text: "Objectifs & Défis"),
            // « Badges Débloqués » décrivait un onglet qui ne montrait que les
            // trophées obtenus. Il montre désormais la collection entière.
            Tab(text: "Collection"),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              children: [
                _buildSummaryHeader(unlockedCount, formattedTime),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [_buildGoalsTab(), _buildBadgesTab()],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSummaryHeader(int unlockedCount, String formattedTime) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryDark, AppColors.primary],
        ),
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.18),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      // Trois chiffres, trois colonnes flexibles.
      //
      // Elles étaient deux, libres de leur largeur. À trois, « Temps de
      // lecture », « Jours d'affilée » et « Badges obtenus » ne tiennent plus
      // côte à côte sur un écran de 320 px : une Row non contrainte déborde en
      // rayures jaunes au lieu de réduire. Expanded partage la largeur, et le
      // libellé s'ellipse plutôt que de pousser.
      child: Row(
        children: [
          _statistique(
            icone: Icons.timer_outlined,
            valeur: formattedTime,
            libelle: "Temps de lecture",
          ),
          _separateur(),
          // La série, au milieu, et ce n'est pas un hasard.
          //
          // Le temps cumulé dit ce qui a été fait, les badges ce qui a été
          // atteint ; ni l'un ni l'autre ne donne de raison de revenir demain.
          // La série, si — c'est la seule des trois qu'on puisse perdre.
          _statistique(
            icone: _serieJours > 0
                ? Icons.local_fire_department_rounded
                : Icons.local_fire_department_outlined,
            valeur: "$_serieJours",
            libelle: _serieJours > 1 ? "Jours d'affilée" : "Jour d'affilée",
          ),
          _separateur(),
          _statistique(
            icone: Icons.emoji_events_outlined,
            valeur: "$unlockedCount / ${_badges.length}",
            libelle: "Badges obtenus",
          ),
        ],
      ),
    );
  }

  Widget _separateur() => Container(
    height: 40,
    width: 1,
    color: AppColors.onAccent.withOpacity(0.25),
  );

  /// Une colonne de l'en-tête : icône, chiffre, libellé.
  ///
  /// Les trois blocs étaient recopiés à l'identique ; une retouche sur l'un ne
  /// suivait pas sur les autres.
  Widget _statistique({
    required IconData icone,
    required String valeur,
    required String libelle,
  }) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, color: AppColors.onAccent, size: 24),
          const SizedBox(height: 6),
          Text(
            valeur,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.onAccent,
            ),
          ),
          Text(
            libelle,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: AppColors.onAccent.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalsTab() {
    if (_goals.isEmpty) {
      return Center(
        child: Text(
          "Aucun défi en cours",
          style: GoogleFonts.poppins(color: AppColors.textHint),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _goals.length,
      itemBuilder: (context, index) {
        final goal = _goals[index];
        final progress = goal.progress;
        final isCompleted = goal.estTermine;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
            // Le liseré souligne, il ne confirme pas : il suit donc l'accent,
            // comme la barre. Seule la pastille « Terminé » garde le vert, qui
            // y énonce un fait plutôt que d'orner.
            border: Border.all(
              color: isCompleted
                  ? AppColors.primary.withOpacity(0.4)
                  : AppColors.textPrimary.withOpacity(0.05),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      goal.titre,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? AppColors.success.withOpacity(0.15)
                          : AppColors.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusPill,
                      ),
                    ),
                    child: Text(
                      isCompleted
                          ? "Terminé 🎉"
                          : "${(progress * 100).round()}%",
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isCompleted
                            ? AppColors.success
                            : AppColors.accentInk,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                goal.description,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: AppColors.textHint.withOpacity(0.15),
                  // Une barre pleine reste ambre.
                  //
                  // `success` est la couleur de la confirmation — celle d'un
                  // paiement accepté, d'un enregistrement réussi. L'employer en
                  // décor lui retire son sens partout ailleurs : quand un vrai
                  // succès s'affiche, il ne se distingue plus de rien. La barre
                  // pleine et l'étiquette « Terminé » disent déjà l'atteinte.
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Les badges, rangés par famille.
  ///
  /// Une grille à plat de dix-huit trophées ne se lit pas : rien n'y dit qu'un
  /// lecteur qui ne termine jamais de livre peut quand même en décrocher par
  /// l'assiduité ou la communauté. Les familles rendent visibles les chemins.
  ///
  /// La première section fait exception : elle rassemble les badges obtenus,
  /// toutes familles confondues. C'est celle qu'on vient voir.
  Widget _buildBadgesTab() {
    if (_badges.isEmpty) return _buildEmptyState();

    final obtenus = _badges.where((b) => b.estDebloque).toList();
    final restants = _badges.where((b) => !b.estDebloque).toList();

    // L'ordre du serveur fait foi : il place les plus proches en tête.
    final familles = <String, List<BadgeModel>>{};
    for (final badge in restants) {
      final nom = badge.famille.isEmpty ? 'À décrocher' : badge.famille;
      familles.putIfAbsent(nom, () => []).add(badge);
    }

    return CustomScrollView(
      slivers: [
        if (obtenus.isNotEmpty) ...[
          _titreSection(
            "Vos trophées",
            "${obtenus.length} sur ${_badges.length}",
          ),
          _grilleBadges(obtenus),
        ],
        for (final entree in familles.entries) ...[
          _titreSection(entree.key, _resteAFaire(entree.value)),
          _grilleBadges(entree.value),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  /// « Plus que 1 annotation » vaut mieux que « 0 sur 25 » : on annonce la
  /// marche la plus proche, pas le retard cumulé.
  String _resteAFaire(List<BadgeModel> badges) {
    final proche = badges.first;
    final reste = proche.cible - proche.progression;
    if (reste <= 0 || proche.cible <= 0) return "";
    return "Plus que $reste";
  }

  SliverToBoxAdapter _titreSection(String titre, String indication) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                titre,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (indication.isNotEmpty)
              Text(
                indication,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textHint,
                ),
              ),
          ],
        ),
      ),
    );
  }

  SliverPadding _grilleBadges(List<BadgeModel> badges) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          // Une barre d'avancement et son compteur s'ajoutent sous la
          // description : à 0.85, les cartes débordaient en rayures jaunes.
          childAspectRatio: 0.74,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildBadgeCard(badges[index]),
          childCount: badges.length,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.emoji_events_outlined,
            size: 80,
            color: AppColors.textHint,
          ),
          SizedBox(height: 16),
          // La liste vide ne signifie plus « rien de débloqué » — le serveur
          // renvoie tout le catalogue, verrouillés compris. Elle signifie qu'on
          // n'a pas pu le joindre, et qu'aucune version n'a encore été reçue.
          Text("Collection indisponible", style: AppTextStyles.bodyFaded16),
          Text(
            "Reconnectez-vous pour retrouver vos badges.",
            style: GoogleFonts.poppins(color: AppColors.textHint, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeCard(BadgeModel badge) {
    bool isUnlocked = badge.debloqueLe != null;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(
          color: isUnlocked
              ? AppColors.primary.withOpacity(0.5)
              : AppColors.textHint.withOpacity(0.3),
        ),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isUnlocked
                        ? AppColors.primary.withOpacity(0.12)
                        : AppColors.textHint.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: badge.iconUrl.startsWith('http')
                      ? Image.network(
                          badge.iconUrl,
                          width: 40,
                          height: 40,
                          color: isUnlocked ? null : AppColors.textHint,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.emoji_events,
                            size: 40,
                            color: isUnlocked
                                ? AppColors.accentInk
                                : AppColors.textHint,
                          ),
                        )
                      : Icon(
                          _getIconData(badge.iconUrl),
                          size: 40,
                          color: isUnlocked
                              ? AppColors.accentInk
                              : AppColors.textHint,
                        ),
                ),
                SizedBox(height: 12),
                Text(
                  badge.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    // `Colors.white` était écrit en dur sur `cardBackground` :
                    // en thème clair, le nom du badge disparaissait sur fond
                    // blanc dès qu'il était débloqué — la récompense s'effaçait
                    // au moment précis où elle était méritée.
                    color: isUnlocked
                        ? AppColors.textPrimary
                        : AppColors.textHint,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  badge.description,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: AppColors.textHint,
                  ),
                ),
                if (!isUnlocked && badge.cible > 0) ...[
                  const SizedBox(height: 10),
                  _avancementBadge(badge),
                ],
              ],
            ),
          ),
          if (isUnlocked)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check,
                  size: 10,
                  // Sur un aplat de couleur, c'est `onAccent` qui garantit le
                  // contraste : `textPrimary` suit le fond de page, et virait
                  // au sombre sur le vert en thème clair.
                  color: AppColors.onAccent,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// La distance qui reste, sous la carte d'un badge verrouillé.
  ///
  /// Sans elle, « Plume dans la marge » à 24 annotations sur 25 ressemblait
  /// exactement à « Cinquante heures » à zéro : deux carrés gris.
  Widget _avancementBadge(BadgeModel badge) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
          child: LinearProgressIndicator(
            value: badge.avancement,
            minHeight: 4,
            backgroundColor: AppColors.textHint.withOpacity(0.15),
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          "${badge.progression} / ${badge.cible}",
          style: GoogleFonts.poppins(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppColors.textHint,
          ),
        ),
      ],
    );
  }

  /// Le nom d'icône envoyé par le serveur, traduit en icône Material.
  ///
  /// La table n'en connaissait que cinq ; toutes les autres retombaient sur la
  /// coupe générique, si bien que les badges se ressemblaient tous. Elle suit
  /// maintenant le catalogue du serveur, famille par famille.
  IconData _getIconData(String? name) {
    switch (name) {
      // Premiers pas
      case 'waving_hand':
        return Icons.waving_hand;
      case 'directions_walk':
        return Icons.directions_walk;

      // Assiduité
      case 'local_fire_department':
        return Icons.local_fire_department;
      case 'event_available':
        return Icons.event_available;
      case 'hourglass_bottom':
        return Icons.hourglass_bottom;
      case 'timer':
        return Icons.timer;

      // Lecture
      case 'auto_stories':
        return Icons.auto_stories;
      case 'menu_book':
        return Icons.menu_book;
      case 'local_library':
        return Icons.local_library;
      case 'fitness_center':
        return Icons.fitness_center;

      // Curiosité
      case 'explore':
        return Icons.explore;
      case 'inventory_2':
        return Icons.inventory_2;
      case 'favorite':
        return Icons.favorite;

      // Traces de lecture
      case 'edit_note':
        return Icons.edit_note;

      // Communauté
      case 'rate_review':
        return Icons.rate_review;
      case 'reviews':
        return Icons.reviews;
      case 'forum':
        return Icons.forum;

      case 'stars':
        return Icons.stars;
      default:
        return Icons.emoji_events;
    }
  }
}
