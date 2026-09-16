import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/themes/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:space_learn_flutter/core/themes/app_dimensions.dart';
import 'package:space_learn_flutter/core/utils/app_notifications.dart';
import 'package:space_learn_flutter/core/utils/message_erreur.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:space_learn_flutter/core/services/session_service.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/relationService.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/relationModel.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/auth/login.dart';
import 'package:space_learn_flutter/core/utils/image_reseau.dart';

class AbonnesPage extends StatefulWidget {
  final String authorId;
  const AbonnesPage({super.key, required this.authorId});

  @override
  State<AbonnesPage> createState() => _AbonnesPageState();
}

class _AbonnesPageState extends State<AbonnesPage> {
  final RelationService _relationService = RelationService();
  List<RelationModel> _followers = [];

  /// Combien d'abonnés en tout, d'après le serveur — nul quand il ne l'a pas
  /// dit. Voir [PageDeRelations] : ce n'est PAS `_followers.length`.
  int? _total;

  bool _isLoading = true;
  String? _error;

  /// L'échec est-il une session morte ?
  ///
  /// La cause du serveur était ÉCRASÉE par « Impossible de charger vos
  /// abonnés. » — le `e` était attrapé puis jeté — et le seul bouton offert
  /// était « Réessayer », sans condition. Or l'appel est authentifié (ApiClient
  /// pose le jeton) : le 401 y arrive normalement, et l'auteur au jeton mort
  /// tournait en boucle sur cet écran, chaque appui rejouant la requête que le
  /// serveur venait de refuser.
  bool _sessionFinie = false;

  /// La tranche déjà obtenue. `_followers.length` NE dit pas le total : voir
  /// [PageDeRelations] et [_total].
  int _page = 1;
  bool _chargeLaSuite = false;

  /// La taille d'une tranche, MESURÉE sur ce que le serveur vient de rendre.
  ///
  /// C'était `static const int _parTranche = 100`, c'est-à-dire la valeur de
  /// `PlafondListeNominative` recopiée d'un autre dépôt. Or c'est de ce chiffre
  /// que dépend la continuité de la concaténation : « Voir plus » demande la
  /// page suivante, et le serveur en déduit le décalage en multipliant par la
  /// limite envoyée. Les deux doivent être le MÊME nombre.
  ///
  /// Le serveur a déjà changé ce plafond une fois — de cinq cents à cent — et
  /// le jour où il le rebaissera, une constante figée ici ferait sauter en
  /// silence les abonnés situés entre la taille réelle de la première tranche
  /// et cent, pendant que l'en-tête continuerait d'annoncer le bon total. Le
  /// même écart existe déjà pour un appelant sans compte, que le serveur sert
  /// à vingt-quatre (modules/relations/controller.go, PlafondAnonyme).
  ///
  /// Zéro tant que la première tranche n'est pas arrivée : aucune suite n'est
  /// alors proposée, faute de savoir quoi demander.
  int _tranche = 0;

  /// Reste-t-il des abonnés que cet écran n'a pas ?
  ///
  /// La condition qui manquait au serveur pour redescendre
  /// `PlafondListeNominative` à cent : cet écran affichait la liste sans savoir
  /// en demander la suite, si bien qu'un auteur de trois cents abonnés aurait
  /// lu « 300 abonnés » — juste — au-dessus de cent lignes et d'aucun moyen
  /// d'atteindre les deux cents autres. Elle est remplie depuis que « Voir
  /// plus » existe, et le serveur a baissé son plafond.
  bool get _ilEnReste {
    final total = _total;
    // `_tranche > 0` : sans tranche mesurée on ne sait pas quoi demander, et
    // proposer « Voir plus » serait offrir un bouton qui ne peut pas aboutir.
    return total != null && _tranche > 0 && _followers.length < total;
  }

  @override
  void initState() {
    super.initState();
    _loadFollowers();
  }

  Future<void> _loadFollowers() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
        _sessionFinie = false;
        _page = 1;
      });

      final page = await _relationService.getFollowers(widget.authorId);

      if (mounted) {
        setState(() {
          // La liste affichée est la tranche que le serveur a rendue ; le
          // nombre annoncé vient de `meta.total` et non de sa longueur (voir
          // PageDeRelations). Les deux coïncident tant que tout tient dans une
          // tranche, et cessent de coïncider dès que le plafond descend.
          _followers = page.relations;
          _total = page.nombreConnu;
          // La tranche que le serveur vient de servir fait loi pour la suite.
          _tranche = page.relations.length;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          // La cause vient du serveur, et le geste suit la cause.
          _sessionFinie = estSessionExpiree(e);
          _error = messageLisible(
            e,
            repli: "Impossible de charger vos abonnés.",
          );
          _isLoading = false;
        });
      }
    }
  }

  /// La tranche suivante, concaténée à ce qui est déjà affiché.
  ///
  /// Les DEUX paramètres partent ensemble — voir [RelationService.getFollowers].
  ///
  /// Un échec ici ne détruit RIEN de ce qui est lisible : la liste reste, le
  /// message est furtif, et le bouton revient pour recommencer.
  ///
  /// SAUF SUR UNE SESSION MORTE, et c'était la moitié qui manquait.
  /// `_sessionFinie` n'était posé que par [_loadFollowers] : le jeton qui
  /// meurt pendant qu'on tourne les pages laissait donc un message furtif sous
  /// un bouton « Voir plus » resté actif, c'est-à-dire une invitation à
  /// recommencer un geste qui ne peut par construction pas aboutir. Le serveur
  /// nomme désormais ce cas — 401 « Votre session a expiré. Reconnectez-vous
  /// pour voir la suite de la liste. » (space_learn_livres,
  /// modules/relations/controller.go:356-366) — là où il rendait un 400 qui
  /// reprochait à un connecté de ne pas l'être. `ApiClient` renouvelle et
  /// rejoue tout seul ; quand le renouvellement est impossible, l'erreur
  /// remonte ici, et l'écran mène alors à la connexion.
  Future<void> _chargerLaSuite() async {
    if (_chargeLaSuite) return;
    setState(() => _chargeLaSuite = true);
    try {
      final suivante = _page + 1;
      final page = await _relationService.getFollowers(
        widget.authorId,
        limit: _tranche,
        page: suivante,
      );
      if (!mounted) return;
      setState(() {
        _followers = [..._followers, ...page.relations];
        // `meta.total` est réaffirmé à chaque tranche : on garde le dernier
        // que le serveur ait dit, jamais la longueur de la liste.
        _total = page.nombreConnu ?? _total;
        _page = suivante;
        _chargeLaSuite = false;
      });
    } catch (e) {
      if (!mounted) return;
      // La liste déjà obtenue n'est PAS détruite — voir la note ci-dessus. Ce
      // qui change sur un jeton mort, c'est le geste offert : `_sessionFinie`
      // retire « Voir plus » et l'écran propose « Se reconnecter ».
      final sessionMorte = estSessionExpiree(e);
      setState(() {
        _chargeLaSuite = false;
        if (sessionMorte) _sessionFinie = true;
      });
      AppNotifications.showSnackBar(
        context,
        message: messageLisible(
          e,
          repli: "La suite de la liste n'a pas pu être chargée.",
        ),
        isError: true,
      );
    }
  }

  /// Fin de session complète, puis retour à l'écran de connexion.
  Future<void> _seReconnecter() async {
    await SessionService.terminer();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    AppColors.suivreLeTheme(context);
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text("MES ABONNÉS", style: AppTextStyles.subtitle),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: AppColors.textPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: AppColors.secondaryVariant,
              ),
            )
          : _error != null
          // La panne se distingue du vide, et le GESTE suit la cause : se
          // reconnecter sur un jeton mort — « Réessayer » ne peut alors par
          // construction jamais aboutir —, réessayer sur une panne.
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _sessionFinie
                          ? _seReconnecter
                          : _loadFollowers,
                      child: Text(
                        _sessionFinie ? "Se reconnecter" : "Réessayer",
                      ),
                    ),
                  ],
                ),
              ),
            )
          : _followers.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              // Une ligne d'en-tête quand le serveur a rendu un total, et
              // seulement alors : elle dit COMBIEN, et le dit d'après lui. Une
              // ligne de fin quand il en reste : voir [_ilEnReste].
              itemCount:
                  _followers.length +
                  (_total != null ? 1 : 0) +
                  (_ilEnReste ? 1 : 0),
              itemBuilder: (context, index) {
                if (_total != null) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        _total == 1 ? "1 abonné" : "$_total abonnés",
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }
                  index -= 1;
                }
                if (index >= _followers.length) {
                  // UNE SESSION MORTE NE SE VOIT PAS OFFRIR « VOIR PLUS ».
                  //
                  // La liste déjà obtenue reste à l'écran — elle n'a rien fait
                  // de mal — mais le seul geste qui puisse aboutir est de se
                  // reconnecter, pas de rejouer la requête que le serveur vient
                  // de refuser. Voir [_chargerLaSuite].
                  if (_sessionFinie) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        children: [
                          Text(
                            "$phraseSessionExpiree La suite de la liste "
                            "s'affichera ensuite.",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: _seReconnecter,
                            child: const Text("Se reconnecter"),
                          ),
                        ],
                      ),
                    );
                  }
                  // « VOIR PLUS », ET LE COMPTE QUI DIT COMBIEN IL EN MANQUE.
                  //
                  // Sans lui, l'en-tête annonçait un nombre que l'écran ne
                  // savait pas atteindre — juste, et hors de portée.
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Center(
                      child: TextButton(
                        onPressed: _chargeLaSuite ? null : _chargerLaSuite,
                        child: Text(
                          _chargeLaSuite
                              ? "Chargement…"
                              : "Voir plus (${_total! - _followers.length} restants)",
                          style: TextStyle(color: AppColors.secondaryVariant),
                        ),
                      ),
                    ),
                  );
                }
                final follower = _followers[index];
                // Note: For now we only have IDs, in a real scenario the API
                // should return user details or we fetch them here.
                return _buildFollowerTile(follower);
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 80,
            color: AppColors.textPrimary.withOpacity(0.1),
          ),
          SizedBox(height: 16),
          Text(
            "Vous n'avez pas encore d'abonnés.",
            style: GoogleFonts.poppins(
              color: AppColors.textSecondary,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 8),
          Text(
            "Publiez plus de contenu pour attirer des lecteurs !",
            style: GoogleFonts.poppins(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFollowerTile(RelationModel follower) {
    final name =
        follower.nomComplet ??
        "Lecteur #${follower.utilisateurId.substring(0, 8)}";
    final photo = follower.profilePhoto;

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.secondaryVariant.withOpacity(0.1),
            child: photo != null
                ? ClipOval(
                    child: Image(
                      image: imageReseau(photo),
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.person,
                          color: AppColors.secondaryVariant,
                        );
                      },
                    ),
                  )
                : Icon(Icons.person, color: AppColors.secondaryVariant),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.poppins(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  follower.creeLe != null
                      ? "Abonné depuis le ${follower.creeLe!.day}/${follower.creeLe!.month}/${follower.creeLe!.year}"
                      : "Abonné récemment",
                  style: GoogleFonts.poppins(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              AppNotifications.showSnackBar(
                context,
                message: "Profil de $name",
              );
            },
            child: Text(
              "Profil",
              style: TextStyle(color: AppColors.secondaryVariant),
            ),
          ),
        ],
      ),
    );
  }
}
