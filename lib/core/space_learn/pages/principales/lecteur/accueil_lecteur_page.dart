import 'dart:async';

import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/utils/app_notifications.dart';
import 'package:space_learn_flutter/core/themes/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:space_learn_flutter/core/themes/layout/recherche_bar.dart';
import 'package:space_learn_flutter/core/themes/app_dimensions.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import '../../../data/dataServices/notification_provider.dart';

import '../../widgets/details/book_detail_page.dart';
import '../../widgets/lecteur/boutique/livre_card.dart';
import '../../widgets/details/author_profile_page.dart';
import 'badges_page.dart';
import '../../widgets/lecteur/accueil/daily_goal_section.dart';
import '../../../data/dataServices/badgeService.dart';
import '../../../data/model/goalModel.dart';
import '../../principales/lecteur/all_authors_page.dart';

import '../../../../themes/layout/nav_bar_all.dart';
import '../../../../themes/layout/nav_bar_lecteur.dart';
import '../../widgets/lecteur/communaute/forum_messages_page.dart';

import '../../../data/dataServices/readingProgressService.dart';
import '../../../data/dataServices/reading_time_storage.dart';
import '../../../data/model/readingActivityModel.dart';
import '../../../data/model/badgeModel.dart';
import '../../../data/dataServices/libraryService.dart';
import '../../widgets/lecteur/accueil/continuer_lecture.dart';
import '../../widgets/lecteur/bandeau_ecoute.dart';
import 'package:flutter/scheduler.dart';
import '../../../../services/lecture_audio_livre.dart';
import '../../widgets/details/reading_page.dart';
import '../../../data/dataServices/bookService.dart';
import '../../../data/dataServices/readerStatsService.dart';
import '../../../data/dataServices/lectureService.dart';
import '../../../data/model/book_model.dart';
import '../../../data/model/library_model.dart';
import '../../../data/model/readerStatsModel.dart';
import '../../../data/model/activite_model.dart';
import '../../../data/model/user_model.dart';
import '../../../../utils/token_storage.dart';
import '../../../data/dataServices/categorie_service.dart';
import '../../../data/model/categorie.dart';
import '../../../data/dataServices/discussionService.dart';
import '../../../data/model/discussionModel.dart';
import '../../../data/dataServices/recommendationService.dart';
import '../../../data/model/recommendationModel.dart';
import '../../../data/dataServices/relationService.dart';
import '../../../data/dataServices/authServices.dart';
import '../../../data/model/relationModel.dart';
import '../../../data/dataServices/citation_service.dart';
import '../../../data/model/citation_model.dart';
import 'temps_lecture_page.dart';
import 'package:space_learn_flutter/core/services/onboarding_guide_service.dart';
import 'package:space_learn_flutter/core/widgets/guides/space_learn_tour.dart';
import 'package:space_learn_flutter/core/utils/message_erreur.dart';
import 'package:space_learn_flutter/core/services/session_service.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/auth/login.dart';

class HomePageLecteur extends StatefulWidget {
  final String profileId;
  final String userName;

  const HomePageLecteur({
    super.key,
    required this.profileId,
    this.userName = 'Utilisateur',
  });

  @override
  State<HomePageLecteur> createState() => _HomePageLecteurState();
}

class _HomePageLecteurState extends State<HomePageLecteur> {
  final BookService _bookService = BookService();
  final ReaderStatsService _statsService = ReaderStatsService();
  final Lectureservice _lectureService = Lectureservice();
  final CategorieService _categorieService = CategorieService();
  final DiscussionService _discussionService = DiscussionService();
  final RecommendationService _recommendationService = RecommendationService();
  final RelationService _relationService = RelationService();
  final LibraryService _libraryService = LibraryService();
  final AuthService _authService = AuthService();
  final BadgeService _badgeService = BadgeService();
  final CitationService _citationService = CitationService();
  final ReadingProgressService _progressService = ReadingProgressService();

  final GlobalKey _searchBarKey = GlobalKey();
  final GlobalKey _dailyGoalKey = GlobalKey();
  final GlobalKey _featuredBooksKey = GlobalKey();

  GoalModel? _dailyGoal;

  /// La bibliothèque, progressions déjà fusionnées.
  ///
  /// Elle était calculée puis jetée : `updatedLibrary` ne servait qu'à
  /// compter les livres terminés. La garder ne coûte aucun appel de plus —
  /// `/api/library` est déjà dans le `Future.wait` du chargement — et c'est
  /// elle qui dit quel livre est en cours.
  List<LibraryModel> _bibliotheque = const [];

  /// L'écoute d'un livre, sans l'ouvrir.
  ///
  /// Le service est unique : un seul livre parle à la fois, et l'écoute survit
  /// à cet écran.
  final LectureAudioLivre _audio = LectureAudioLivre.instance;
  CitationModel? _dailyCitation;

  bool _isLoading = true;
  String? _error;

  /// La panne vient-elle d'une session finie plutôt que d'un incident passager ?
  ///
  /// Les deux n'appellent pas le même geste : l'une se répare en réessayant,
  /// l'autre jamais.
  bool _sessionExpiree = false;
  ReaderStatsModel? _stats;

  /// Jours de lecture consécutifs, tenus par le serveur quand il les connaît.
  int _serieJours = 0;

  List<BookModel> _featuredBooks = [];
  List<BookModel> _recommendations = [];
  List<BookModel> _allBooks = [];

  List<UserModel> _featuredAuthors = [];
  List<ReviewModel> _recentActivities = [];
  List<Categorie> _categories = [];
  Set<String> _ownedBookIds = {};
  List<Discussion> _discussions = [];
  String? _currentUserId;
  Set<String> _followingIds = {};
  String _displayName = "Utilisateur";
  String? _profilePhoto;
  String _selectedCategory = "Tous";
  String _selectedSection = "Tout";
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  List<BookModel> _searchResults = [];
  bool _isSearching = false;

  /// La recherche de l'accueil interroge le serveur, comme la boutique.
  ///
  /// L'ancien filtre local ne fouillait que `_allBooks` — une seule page de
  /// 100 livres. Dès que le catalogue dépassait cette page, un ouvrage de la
  /// page 2 était « introuvable » ici alors que la boutique le trouvait :
  /// deux barres de recherche, deux vérités.
  Timer? _attenteRecherche;

  /// Jeton : la réponse d'une frappe ancienne ne doit pas écraser celle de la
  /// frappe courante.
  int _jetonRecherche = 0;
  bool _rechercheEnCours = false;
  String? _erreurRecherche;

  /// Pannes par section, posées par les `catchError` de [_loadData].
  ///
  /// Sans elles, un repli silencieux sur une liste vide était indistinguable
  /// d'un vide réel — et l'écran comblait ce vide avec des auteurs, forums et
  /// citations INVENTÉS (« Marie Dubois », « Science-fiction & Futurs — 12
  /// messages »...) que le lecteur prenait pour la communauté réelle.
  bool _livresEnPanne = false;
  bool _forumsEnPanne = false;
  bool _avisEnPanne = false;

  /// La citation du jour vit à côté des avis dans la même section : si SEUL
  /// son appel échoue, le drapeau des avis reste baissé et la section
  /// afficherait « aucune citation » pour une panne. Elle a donc le sien.
  bool _citationEnPanne = false;

  void _onSearch(String value) {
    _attenteRecherche?.cancel();
    setState(() {
      _searchQuery = value;
      _isSearching = value.isNotEmpty;
    });

    // Le serveur ignore une recherche de moins de deux caractères : lancer la
    // requête quand même rendrait la première page entière du catalogue en la
    // faisant passer pour des résultats.
    if (value.trim().length < 2) {
      _jetonRecherche++; // invalide toute réponse encore en vol
      setState(() {
        _searchResults = [];
        _erreurRecherche = null;
        _rechercheEnCours = false;
      });
      return;
    }

    // Anti-rebond : « quantique » ne doit pas déclencher neuf requêtes.
    // L'indicateur part dès la frappe : sinon, pendant l'attente, l'écran
    // affirmerait « Aucun résultat » pour un terme pas encore cherché.
    setState(() {
      _rechercheEnCours = true;
      _erreurRecherche = null;
    });
    _attenteRecherche = Timer(const Duration(milliseconds: 350), () {
      if (mounted) _rechercherSurLeServeur(value);
    });
  }

  Future<void> _rechercherSurLeServeur(String value) async {
    final jeton = ++_jetonRecherche;
    setState(() {
      _rechercheEnCours = true;
      _erreurRecherche = null;
    });

    try {
      final token = await TokenStorage.getToken();
      final resultats = await _bookService.getBooksPage(
        authToken: token,
        recherche: value,
      );

      // Réponse dépassée par une frappe plus récente : on la jette, sinon les
      // résultats de « har » s'affichent sous le titre « harry ».
      if (!mounted || jeton != _jetonRecherche) return;
      setState(() {
        _searchResults = resultats;
        _rechercheEnCours = false;
      });
    } catch (e) {
      if (!mounted || jeton != _jetonRecherche) return;
      setState(() {
        // Une panne n'est pas « aucun résultat » : l'état d'erreur l'affiche
        // comme telle, avec de quoi réessayer.
        _searchResults = [];
        _erreurRecherche = messageLisible(
          e,
          repli: "La recherche n'a pas abouti.",
        );
        _rechercheEnCours = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _displayName = widget.userName;
    _initDisplayName();
    _loadData();
    // Sans cet abonnement, `_surEcoute` n'était jamais appelé : `flutter
    // analyze` le signalait d'ailleurs comme déclaré et non référencé.
    //
    // La conséquence se voyait à l'écran. Le bouton ▶ de « Continuer la
    // lecture » lançait bien la voix, mais rien ne redessinait l'écran : la
    // flèche ne devenait jamais deux barres, la roue de préparation
    // n'apparaissait pas, et le bandeau d'écoute — posé en
    // `bottomNavigationBar` sur `_audio.actif` — ne s'affichait pas non plus.
    // On lançait une voix qu'aucun bouton de cet écran ne pouvait plus
    // arrêter.
    //
    // La bibliothèque, qui porte la même carte, s'abonnait déjà ainsi.
    _audio.addListener(_surEcoute);
  }

  @override
  void dispose() {
    _attenteRecherche?.cancel();
    // Le service est unique et survit à cet écran : ne pas se désabonner
    // laisserait une fermeture appeler `setState` sur un widget démonté.
    _audio.removeListener(_surEcoute);
    super.dispose();
  }

  /// Le livre à reprendre : celui qu'on a lu le plus récemment.
  ///
  /// « En cours » veut dire commencé et pas fini — le même test que la
  /// bibliothèque (bibliotheque_page.dart), pour que les deux écrans ne se
  /// contredisent pas. Le tri par dernière lecture vient du même endroit.
  ///
  /// Un livre terminé n'a pas à revenir en tête d'accueil, et un livre jamais
  /// ouvert n'est pas une reprise : c'est une découverte, et « Nouveautés » s'en
  /// charge quelques centimètres plus bas.
  LibraryModel? get _lectureEnCours {
    final encours = _bibliotheque.where((item) {
      final p = item.livre?.progressions;
      if (p == null || p.isEmpty) return false;
      final pourcentage = p.first.pourcentage.toDouble();
      return pourcentage > 0 && pourcentage < 100;
    }).toList();

    if (encours.isEmpty) return null;

    encours.sort((a, b) {
      DateTime quand(LibraryModel item) {
        final p = item.livre?.progressions;
        if (p != null && p.isNotEmpty && p.first.majLe != null) {
          return p.first.majLe!;
        }
        return item.creeLe ?? DateTime(0);
      }

      return quand(b).compareTo(quand(a));
    });
    return encours.first;
  }

  /// Ouvre le livre repris à la page où on l'a laissé.
  /// Lance ou suspend l'écoute du livre repris, sans ouvrir la liseuse.
  ///
  /// La carte est construite à la main plutôt que par `toJson()` : celui-ci ne
  /// porte pas de clé `auteur_nom`, et le service la lit pour titrer la
  /// notification système. Sans elle, le bandeau annonce un auteur vide.
  Future<void> _ecouter(BookModel livre) async {
    await _audio.basculer({
      'id': livre.id,
      'titre': livre.titre,
      'auteur_nom': livre.authorName,
      'fichier_url': livre.fichierUrl,
      'format': livre.format,
      'image_couverture': livre.imageCouverture,
    });
  }

  /// L'état de l'écoute a changé : la carte doit le refléter.
  void _surEcoute() {
    if (!mounted) return;

    // Une notification peut tomber en pleine frame : le service est partagé et
    // ses méthodes ne rencontrent pas toujours un `await` avant de notifier.
    // `setState` et `showSnackBar` lèvent tous les deux dans cette phase.
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase != SchedulerPhase.idle &&
        phase != SchedulerPhase.postFrameCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) _surEcoute();
      });
      return;
    }

    setState(() {});

    // Une erreur d'écoute se dit une fois, puis se retire — un EPUB refusé,
    // un fichier qui ne vient pas.
    final erreur = _audio.erreur;
    if (erreur != null) {
      AppNotifications.showSnackBar(context, message: erreur, isError: true);
    }
  }

  Future<void> _reprendre(LibraryModel item) async {
    final livre = item.livre;
    if (livre == null) return;

    final p = livre.progressions;
    int? page;
    if (p != null && p.isNotEmpty) {
      if (p.first.lastPage > 0) {
        page = p.first.lastPage;
      } else if (p.first.chapitreCourant > 0) {
        page = p.first.chapitreCourant;
      }
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ReadingPage(book: livre.toJson(), initialPage: page),
      ),
    );
    // Au retour, la progression a bougé : l'accueil doit la relire, sinon la
    // carte annonce encore la page d'avant.
    if (mounted) _loadData();
  }

  Future<void> _checkAndShowTour() async {
    final shouldShow = await OnboardingGuideService.shouldShowHomeTour();
    if (shouldShow && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 650), () {
          if (mounted) {
            SpaceLearnTour.startHomeTour(
              context: context,
              searchBarKey: _searchBarKey,
              // La deuxième étape vise la carte de cet emplacement, que ce
              // soit la reprise de lecture ou l'objectif quotidien.
              dailyGoalKey: (_lectureEnCours != null || _dailyGoal != null)
                  ? _dailyGoalKey
                  : null,
              featuredBooksKey: _featuredBooks.isNotEmpty
                  ? _featuredBooksKey
                  : null,
            );
          }
        });
      });
    }
  }

  Future<void> _initDisplayName() async {
    final savedName = await TokenStorage.getUserName();
    if (savedName != null && mounted && _displayName == widget.userName) {
      setState(() {
        _displayName = savedName;
      });
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
      // Sans cette remise à zéro, un incident réseau survenant après une
      // session expirée garderait le bouton « Se reconnecter ».
      _sessionExpiree = false;
      // Chaque rechargement repart d'un état sain : une panne passée ne doit
      // pas continuer à s'afficher après un chargement qui a abouti.
      _livresEnPanne = false;
      _forumsEnPanne = false;
      _avisEnPanne = false;
      _citationEnPanne = false;
    });

    try {
      final token = await TokenStorage.getToken();
      if (token == null) throw Exception("Session expirée");

      // Get current user Id to prevent self-following
      final user = await _authService.getUser(token);
      if (user != null && mounted) {
        setState(() {
          _currentUserId = user.id;
          // Rattrape les sessions ouvertes avant que l'identifiant soit
          // enregistré à la connexion.
          TokenStorage.saveUserId(user.id);
          if (user.nomComplet.isNotEmpty) {
            _displayName = user.nomComplet;
            TokenStorage.saveUserName(user.nomComplet); // Sync storage
          }
          _profilePhoto = user.profilePhoto;
        });
      }

      final readingMinutes = await ReadingTimeStorage.getTotalReadingMinutes(
        user?.id ?? widget.profileId,
      );
      final todayReadingMinutes =
          await ReadingTimeStorage.getTodayReadingMinutes(
            user?.id ?? widget.profileId,
          );

      // `getReaderStats` ouvrait cette liste ; il n'y est plus.
      //
      // Il appelait `GET /api/analytics/reader/:livre_id` — la route des
      // statistiques D'UN LIVRE — avec `widget.profileId`, un identifiant
      // d'UTILISATEUR. La requête ne trouvait donc jamais rien et le service
      // rendait des statistiques factices, toutes à zéro, que cet écran
      // consommait comme une vraie réponse. Les deux chiffres qu'on en tirait
      // (`booksRead`, `totalTime`) viennent désormais l'un et l'autre de
      // `lireBilan()`, lu quelques lignes plus bas, avec repli sur le comptage
      // local de l'appareil.
      final results = await Future.wait([
        // L'accueil presente une selection, pas le catalogue : une page
        // suffit. Charger davantage serait telecharger des livres que
        // personne ne verra.
        //
        // Le repli sur [] reste — une section en panne ne doit pas emporter
        // tout l'accueil — mais il se NOTE : c'est ce drapeau qui permet aux
        // sections d'afficher une panne plutot qu'un vide (ou pire, du
        // contenu invente).
        _bookService.getBooksPage(authToken: token).catchError((e) {
          _livresEnPanne = true;
          return <BookModel>[];
        }),
        _lectureService.getAllReviews(token).catchError((e) {
          _avisEnPanne = true;
          return <ReviewModel>[];
        }),
        _categorieService.getCategories().catchError((e) {
          return <Categorie>[];
        }),
        _discussionService.getGlobalDiscussions().catchError((e) {
          _forumsEnPanne = true;
          return <Discussion>[];
        }),
        _recommendationService.getRecommendations(token).catchError((e) {
          return <RecommendationModel>[];
        }),
        _libraryService.getUserLibrary(token).catchError((e) {
          return <LibraryModel>[];
        }),
        (user != null)
            ? _relationService.getFollowing(user.id).catchError((e) {
                return <RelationModel>[];
              })
            : Future.value(<RelationModel>[]),
        _badgeService.getGoals().catchError((e) {
          return <GoalModel>[];
        }),
        // Le service ne rend plus `null` que lorsque le serveur n'a
        // réellement pas de citation : un échec se note, comme pour les
        // livres et les forums.
        _citationService.getDailyCitation(token).catchError((e) {
          _citationEnPanne = true;
          return null;
        }),
        _progressService.getAllProgressions(token).catchError((e) {
          return <ReadingActivityModel>[];
        }),
        _badgeService.getUserBadges().catchError((e) {
          return <BadgeModel>[];
        }),
      ]);

      // Le bilan tenu par le serveur, lu avant d'entrer dans setState : celui-ci
      // est synchrone et n'attend rien.
      final bilan = await _statsService.lireBilan();
      final serveurRenseigne = (bilan?['total'] ?? 0) > 0;
      final serieLocale = await ReadingTimeStorage.getReadingStreak(
        widget.profileId,
      );
      // La cible que le lecteur a RÉELLEMENT réglée.
      //
      // `computeSmartGoals` la prend en paramètre nommé avec 15 par défaut, et
      // les deux appelants l'omettaient : régler 30 minutes sur la page
      // « Temps de lecture » n'avait donc aucun effet ici ni sur l'écran des
      // badges, qui continuaient d'annoncer « Lire au moins 15 minutes
      // aujourd'hui ». Trois écrans, un seul réglage, deux valeurs.
      //
      // Lue ICI et non dans le `setState` qui suit : celui-ci est synchrone et
      // n'attend rien.
      final cibleQuotidienne = await ReadingTimeStorage.getDailyGoalMinutes(
        widget.profileId,
      );

      if (mounted) {
        context
            .read<NotificationProvider>()
            .loadNotifications(token)
            .catchError((e) {});
        setState(() {
          // Les rangs sont décalés d'un cran depuis le retrait de
          // `getReaderStats`, qui occupait le rang 0 : ils suivent l'ordre du
          // `Future.wait` ci-dessus, et rien d'autre.
          final allBooks = (results[0] as List).cast<BookModel>();
          final reviews = (results[1] as List).cast<ReviewModel>();
          final categories = (results[2] as List).cast<Categorie>();
          final discussions = (results[3] as List).cast<Discussion>();
          final recs = (results[4] as List).cast<RecommendationModel>();
          final library = (results.length > 5 && results[5] is List)
              ? (results[5] as List).cast<LibraryModel>()
              : <LibraryModel>[];
          final followings = (results.length > 6 && results[6] is List)
              ? (results[6] as List).cast<RelationModel>()
              : <RelationModel>[];
          final backendGoals = (results.length > 7 && results[7] is List)
              ? (results[7] as List).cast<GoalModel>()
              : <GoalModel>[];
          final citation = results.length > 8
              ? results[8] as CitationModel?
              : null;
          final allProgress = (results.length > 9 && results[9] is List)
              ? (results[9] as List).cast<ReadingActivityModel>()
              : <ReadingActivityModel>[];
          final backendBadges = (results.length > 10 && results[10] is List)
              ? (results[10] as List).cast<BadgeModel>()
              : <BadgeModel>[];

          _recentActivities = reviews;
          _dailyCitation = citation;
          _categories = categories;
          _discussions = discussions;
          if (_discussions.isNotEmpty) {
            _discussions.sort((a, b) {
              if (a.creeLe != null && b.creeLe != null) {
                return b.creeLe!.compareTo(a.creeLe!);
              }
              return b.id.compareTo(a.id);
            });
          }

          // Map allProgress onto library
          final Map<String, ReadingActivityModel> progressMap = {};
          for (var p in allProgress) {
            if (p.livreId.isNotEmpty) {
              progressMap[p.livreId] = p;
            }
          }
          final updatedLibrary = library.map((item) {
            if (item.livre != null) {
              final prog = progressMap[item.livre!.id];
              if (prog != null) {
                return item.copyWith(
                  livre: item.livre!.copyWith(progressions: [prog]),
                );
              }
            }
            return item;
          }).toList();

          _bibliotheque = updatedLibrary;

          // Compute accurate books read
          int finishedReading = allProgress.where((p) {
            return p.pourcentage >= 100 ||
                (p.lastPage >= p.totalPages && p.totalPages > 0);
          }).length;

          if (finishedReading == 0) {
            finishedReading = updatedLibrary.where((item) {
              final p = item.livre?.progressions;
              return p != null &&
                  p.isNotEmpty &&
                  (p.first.pourcentage >= 100 ||
                      (p.first.lastPage >= p.first.totalPages &&
                          p.first.totalPages > 0));
            }).length;
          }

          // Le bilan du lecteur fait foi : c'est la seule définition qui reste.
          //
          // Cette ligne valait auparavant :
          //     (apiStats.booksRead > 0 && apiStats.booksRead != 12)
          //         ? apiStats.booksRead : finishedReading
          // Le « != 12 » écartait une valeur de démonstration écrite en dur
          // ailleurs — un nombre magique pour contourner un autre défaut. Et
          // `apiStats` venait de `/api/analytics/reader/:livre_id`, une route
          // qui rend les statistiques D'UN LIVRE : l'application y envoyait un
          // identifiant d'utilisateur, ne recevait jamais de champ `books_read`
          // et retombait donc toujours sur le comptage local. Cet appel est
          // maintenant retiré de la liste ci-dessus, faute de route juste.
          //
          // `bilan['lus']` compte les livres terminés ET possédés. Sans la
          // jointure sur la bibliothèque, ce compte montait à 6 pour un lecteur
          // qui ne possède que 2 livres : des extraits parcourus, des essais.
          // Le gardien est `bilan != null`, et non `serveurRenseigne` : ce
          // dernier dit si le serveur a enregistré des MINUTES de lecture, ce
          // qui n'a rien à voir avec le nombre de livres terminés. Un lecteur
          // ayant fini un livre avant que le décompte du temps n'existe serait
          // retombé sur le comptage local — le mauvais.
          //
          // Un zéro venu du serveur est ici une vraie réponse, pas une absence :
          // c'est lui qui sait ce que le lecteur possède.
          int displayedBooksRead = bilan != null
              ? (bilan['lus'] ?? finishedReading)
              : finishedReading;

          // Le temps de l'APPAREIL, repli quand le compte n'a rien à dire.
          //
          // Un second repli suivait, sur `apiStats.totalTime`, gardé par trois
          // comparaisons à des chaînes en dur — '0h', '0m' et surtout '34h',
          // une durée de démonstration qu'il fallait écarter à la main. Il ne
          // servait à rien : `apiStats` venait de la route par livre décrite
          // ci-dessus et n'a jamais rapporté de durée. Le vrai temps du compte
          // est lu par `lireBilan()` et l'emporte juste en dessous.
          final String formattedTime = ReadingTimeStorage.formatMinutes(
            readingMinutes,
          );

          // Compute smart & backend goals
          final smartGoals = ReadingTimeStorage.computeSmartGoals(
            dailyGoalTarget: cibleQuotidienne,
            booksRead: displayedBooksRead,
            totalMinutes: readingMinutes,
            todayMinutes: todayReadingMinutes,
            libraryCount: library.length,
          );

          // Les deux origines se complètent, elles ne se remplacent pas.
          //
          // Le « l'un OU l'autre » faisait disparaître la série et l'objectif
          // du jour dès que le serveur répondait quoi que ce soit — il ne sait
          // calculer ni l'un ni l'autre. Même règle que sur la page des
          // statistiques : clé de l'objectif, le serveur l'emporte.
          final clesServeur = backendGoals.map((g) => g.id).toSet();
          final List<GoalModel> finalGoals = [
            ...backendGoals,
            ...smartGoals.where((g) => !clesServeur.contains(g.id)),
          ];

          if (finalGoals.isNotEmpty) {
            _dailyGoal = finalGoals.firstWhere(
              (g) => g.type == 'DAILY',
              orElse: () => finalGoals.first,
            );
          }

          // La série remplace l'ancien décompte d'objectifs sur la troisième
          // tuile. Le serveur fait foi dès qu'il a enregistré quelque chose ;
          // sinon le comptage local reste la seule source. `??` ne suffirait
          // pas : une table encore vide renvoie 0, pas null.
          _serieJours = serveurRenseigne ? (bilan?['serie'] ?? 0) : serieLocale;

          _stats = ReaderStatsModel(
            booksRead: displayedBooksRead,
            totalTime: serveurRenseigne
                ? ReadingTimeStorage.formatMinutes(bilan!['total']!)
                : formattedTime,
            // Conservé pour le modèle, mais plus affiché : il valait
            // `max(objectifs terminés, badges débloqués)`, deux grandeurs sans
            // rapport. Les badges se comptent sur leur propre écran.
            goalsAchieved: backendBadges
                .where((b) => b.debloqueLe != null)
                .length,
          );

          // 1. Build a comprehensive Author Map from all available sources
          final Map<String, UserModel> knownAuthors = {};

          // Source A: Following (very reliable for names)
          for (var f in followings) {
            if (f.nomComplet != null && f.nomComplet!.isNotEmpty) {
              knownAuthors[f.suitId] = UserModel(
                id: f.suitId,
                profilId: f.suitId,
                email: '',
                nomComplet: f.nomComplet!,
                profilePhoto: f.profilePhoto,
                isProfileComplete: false,
              );
            }
          }

          // Source B: Library (often contains enriched names from joins)
          for (var item in library) {
            final authorId = item.livre?.auteurId;
            if (authorId != null && authorId.isNotEmpty) {
              if (item.livre!.auteur != null &&
                  item.livre!.auteur!.nomComplet != 'Auteur inconnu') {
                knownAuthors[authorId] = item.livre!.auteur!;
              } else if (item.auteurNom != null &&
                  item.auteurNom!.isNotEmpty &&
                  item.auteurNom != 'Auteur inconnu') {
                knownAuthors[authorId] = UserModel(
                  id: authorId,
                  profilId: authorId,
                  email: '',
                  nomComplet: item.auteurNom!,
                  isProfileComplete: false,
                );
              }
            }
          }

          // Source C: Books list
          for (var book in allBooks) {
            if (book.auteur != null &&
                book.auteur!.nomComplet != 'Auteur inconnu') {
              knownAuthors[book.auteurId] = book.auteur!;
            }
          }

          // 2. Enrich ALL books with the best author data found
          BookModel enrichBook(BookModel b) {
            if (knownAuthors.containsKey(b.auteurId)) {
              final bestAuthor = knownAuthors[b.auteurId]!;
              // Only update if current is missing or "Auteur inconnu"
              if (b.auteur == null ||
                  b.auteur!.nomComplet == 'Auteur inconnu') {
                return b.copyWith(auteur: bestAuthor);
              }
            }
            return b;
          }

          _allBooks = allBooks.map(enrichBook).toList();

          // 3. Enrich reviews (Recent Activities) with book data
          final Map<String, BookModel> booksById = {
            for (var b in _allBooks) b.id: b,
          };

          _recentActivities = _recentActivities.map((review) {
            BookModel? book = booksById[review.livreId];
            if (book != null) {
              return ReviewModel(
                id: review.id,
                utilisateurId: review.utilisateurId,
                livreId: review.livreId,
                note: review.note,
                commentaire: review.commentaire,
                creeLe: review.creeLe,
                livre: book,
                utilisateur: review.utilisateur,
                nomUtilisateur: review.nomUtilisateur,
              );
            }
            return review;
          }).toList();

          // Sort reviews by date descending (Handle nulls by putting them at the end)
          _recentActivities.sort((a, b) {
            if (a.creeLe != null && b.creeLe != null) {
              return b.creeLe!.compareTo(a.creeLe!);
            } else if (a.creeLe == null && b.creeLe != null) {
              return 1; // a is null, put it after b
            } else if (a.creeLe != null && b.creeLe == null) {
              return -1; // b is null, put a before b
            }
            return 0;
          });

          // Limit to most recent activities to avoid long lists
          if (_recentActivities.length > 15) {
            _recentActivities = _recentActivities.take(15).toList();
          }

          _recommendations = recs
              .where((r) => r.livre != null)
              .map((r) => enrichBook(r.livre!))
              .toList();

          // Sur les IDENTIFIANTS seulement : comparer les noms marquait
          // « possédé » tous les livres d'un auteur homonyme du lecteur — un
          // « Jean Dupont » lecteur voyait les livres d'un « Jean Dupont »
          // auteur comme déjà acquis, sans bouton d'achat.
          final authorOwnBookIds = _allBooks
              .where(
                (b) =>
                    (b.auteurId.isNotEmpty && b.auteurId == _currentUserId) ||
                    (b.auteur != null && b.auteur!.id == _currentUserId),
              )
              .map((b) => b.id);

          _ownedBookIds = {
            ...library.map((item) => item.livreId),
            ...authorOwnBookIds,
          };
          _followingIds = followings.map((f) => f.suitId).toSet();

          // 3. Finalize Lists
          // Nouveautés
          _featuredBooks = List.from(_allBooks);
          _featuredBooks.sort((a, b) {
            if (a.creeLe != null && b.creeLe != null) {
              return b.creeLe!.compareTo(a.creeLe!);
            }
            return b.id.compareTo(a.id);
          });
          _featuredBooks = _featuredBooks.take(5).toList();

          // Auteurs à suivre
          final Map<String, UserModel> authorsToFollowMap = {};
          for (var book in _allBooks) {
            final authorId = book.auteurId;
            if (authorId.isEmpty || authorId == _currentUserId) continue;

            if (knownAuthors.containsKey(authorId)) {
              authorsToFollowMap[authorId] = knownAuthors[authorId]!;
            } else {
              authorsToFollowMap[authorId] = UserModel(
                id: authorId,
                profilId: authorId,
                email: '',
                nomComplet: (book.authorName != 'Auteur inconnu')
                    ? book.authorName
                    : "Auteur #${authorId.length > 5 ? authorId.substring(0, 5) : authorId}",
                isProfileComplete: false,
              );
            }
          }
          _featuredAuthors = authorsToFollowMap.values.take(10).toList();
        });

        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          _checkAndShowTour();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _sessionExpiree = estSessionExpiree(e);
          _error = messageLisible(
            e,
            repli: "Impossible de charger vos données.",
          );
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    AppColors.suivreLeTheme(context);
    return MainNavBar(
      key: MainNavBar.mainNavBarKey,
      child: Scaffold(
        key: PageStorageKey('homePageLecteur'),
        backgroundColor: AppColors.scaffoldBackground,
        // Sans lui, une voix lancée depuis cette carte n'aurait aucun moyen
        // d'être arrêtée hors de la notification système.
        bottomNavigationBar: _audio.actif ? const BandeauEcoute() : null,
        body: Column(
          children: [
            NavBarAll(
              userName: _displayName,
              userUrl: _profilePhoto,
              role: 'lecteur',
            ),
            Expanded(
              child: _isLoading
                  ? Center(
                      child: Text(
                        "Chargement...",
                        style: GoogleFonts.poppins(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadData,
                      color: AppColors.indigo,
                      child: _error != null
                          ? _buildErrorState()
                          : _isSearching
                          ? _buildSearchResults()
                          : _buildContent(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      key: _searchBarKey,
      padding: const EdgeInsets.fromLTRB(24, 4, 16, 2),
      child: Row(
        children: [
          Expanded(
            child: CustomSearchBar(
              controller: _searchController,
              onChanged: _onSearch,
              hintText: "Rechercher un livre, un auteur...",
            ),
          ),
          SizedBox(width: 10),
          PopupMenuButton<String>(
            icon: Container(
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(AppDimensions.radiusInner),
                border: Border.all(
                  color: _selectedSection != "Tout"
                      ? AppColors.accentInk
                      : AppColors.textHint,
                ),
              ),
              child: Icon(
                Icons.tune,
                color: _selectedSection != "Tout"
                    ? AppColors.accentInk
                    : AppColors.textSecondary,
                size: 20,
              ),
            ),
            offset: Offset(0, 52),
            color: AppColors.cardBackground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusInner),
            ),
            onSelected: (value) {
              setState(() {
                _selectedSection = value;
              });
            },
            itemBuilder: (context) {
              final List<Map<String, dynamic>> menuItems = [
                {'label': 'Tout', 'icon': Icons.dashboard_outlined},
                {'label': 'Nouveautés', 'icon': Icons.new_releases_outlined},
                {'label': 'Recommandations', 'icon': Icons.recommend},
                {'label': 'Auteurs', 'icon': Icons.people_outline},
                {'label': 'Forum', 'icon': Icons.forum_outlined},
              ];
              return menuItems.map((item) {
                final isSelected = _selectedSection == item['label'];
                return PopupMenuItem<String>(
                  value: item['label'],
                  height: 40,
                  child: Row(
                    children: [
                      Icon(
                        item['icon'],
                        size: 16,
                        color: isSelected
                            ? AppColors.accentInk
                            : AppColors.textHint,
                      ),
                      SizedBox(width: 12),
                      Text(
                        item['label'],
                        style: GoogleFonts.poppins(
                          color: isSelected
                              ? AppColors.secondaryVariant
                              : AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        children: [
          // Search bar (scrollable)
          _buildSearchBar(),
          // Section Sombre (Haut)
          Container(
            color: Colors.transparent,
            width: double.infinity,
            padding: const EdgeInsets.only(top: 8, bottom: 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_selectedSection == "Tout") ...[
                  SizedBox(height: 16),
                  if (_stats != null) _buildQuickStats(),
                  // Reprendre passe avant encourager.
                  //
                  // Quand une lecture est en cours, c'est elle qui occupe cette
                  // place : le lecteur qui revient veut rouvrir son livre, pas
                  // lire un pourcentage. L'objectif quotidien reste en repli —
                  // le retirer tout à fait le ferait disparaître de l'accueil
                  // pour un compte neuf, c'est-à-dire précisément pour celui à
                  // qui il s'adresse, et laisserait la visite guidée sans cible
                  // à sa deuxième étape.
                  if (_lectureEnCours != null) ...[
                    SizedBox(height: 16),
                    Container(
                      key: _dailyGoalKey,
                      child: ContinuerLecture(
                        livre: _lectureEnCours!.livre!,
                        onReprendre: () => _reprendre(_lectureEnCours!),
                        onEcouter: () => _ecouter(_lectureEnCours!.livre!),
                        // `estLeLivre` est indispensable : le service est
                        // unique et `enLecture` est global.
                        enEcoute:
                            _audio.estLeLivre(_lectureEnCours!.livre!.id) &&
                            _audio.enLecture,
                        enPreparation:
                            _audio.estLeLivre(_lectureEnCours!.livre!.id) &&
                            _audio.preparation,
                      ),
                    ),
                  ] else if (_dailyGoal != null) ...[
                    SizedBox(height: 16),
                    GestureDetector(
                      key: _dailyGoalKey,
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                BadgesPage(userId: widget.profileId),
                          ),
                        );
                        _loadData();
                      },
                      child: DailyGoalSection(goal: _dailyGoal),
                    ),
                  ],
                  SizedBox(height: 20),
                ],

                // Nouveautés
                if (_selectedSection == "Tout" ||
                    _selectedSection == "Nouveautés") ...[
                  Container(
                    key: _featuredBooksKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Nouveautés",
                                style: AppTextStyles.sectionTitle,
                              ),
                              GestureDetector(
                                onTap: () {
                                  MainNavBar.mainNavBarKey.currentState
                                      ?.navigateToMarketplace();
                                },
                                child: Text(
                                  "Voir plus",
                                  style: AppTextStyles.link,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 16),
                        _buildFeaturedHorizontalList(),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),
                ],

                // Catégories (Persistent or only in section?)
                // Usually better to keep categories only when book sections are shown
                if (_selectedSection == "Tout" ||
                    _selectedSection == "Nouveautés" ||
                    _selectedSection == "Recommandations") ...[
                  _buildCategoryPills(),
                  SizedBox(height: 18),
                ],

                // Recommandations pour vous
                if (_selectedSection == "Tout" ||
                    _selectedSection == "Recommandations") ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Recommandations",
                          style: AppTextStyles.sectionTitle,
                        ),
                        TextButton(
                          onPressed: () {
                            MainNavBar.mainNavBarKey.currentState
                                ?.navigateToMarketplace();
                          },
                          child: Text(
                            "Voir plus",
                            style: AppTextStyles.linkBold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 12),
                  _buildRecommendationsGrid(),
                  if (_selectedSection == "Tout") SizedBox(height: 20),
                ],
              ],
            ),
          ),

          // Section Basse
          if (_selectedSection == "Tout" ||
              _selectedSection == "Auteurs" ||
              _selectedSection == "Forum")
            Container(
              color: Colors.transparent,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Auteurs
                  if (_selectedSection == "Tout" ||
                      _selectedSection == "Auteurs") ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Auteurs", style: AppTextStyles.sectionTitle),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const AllAuthorsPage(),
                                ),
                              );
                            },
                            child: Text(
                              "Voir plus",
                              style: AppTextStyles.linkBold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 12),
                    _buildAuthorsList(),
                    SizedBox(height: 20),
                  ],

                  // Clubs / Forum
                  if (_selectedSection == "Tout" ||
                      _selectedSection == "Forum") ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _discussions.isNotEmpty
                                ? "Forums (${_discussions.length})"
                                : "Forums",
                            style: AppTextStyles.sectionTitle,
                          ),
                          TextButton(
                            onPressed: () {
                              MainNavBar.mainNavBarKey.currentState
                                  ?.navigateToCommunaute();
                            },
                            child: Text(
                              "Voir plus",
                              style: AppTextStyles.linkBold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 12),
                    _buildClubsList(),
                    SizedBox(height: 20),
                  ],

                  // Citations (toujours à la fin si mode Tout)
                  if (_selectedSection == "Tout") ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        "Citations",
                        style: AppTextStyles.sectionTitle,
                      ),
                    ),
                    SizedBox(height: 12),
                    _buildQuotesList(),
                    SizedBox(height: 20),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  // Helpers UI du nouveau design

  /// Largeur d'une carte de livre sur l'accueil.
  ///
  /// Reprise de la boutique : deux colonnes sur un ecran ordinaire y donnent
  /// environ cette largeur, si bien qu'un meme ouvrage a la meme taille d'un
  /// ecran a l'autre.
  static const double _largeurCarte = 160;

  Widget _buildFeaturedHorizontalList() {
    List<BookModel> displayBooks = [];
    if (_featuredBooks.isNotEmpty) {
      displayBooks = _featuredBooks;
    } else if (_allBooks.isNotEmpty) {
      displayBooks = _allBooks;
    }

    if (displayBooks.isEmpty) {
      return SizedBox(height: LivreCard.hauteurPour(_largeurCarte));
    }

    // Meme carte qu'en boutique, donc meme hauteur.
    //
    // Elle etait posee dans une bande de 250 px : la couverture y tenait ce
    // qu'elle pouvait et le texte debordait par le bas, sans que rien ne le
    // signale a la compilation. La hauteur se demande maintenant a la carte
    // elle-meme, qui seule connait ses proportions.
    return SizedBox(
      height: LivreCard.hauteurPour(_largeurCarte),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: displayBooks.length,
        itemBuilder: (context, index) {
          final book = displayBooks[index];
          return Padding(
            padding: const EdgeInsets.only(right: 14),
            child: SizedBox(
              width: _largeurCarte,
              child: LivreCard(
                book: book,
                isOwned: _ownedBookIds.contains(book.id),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCategoryPills() {
    final List<BookModel> pool = _recommendations.isNotEmpty
        ? _recommendations
        : _allBooks;

    // Get names of categories that actually contain books
    final Set<String> activeCategoryNames = pool
        .map((b) => b.categorie?.nom)
        .whereType<String>()
        .map((name) => name.trim())
        .toSet();

    final List<String> categories = ["Tous"];
    if (_categories.isNotEmpty) {
      categories.addAll(
        _categories
            .map((c) => c.nom)
            .where((name) => activeCategoryNames.contains(name.trim()))
            .toList(),
      );
    } else if (pool.isNotEmpty) {
      categories.addAll(activeCategoryNames.toList());
    }

    if (categories.length <= 1 && pool.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 36,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final catName = categories[index];
          final isSelected = _selectedCategory == catName;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedCategory = catName;
              });
            },
            child: Container(
              margin: const EdgeInsets.only(right: 10),
              padding: EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.secondary
                    : AppColors.cardBackground,
                borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
                border: Border.all(
                  color: isSelected ? AppColors.accentInk : AppColors.textHint,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                catName,
                style: GoogleFonts.poppins(
                  color: isSelected
                      ? AppColors.onAccent
                      : AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecommendationsGrid() {
    List<BookModel> displayBooks = [];

    if (_recommendations.isNotEmpty) {
      displayBooks = _recommendations;
    } else if (_allBooks.isNotEmpty) {
      displayBooks = List.from(_allBooks);
    }

    // Filter by category locally
    if (_selectedCategory != "Tous") {
      displayBooks = displayBooks.where((book) {
        // Try to match by category name
        final bookCategory = book.categorie?.nom;
        return bookCategory != null &&
            bookCategory.toLowerCase() == _selectedCategory.toLowerCase();
      }).toList();
    }

    if (displayBooks.isEmpty) {
      return const SizedBox.shrink();
    }

    // Meme carte qu'en boutique, donc meme hauteur.
    //
    // Elle etait posee dans une bande de 250 px : la couverture y tenait ce
    // qu'elle pouvait et le texte debordait par le bas, sans que rien ne le
    // signale a la compilation. La hauteur se demande maintenant a la carte
    // elle-meme, qui seule connait ses proportions.
    return SizedBox(
      height: LivreCard.hauteurPour(_largeurCarte),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: displayBooks.length,
        itemBuilder: (context, index) {
          final book = displayBooks[index];
          return Padding(
            padding: const EdgeInsets.only(right: 14),
            child: SizedBox(
              width: _largeurCarte,
              child: LivreCard(
                book: book,
                isOwned: _ownedBookIds.contains(book.id),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Une section en panne se dit comme telle — jamais comme un vide, et
  /// jamais avec du contenu inventé pour « faire plein ».
  Widget _sectionEnPanne(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, size: 18, color: AppColors.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.poppins(
                color: AppColors.textSecondary,
                fontSize: 12.5,
              ),
            ),
          ),
          TextButton(
            onPressed: _loadData,
            child: Text(
              "Réessayer",
              style: GoogleFonts.poppins(
                color: AppColors.accentInk,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Un vide réel, dit honnêtement.
  Widget _sectionVide(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        message,
        style: GoogleFonts.poppins(
          color: AppColors.textSecondary,
          fontSize: 12.5,
        ),
      ),
    );
  }

  Widget _buildAuthorsList() {
    // Les quatre auteurs de démonstration (« Marie Dubois », « Thomas
    // Leroy »...) qui comblaient ce vide sont partis : un nom inventé sous un
    // bouton « + Suivre » n'est pas un état d'attente, c'est un mensonge que
    // le lecteur prenait pour la communauté réelle. Une panne s'affiche comme
    // une panne, un vide comme un vide.
    if (_featuredAuthors.isEmpty) {
      return _livresEnPanne
          ? _sectionEnPanne("Impossible de charger les auteurs.")
          : _sectionVide("Aucun auteur à découvrir pour le moment.");
    }

    return SizedBox(
      height: 135, // Adjust for fitting content comfortably
      child: ListView.builder(
        physics: const ClampingScrollPhysics(),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _featuredAuthors.length,
        itemBuilder: (context, index) {
          final author = _featuredAuthors[index];
          final authorName = author.nomComplet;
          final estSuivi = _followingIds.contains(author.id);

          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AuthorProfilePage(
                    author: author,
                    initialIsFollowing: estSuivi,
                  ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.only(right: 20),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: AppColors.secondary.withOpacity(0.15),
                    child: Text(
                      authorName.isNotEmpty
                          ? authorName.substring(0, 1).toUpperCase()
                          : "?",
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        color: AppColors.accentInk,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    authorName,
                    style: GoogleFonts.poppins(
                      color: AppColors.textPrimary, // Changé de black87
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 8),
                  GestureDetector(
                    onTap: () {
                      if (estSuivi) {
                        _showAlreadyFollowingDialog(authorName);
                      } else {
                        _followAuthor(author.id, authorName);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: estSuivi
                            ? AppColors.textHint
                            : AppColors.secondary, // Blue pill
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusCard,
                        ),
                        border: estSuivi
                            ? Border.all(color: AppColors.textHint)
                            : null,
                      ),
                      child: Text(
                        estSuivi ? "Suivi" : "+ Suivre",
                        style: GoogleFonts.poppins(
                          color: estSuivi
                              ? AppColors.textSecondary
                              : Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _followAuthor(String authorId, String authorName) async {
    if (_followingIds.contains(authorId)) return;
    try {
      final token = await TokenStorage.getToken();
      // Sans jeton, l'appui sur « Suivre » ne produisait RIEN : pas de
      // requête, pas de message, pas de changement de bouton. Une session
      // finie se dit, sinon la personne réappuie en croyant avoir mal visé.
      if (token == null) {
        if (!mounted) return;
        AppNotifications.showSnackBar(
          context,
          message:
              "Votre session a expiré. Reconnectez-vous pour suivre "
              "cet auteur.",
          isError: true,
        );
        return;
      }

      // Anti-self following
      if (authorId == _currentUserId) {
        if (mounted) {
          AppNotifications.showSnackBar(
            context,
            message: "Vous ne pouvez pas vous suivre vous-même",
            isError: true,
          );
        }
        return;
      }

      await _relationService.followUser(authorId, token);
      if (mounted) {
        setState(() {
          _followingIds.add(authorId);
        });
        AppNotifications.showSnackBar(context, message: '$authorName suivi !');
      }
    } catch (e) {
      final errorStr = e.toString();
      if (errorStr.contains("409") || errorStr.contains("déjà existante")) {
        // If it's a conflict (already following), update local state and show dialog
        if (mounted) {
          setState(() {
            _followingIds.add(authorId);
          });
          _showAlreadyFollowingDialog(authorName);
        }
      } else {
        if (mounted) {
          AppNotifications.showSnackBar(
            context,
            // `errorStr` sert juste au-dessus à reconnaître un 409 : c'est du
            // routage, pas de l'affichage. Le montrer tel quel laissait passer
            // « Failed to follow user: 500 - {...} », que RelationService
            // compose avec le code HTTP et le corps de la réponse.
            message: messageLisible(
              e,
              repli: "Impossible de suivre cet auteur.",
            ),
            isError: true,
          );
        }
      }
    }
  }

  void _showAlreadyFollowingDialog(String authorName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: Text(
          "Déjà suivi",
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          "Vous suivez déjà $authorName. Vous recevrez des notifications pour ses prochaines publications.",
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("OK", style: TextStyle(color: AppColors.accentInk)),
          ),
        ],
      ),
    );
  }

  Widget _buildClubsList() {
    // Les trois forums de démonstration (« Science-fiction & Futurs — 12
    // messages »...) qui comblaient ce vide sont partis : des compteurs
    // inventés sous un bouton « Rejoindre » faisaient passer une panne pour
    // une communauté active.
    if (_discussions.isEmpty) {
      return _forumsEnPanne
          ? _sectionEnPanne("Impossible de charger les forums.")
          : _sectionVide("Aucune discussion pour le moment.");
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: _discussions.take(3).map((d) {
          final club = {
            "title": d.titre.isNotEmpty
                ? d.titre
                : "Discussion #${d.id.substring(0, 4)}",
            "members": (d.messagesCount ?? 0) > 0
                ? "${d.messagesCount} message${d.messagesCount! > 1 ? 's' : ''}"
                : "${d.messages.length} message${d.messages.length > 1 ? 's' : ''}",
            "icon": Icons.public,
            "color": AppColors.scaffoldBackground,
            "button": true,
          };
          return _buildClubItem(club, discussion: d);
        }).toList(),
      ),
    );
  }

  Widget _buildClubItem(Map<String, dynamic> club, {Discussion? discussion}) {
    return GestureDetector(
      onTap: () {
        if (discussion != null) {
          MainNavBar.mainNavBarKey.currentState?.navigateToCommunaute();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ForumMessagesPage(discussion: discussion),
            ),
          );
        } else {
          MainNavBar.mainNavBarKey.currentState?.navigateToCommunaute();
        }
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: club["color"] as Color,
                borderRadius: BorderRadius.circular(AppDimensions.radiusInner),
              ),
              child: Icon(
                club["icon"] as IconData,
                color: AppColors.textPrimary,
                size: 24,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(club["title"] as String, style: AppTextStyles.cardTitle),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        (club["members"] as String).toLowerCase().contains(
                              "message",
                            )
                            ? Iconsax.message
                            : Icons.person_outline,
                        color: AppColors.textSecondary,
                        size: 11,
                      ),
                      SizedBox(width: 4),
                      Text(
                        club["members"] as String,
                        style: AppTextStyles.grey12,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (club["button"] == true)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.joinBadgeBg,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
                ),
                child: Text(
                  "Rejoindre",
                  style: GoogleFonts.poppins(
                    color: AppColors.joinBadgeText,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuotesList() {
    List<Map<String, dynamic>> quotes = [];

    // Ajouter la citation API dynamique s'il y en a une
    if (_dailyCitation != null && _dailyCitation!.texte.isNotEmpty) {
      quotes.add({
        "quote": _dailyCitation!.texte,
        "author": _dailyCitation!.auteur,
        "bookTitle": _dailyCitation!.livreTitre ?? "",
        "gradient": [AppColors.primary, AppColors.primaryDark],
        "book": null,
        "note": 5,
      });
    }

    if (_recentActivities.isNotEmpty &&
        _recentActivities.any((r) => r.commentaire.isNotEmpty)) {
      final validReviews = _recentActivities
          .where((r) => r.commentaire.isNotEmpty)
          .toList();
      final colors = [
        [AppColors.slateLight, AppColors.slate],
        [AppColors.orange, AppColors.orangeDark],
        [AppColors.primary, AppColors.primaryDark],
      ];

      final reviewQuotes = validReviews.map((r) {
        final idx = validReviews.indexOf(r) % colors.length;
        String author = "Membre SpaceLearn";

        if (r.nomUtilisateur != null && r.nomUtilisateur!.isNotEmpty) {
          author = r.nomUtilisateur!;
        } else if (r.utilisateur != null && r.utilisateur!.libelle.isNotEmpty) {
          author = r.utilisateur!.libelle;
        } else if (r.livre != null) {
          author = "Avis sur ${r.livre!.titre}";
        }

        return {
          "quote": "“${r.commentaire}”",
          "author": author,
          "bookTitle": r.livre?.titre ?? "",
          "gradient": colors[idx],
          "book": r.livre,
          "note": r.note,
        };
      }).toList();

      quotes.addAll(reviewQuotes);
    }

    // Plus de citations de démonstration attribuées à « Chloé B. » ou
    // « Marc D. » : des membres inventés notant des livres qu'ils n'ont pas
    // lus faisaient passer une panne (ou un simple vide) pour de l'activité
    // réelle.
    if (quotes.isEmpty) {
      // La section se nourrit de DEUX appels : la citation du jour et les
      // avis. Il suffit que l'un d'eux ait échoué pour que le vide affiché ne
      // soit pas un vrai vide.
      return (_avisEnPanne || _citationEnPanne)
          ? _sectionEnPanne("Impossible de charger les citations.")
          : _sectionVide("Aucune citation pour le moment.");
    }

    return SizedBox(
      height: 210,
      child: ListView.builder(
        physics: const ClampingScrollPhysics(),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: quotes.length,
        itemBuilder: (context, index) {
          final q = quotes[index];
          return GestureDetector(
            onTap: () {
              if (q["book"] != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BookDetailPage(
                      book: q["book"] as BookModel,
                      isOwned: _ownedBookIds.contains(
                        (q["book"] as BookModel).id,
                      ),
                    ),
                  ),
                );
              }
            },
            child: Container(
              width: 220,
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: q["gradient"] as List<Color>,
                ),
              ),
              // Toute l'encre de cette carte appartient a l'APLAT, pas a la
              // page.
              //
              // Elle utilisait AppColors.textPrimary, textSecondary et
              // textHint — trois couleurs qui suivent le fond de la PAGE. Or
              // la carte a son propre fond, un degrade orange ou ardoise. En
              // theme clair l'encre sombre passait par chance sur l'orange et
              // mal sur l'ardoise ; en theme sombre elle devient claire, et
              // toute la carte s'efface.  est la seule encre garantie
              // sur la gamme d'accent, dans les deux themes.
              //
              // Le test de coherence des couleurs porte deja cette regle, mais
              // il ne voit que  et  : ici le fond est
              // un degrade construit depuis une liste de donnees, invisible a
              // une lecture du source.
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: List.generate(5, (starIndex) {
                          final acquise = starIndex < (q["note"] as int? ?? 0);
                          return Icon(
                            acquise ? Icons.star : Icons.star_border,
                            // Une etoile non acquise s'efface sans changer de
                            // teinte : deux couleurs differentes sur un aplat
                            // colore font une troisieme couleur a l'oeil.
                            color: AppColors.onAccent.withValues(
                              alpha: acquise ? 1 : 0.45,
                            ),
                            size: 14,
                          );
                        }),
                      ),
                      Icon(
                        Icons.format_quote,
                        color: AppColors.onAccent.withValues(alpha: 0.45),
                        size: 24,
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Expanded(
                    child: Center(
                      child: Text(
                        q["quote"] as String,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.lora(
                          color: AppColors.onAccent,
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ),
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: AppColors.onAccent.withValues(
                          alpha: 0.25,
                        ),
                        child: Icon(
                          Icons.person,
                          size: 14,
                          color: AppColors.onAccent,
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              q["author"] as String,
                              style: GoogleFonts.poppins(
                                color: AppColors.onAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (q["book"] != null)
                              Text(
                                "Livre: ${(q["book"] as BookModel).titre}",
                                style: GoogleFonts.poppins(
                                  color: AppColors.onAccent.withValues(
                                    alpha: 0.75,
                                  ),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuickStats() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          border: Border.all(color: AppColors.textPrimary.withOpacity(0.05)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(
              "${_stats!.booksRead}",
              "Livres lus",
              Icons.auto_stories,
              onTap: () {
                MainNavBar.mainNavBarKey.currentState?.navigateToBibliotheque();
              },
            ),
            _buildStatSeparator(),
            _buildStatItem(
              _stats!.totalTime,
              "Temps total",
              Icons.timer,
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        TempsLecturePage(userId: widget.profileId),
                  ),
                );
                _loadData();
              },
            ),
            _buildStatSeparator(),
            // La série de jours, à la place d'un décompte d'objectifs.
            //
            // Cette tuile affichait `max(objectifs terminés, badges débloqués)`
            // sous l'étiquette « Objectifs » : deux grandeurs sans rapport,
            // réunies par une comparaison. Et depuis que les paliers ouvrent
            // toujours la marche suivante, aucun objectif n'est jamais
            // « terminé » — le maximum ne pouvait plus retenir que les badges.
            //
            // La série dit quelque chose qu'aucune des deux autres tuiles ne
            // dit : elle change chaque jour, et c'est la seule qu'on puisse
            // perdre. C'est ce qui donne une raison de revenir demain.
            _buildStatItem(
              "$_serieJours",
              _serieJours > 1 ? "Jours d'affilée" : "Jour d'affilée",
              _serieJours > 0
                  ? Icons.local_fire_department
                  : Icons.local_fire_department_outlined,
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BadgesPage(userId: widget.profileId),
                  ),
                );
                _loadData();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    String value,
    String label,
    IconData icon, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Icon(icon, color: AppColors.accentInk, size: 20),
          SizedBox(height: 8),
          Text(value, style: AppTextStyles.subtitle),
          Text(label, style: AppTextStyles.grey11),
        ],
      ),
    );
  }

  Widget _buildStatSeparator() {
    return Container(
      height: 40,
      width: 1,
      color: AppColors.textPrimary.withOpacity(0.1),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
            SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: AppColors.textPrimary),
            ),
            SizedBox(height: 20),
            // Un bouton qui peut aboutir, ou pas de bouton du tout.
            //
            // « Réessayer » s'affichait sous toutes les erreurs, session
            // expirée comprise. Or un jeton mort le reste : appuyer relançait
            // les mêmes requêtes, qui échouaient de la même façon, aussi
            // longtemps que la personne insistait. Le seul geste utile est de
            // se reconnecter — alors c'est celui-là qu'on propose.
            _sessionExpiree
                ? ElevatedButton(
                    onPressed: _seReconnecter,
                    child: const Text("Se reconnecter"),
                  )
                : ElevatedButton(
                    onPressed: _loadData,
                    child: const Text("Réessayer"),
                  ),
          ],
        ),
      ),
    );
  }

  /// Termine la session et ramène à l'écran de connexion.
  ///
  /// Le nettoyage passe par [SessionService] : effacer le seul jeton laisserait
  /// sur l'appareil la bibliothèque téléchargée et le profil choisi.
  Future<void> _seReconnecter() async {
    await SessionService.terminer();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  Widget _buildSearchResults() {
    if (_rechercheEnCours) {
      return Center(
        child: Text(
          "Recherche en cours...",
          style: GoogleFonts.poppins(color: AppColors.textSecondary),
        ),
      );
    }

    // Une panne n'est pas « aucun résultat » : elle se dit, et se rejoue.
    if (_erreurRecherche != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: AppColors.error,
              ),
              SizedBox(height: 16),
              Text(
                _erreurRecherche!,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(color: AppColors.textPrimary),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                // Directement, sans repasser par l'anti-rebond : la personne
                // vient d'appuyer, il n'y a pas de frappe à attendre.
                onPressed: () => _rechercherSurLeServeur(_searchQuery),
                child: const Text("Réessayer"),
              ),
            ],
          ),
        ),
      );
    }

    // En dessous de deux caractères, la recherche n'est pas partie (contrat
    // serveur) : on invite à continuer, on n'affirme pas « aucun résultat ».
    if (_searchQuery.trim().length < 2) {
      return Center(
        child: Text(
          "Saisissez au moins deux caractères.",
          style: AppTextStyles.greyMedium14,
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Iconsax.search_status,
              size: 64,
              color: AppColors.textPrimary.withOpacity(0.1),
            ),
            SizedBox(height: 16),
            Text(
              "Aucun résultat trouvé pour \"$_searchQuery\"",
              style: AppTextStyles.greyMedium14,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final book = _searchResults[index];
        return _buildSearchResultCard(book);
      },
    );
  }

  /// Le lecteur possède-t-il ce livre — ou en est-il l'auteur ?
  ///
  /// [_ownedBookIds] est figé par [_loadData] : il réunit la bibliothèque
  /// (complète) et les livres de l'utilisateur trouvés dans `_allBooks`,
  /// c'est-à-dire la PREMIÈRE page du catalogue. Depuis que la recherche
  /// interroge le serveur, un résultat peut venir de n'importe quelle page :
  /// un auteur cherchant son propre livre publié au-delà des cent premiers le
  /// voyait proposé à l'achat, bouton d'achat compris. La possession par
  /// paternité se reteste donc sur le livre lui-même, d'où qu'il vienne — sur
  /// les IDENTIFIANTS seulement, comme aux lignes qui remplissent l'ensemble,
  /// pour ne pas marquer « possédés » les livres d'un auteur homonyme.
  bool _estAcquis(BookModel book) {
    if (_ownedBookIds.contains(book.id)) return true;
    if (_currentUserId == null) return false;
    return (book.auteurId.isNotEmpty && book.auteurId == _currentUserId) ||
        (book.auteur != null && book.auteur!.id == _currentUserId);
  }

  Widget _buildSearchResultCard(BookModel book) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                BookDetailPage(book: book, isOwned: _estAcquis(book)),
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          border: Border.all(color: AppColors.textPrimary.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 70,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
                color: AppColors.textHint,
              ),
              child:
                  book.imageCouverture != null &&
                      book.imageCouverture!.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusSmall,
                      ),
                      child: Image.network(
                        book.imageCouverture!,
                        fit: BoxFit.cover,
                      ),
                    )
                  : Icon(Icons.book, color: AppColors.textHint, size: 20),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.titre,
                    style: AppTextStyles.button14,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text("Par ${book.authorName}", style: AppTextStyles.link12),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }
}
