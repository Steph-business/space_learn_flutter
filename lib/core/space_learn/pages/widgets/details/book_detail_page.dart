import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/utils/app_notifications.dart';
import 'package:space_learn_flutter/core/themes/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:space_learn_flutter/core/themes/app_dimensions.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/book_model.dart';
import 'package:iconsax/iconsax.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/bookService.dart';
import 'reading_page.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/paymentService.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/cinetpay_webview_page.dart';
import 'package:space_learn_flutter/core/services/book_cache_service.dart';
import 'package:space_learn_flutter/core/services/session_service.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/auth/login.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/review_model.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/review_service.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/favoriteService.dart';
import 'package:space_learn_flutter/core/utils/token_storage.dart';
import 'package:intl/intl.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/readingProgressService.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/readingActivityModel.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/libraryService.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/library_model.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/chapitre_service.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/chapitre_model.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/partageService.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/authServices.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/user_model.dart';
import 'all_reviews_page.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/ecrivain/ajouter_livre_page.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/ecrivain/statistiques_livre_page.dart';
import 'package:space_learn_flutter/core/utils/message_erreur.dart';

class BookDetailPage extends StatefulWidget {
  final BookModel book;
  final bool isOwned;

  /// Celui qui regarde peut-il acheter cet ouvrage ?
  ///
  /// Faux quand un auteur consulte son propre livre depuis ses publications.
  /// Le drapeau s'appelait `showCart` : il commandait l'affichage du panier,
  /// lequel n'existe plus. Son nom decrivait un bouton, pas une regle.
  final bool peutAcheter;

  const BookDetailPage({
    super.key,
    required this.book,
    this.isOwned = false,
    this.peutAcheter = true,
  });

  @override
  State<BookDetailPage> createState() => _BookDetailPageState();
}

class _BookDetailPageState extends State<BookDetailPage> {
  final BookService _bookService = BookService();
  List<BookModel> _authorBooks = [];
  List<BookModel> _categoryBooks = [];
  bool _isLoadingRelated = true;

  /// Ce qui a empêché chaque bloc de recommandations d'arriver.
  ///
  /// Deux champs et non un : les deux listes viennent de deux routes
  /// distinctes, et l'échec de l'une ne dit rien de l'autre. Une seule panne
  /// partagée aurait fait disparaître les deux sections pour un seul incident.
  String? _erreurLivresAuteur;
  String? _erreurLivresCategorie;

  /// Un « Réessayer » sans retour visible se fait appuyer trois fois : tant que
  /// la nouvelle tentative court, le bouton le dit et ne se laisse pas
  /// relancer.
  bool _rechargementLivresAuteur = false;
  bool _rechargementLivresCategorie = false;

  bool _isFavorite = false;
  bool _isLoadingFavorite = true;
  final FavoriteService _favoriteService = FavoriteService();
  final ReviewService _reviewService = ReviewService();
  BookModel? _fullBook;
  List<ReviewModel> _reviews = [];
  bool _isLoadingReviews = true;
  final LibraryService _libraryService = LibraryService();
  bool _isOwned = false;
  bool _isAuthorOfThisBook = false;
  UserModel? _currentUser;
  bool _acquisitionEnCours = false;
  bool _paiementEnCours = false;
  bool _isDescriptionExpanded = false;

  /// Un livre a prix nul.
  bool get _estGratuit => (_fullBook ?? widget.book).prix <= 0;
  bool _isLoadingOwnership = true;

  /// La vérification de possession a ÉCHOUÉ — ce qui n'est pas « pas possédé ».
  ///
  /// Avant ce drapeau, un échec réseau de `_checkOwnershipStatus` laissait
  /// `_isOwned` à sa valeur d'entrée (souvent false en arrivant par la
  /// recherche) : un acheteur voyait « Acheter » sur son propre livre et tous
  /// les chapitres verrouillés, sans aucun signal qu'une vérification avait
  /// échoué. Une panne ne doit jamais s'afficher comme une certitude.
  bool _verificationPossessionImpossible = false;

  /// La vérification a échoué parce que la SESSION est finie.
  ///
  /// Une session expirée n'est pas une panne de réseau : « Réessayer » y est un
  /// bouton qui, par construction, ne peut jamais aboutir. On le dit tel quel
  /// et on ramène à la connexion.
  bool _sessionExpiree = false;

  /// On IGNORE si le lecteur possède ce livre — ce qui n'est pas « il ne le
  /// possède pas ».
  ///
  /// La barre du bas respectait déjà ce doute, mais la liste des chapitres
  /// affirmait le contraire dans le même écran : « Contenu verrouillé - Achetez
  /// le livre », et un appui lançait le paiement. L'écran refusait donc de
  /// vendre en bas tout en proposant d'acheter au milieu — soit exactement le
  /// « faire repayer son propre livre » que le drapeau voulait empêcher.
  bool get _possessionIncertaine =>
      _verificationPossessionImpossible && !_isOwned;

  /// Ce qu'un chapitre non lisible doit dire — et il ne doit pas mentir.
  String get _texteChapitreVerrouille => _possessionIncertaine
      ? (_sessionExpiree
            ? "Votre session a expiré — reconnectez-vous pour accéder à ce livre."
            : "Vérification de votre bibliothèque impossible — appuyez pour réessayer.")
      : "Contenu verrouillé - Achetez le livre pour lire la suite.";

  /// La réponse à un appui quand la possession est incertaine : relancer la
  /// vérification, ou dire que la session est finie. Jamais ouvrir un paiement.
  void _traiterAppuiPossessionIncertaine() {
    if (_sessionExpiree) {
      AppNotifications.showSnackBar(
        context,
        message:
            "Votre session a expiré. Reconnectez-vous pour accéder à ce livre.",
        isError: true,
      );
      return;
    }
    _reessayerVerificationPossession();
  }

  /// Fin de session complète, puis retour à l'écran de connexion.
  ///
  /// [SessionService.terminer] est le point de nettoyage UNIQUE : effacer le
  /// seul jeton laisserait au compte suivant le cache et les préférences du
  /// précédent.
  Future<void> _seReconnecter() async {
    await SessionService.terminer();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  String _getAuthorDisplayName(BookModel book) {
    if (book.authorName.isNotEmpty && book.authorName != 'Auteur inconnu') {
      return book.authorName;
    }
    if (_isAuthorOfThisBook &&
        _currentUser != null &&
        _currentUser!.nomComplet.isNotEmpty) {
      return _currentUser!.nomComplet;
    }
    return book.authorName;
  }

  final ReadingProgressService _readingProgressService =
      ReadingProgressService();
  ReadingActivityModel? _readingProgress;
  Set<String> _ownedBookIds = {};

  // Chapitres
  final ChapitreService _chapitreService = ChapitreService();
  List<ChapitreModel> _chapitres = [];

  int get _progressionPourcentage {
    if (_readingProgress != null) {
      return _readingProgress!.pourcentage.round().clamp(0, 100);
    }
    final progressions = (_fullBook ?? widget.book).progressions;
    if (progressions != null && progressions.isNotEmpty) {
      return progressions.first.pourcentage.round().clamp(0, 100);
    }
    return 0;
  }

  /// La moyenne du livre, ou `null` quand il n'y en a pas encore.
  ///
  /// L'ancien calcul retombait sur zéro et l'écrivait tel quel : un ouvrage
  /// compté « 37 avis » mais dont le serveur ne rendait pas de moyenne
  /// s'affichait « 0.0 (37 avis) », cinq étoiles vides — soit un livre
  /// unanimement détesté, alors que la moyenne était simplement absente. Un
  /// VIDE n'est pas un zéro : `null` dit l'absence, l'affichage la nomme.
  double? get _moyenneDesAvis {
    final moyenneServeur = (_fullBook ?? widget.book).noteMoyenne;
    if (moyenneServeur > 0) return moyenneServeur;
    // Faute de moyenne rendue, les avis reçus la donnent : ce sont les notes
    // elles-mêmes, les moyenner n'invente rien.
    if (_reviews.isNotEmpty) {
      final somme = _reviews.fold<int>(0, (total, r) => total + r.note);
      return somme / _reviews.length;
    }
    return null;
  }

  /// La note que CE lecteur a déposée sur ce livre, s'il en a déposé une.
  ///
  /// Elle arrivait autrefois par la bande : la boutique écrasait la
  /// `noteMoyenne` du livre avec elle (`_enrichir`) avant d'ouvrir cette
  /// fiche, qui héritait de l'objet et affichait « 2.0 (37 avis) » — la note
  /// d'une seule personne présentée comme la moyenne de l'ouvrage. La fiche va
  /// désormais la chercher à sa source, dans les avis du livre, et la donne
  /// sous son nom, à côté de la moyenne et jamais à sa place.
  ///
  /// `utilisateur_id` d'un avis est l'identifiant du compte (JWT `user_id`,
  /// avis/model.go), celui-là même que rend `/utilisateurs/me` : la
  /// correspondance est exacte, pas approchée par le nom. Nulle tant que le
  /// profil n'est pas revenu — une absence, jamais une affirmation.
  int? get _noteDuLecteur {
    final moi = _currentUser?.id;
    if (moi == null || moi.isEmpty) return null;
    for (final avis in _reviews) {
      if (avis.utilisateurId == moi) return avis.note;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _isOwned = widget.isOwned;
    if (widget.book.progressions != null &&
        widget.book.progressions!.isNotEmpty) {
      _readingProgress = widget.book.progressions!.first;
    }
    _loadFullBookDetails();
    _loadRelatedBooks();
    _checkFavoriteStatus();
    _loadReviews();
    _checkOwnershipStatus();
    _loadChapitres();
  }

  Future<void> _loadFullBookDetails() async {
    try {
      final token = await TokenStorage.getToken();
      final fullBook = await _bookService.getBookById(
        widget.book.id,
        authToken: token,
      );
      if (mounted) {
        setState(() {
          _fullBook = fullBook;
          if (fullBook.progressions != null &&
              fullBook.progressions!.isNotEmpty) {
            _readingProgress = fullBook.progressions!.first;
          }
        });
        await _checkOwnershipStatus();
      }
    } catch (e) {}
  }

  Future<void> _checkOwnershipStatus() async {
    try {
      final token = await TokenStorage.getToken();
      if (token != null) {
        final authService = AuthService();
        final user = await authService.getUser(token);
        final currentBook = _fullBook ?? widget.book;

        // « Je suis l'auteur » se décide par IDENTIFIANTS, jamais par nom.
        //
        // La comparaison de `nomComplet` avec `authorName` a été retirée : un
        // lecteur homonyme d'un auteur devenait « propriétaire » du livre —
        // bouton d'achat disparu, chapitres prétendus déverrouillés — alors
        // que le serveur, qui compare les UUID, ne lui livrait que l'extrait.
        final isAuthor =
            user != null &&
            ((currentBook.auteurId.isNotEmpty &&
                    (user.id == currentBook.auteurId ||
                        user.profilId == currentBook.auteurId)) ||
                (currentBook.auteur != null &&
                    (currentBook.auteur!.id == user.id ||
                        currentBook.auteur!.profilId == user.id ||
                        currentBook.auteur!.id == user.profilId)));

        final library = await _libraryService.getUserLibrary(token);
        final found = library.any((item) => item.livreId == widget.book.id);
        LibraryModel? matchingItem;
        try {
          matchingItem = library.firstWhere(
            (item) => item.livreId == widget.book.id,
          );
        } catch (_) {}

        if (mounted) {
          setState(() {
            _currentUser = user;
            _isAuthorOfThisBook = isAuthor;
            _isOwned = _isOwned || isAuthor || found;
            _ownedBookIds = library.map((e) => e.livreId).toSet();
            _isLoadingOwnership = false;
            _verificationPossessionImpossible = false;
            _sessionExpiree = false;
            if (matchingItem?.livre?.progressions != null &&
                matchingItem!.livre!.progressions!.isNotEmpty) {
              _readingProgress = matchingItem.livre!.progressions!.first;
            }
          });
          if (_isOwned) {
            _loadReadingProgress();
          }
        }
      } else {
        // Pas de session : « non possédé » est ici une certitude, pas une panne.
        if (mounted) setState(() => _isLoadingOwnership = false);
      }
    } catch (e) {
      // PANNE ≠ « pas possédé » : on lève un drapeau distinct plutôt que de
      // laisser la fiche affirmer que le lecteur doit acheter le livre.
      //
      // Et une SESSION EXPIRÉE n'est pas une panne : AuthService.getUser rend
      // « Votre session a expiré. Reconnectez-vous. » sur un jeton mort, et
      // offrir « Réessayer » dans ce cas, c'est offrir un bouton qui ne peut
      // pas aboutir. `estSessionExpiree` existe exactement pour cette
      // distinction ; le doute sur la possession, lui, reste entier dans les
      // deux cas — la fiche ne doit toujours pas proposer d'acheter.
      if (mounted) {
        setState(() {
          _isLoadingOwnership = false;
          _verificationPossessionImpossible = true;
          _sessionExpiree = estSessionExpiree(e);
        });
      }
    }
  }

  /// Relance la vérification de possession après une panne.
  Future<void> _reessayerVerificationPossession() async {
    setState(() {
      _isLoadingOwnership = true;
      _verificationPossessionImpossible = false;
      _sessionExpiree = false;
    });
    await _checkOwnershipStatus();
  }

  Future<void> _loadReadingProgress() async {
    try {
      final token = await TokenStorage.getToken();
      if (token != null) {
        final progress = await _readingProgressService.getProgressByLivre(
          widget.book.id,
          token,
        );
        if (progress != null && mounted) {
          setState(() {
            _readingProgress = progress;
          });
        }
      }
    } catch (e) {}
  }

  Future<void> _loadChapitres() async {
    try {
      final chapitres = await _chapitreService.getChapitres(widget.book.id);
      if (mounted) {
        setState(() {
          _chapitres = chapitres;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _checkFavoriteStatus() async {
    try {
      final token = await TokenStorage.getToken();
      if (token != null) {
        final favorites = await _favoriteService.getFavorites(token);
        if (mounted) {
          setState(() {
            _isFavorite = favorites.any((f) => f.livreId == widget.book.id);
            _isLoadingFavorite = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingFavorite = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingFavorite = false);
    }
  }

  Future<void> _toggleFavorite() async {
    try {
      final token = await TokenStorage.getToken();
      if (token == null) {
        if (mounted) {
          AppNotifications.showSnackBar(
            context,
            message: "Veuillez vous connecter pour ajouter à ma favorie",
            isError: true,
          );
        }
        return;
      }

      setState(() => _isLoadingFavorite = true);

      if (_isFavorite) {
        await _favoriteService.removeFavorite(widget.book.id, token);
      } else {
        await _favoriteService.addFavorite(widget.book.id, token);
      }

      if (mounted) {
        setState(() {
          _isFavorite = !_isFavorite;
          _isLoadingFavorite = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingFavorite = false);
    }
  }

  /// Détermine si un extrait gratuit est disponible pour ce livre.
  bool _hasExtraitAvailable(BookModel book) {
    if (_isAuthorOfThisBook || book.prix <= 0) return true;
    if (book.aUnExtrait) return true;
    // Sur le détail d'un livre non possédé, le serveur place l'adresse de
    // l'extrait dans `fichier_url` : une adresse présente veut donc dire qu'il
    // y a quelque chose à lire librement.
    if (book.fichierUrl != null && book.fichierUrl!.isNotEmpty) return true;
    return false;
  }

  /// Dernière page comprise dans l'aperçu gratuit.
  ///
  /// Le serveur dit combien de pages il a découpées. Faute de cette réponse —
  /// un livre publié avant que le champ existe — on retient une valeur basse :
  /// annoncer moins que la réalité déçoit moins qu'annoncer un chapitre qui
  /// s'arrête au milieu.
  int _dernierePageDeLExtrait(BookModel book) {
    if (book.nbPagesExtrait > 0) return book.nbPagesExtrait;
    return 2;
  }

  /// Détermine si un chapitre fait partie de l'extrait gratuit.
  ///
  /// La limite était écrite en dur — page dix — sans rapport avec le fichier
  /// réellement découpé. Sur un livre court dont l'aperçu fait deux pages, la
  /// page annonçait « extrait gratuit » sur quatre chapitres, et le lecteur qui
  /// en ouvrait un tombait sur la fin de l'extrait.
  bool _isChapterInExtrait(
    ChapitreModel ch,
    int index, {
    bool hasExtrait = true,
    required int dernierePage,
  }) {
    if (!hasExtrait) return false;
    if (ch.estGratuit) return true;
    if (ch.pageDepart > 0) {
      return ch.pageDepart <= dernierePage;
    }
    // Sans pagination connue, seul le premier chapitre est présumé lisible.
    return index < 1;
  }

  /// Formate le prix proprement avec espace des milliers pour prévenir tout décalage
  String _formatPrix(int prix) {
    if (prix <= 0) return "Gratuit";
    final str = prix.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write(' ');
      }
      buffer.write(str[i]);
    }
    return "${buffer.toString()} FCFA";
  }

  Future<void> _loadReviews() async {
    try {
      final reviews = await _reviewService.getBookReviews(widget.book.id);
      if (mounted) {
        setState(() {
          _reviews = reviews;
          _isLoadingReviews = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingReviews = false);
    }
  }

  void _showAllChaptersModal(BuildContext context) {
    final isOwned = _isOwned;
    final book = _fullBook ?? widget.book;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        // Une feuille est une route a part : elle lit la palette sans
        // s'y abonner, donc elle garde celle du dernier ecran construit.
        AppColors.suivreLeTheme(context);
        final chaptersList = _chapitres;
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Tous les chapitres",
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    chaptersList.isNotEmpty
                        ? "${chaptersList.length} chapitres"
                        : "",
                    style: GoogleFonts.poppins(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: () {
                  final bool hasExtrait = _hasExtraitAvailable(book);
                  if (chaptersList.isNotEmpty) {
                    return ListView.separated(
                      itemCount: chaptersList.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final ch = chaptersList[index];
                        final isExtraitGratuit =
                            (!isOwned) &&
                            _isChapterInExtrait(
                              ch,
                              index,
                              hasExtrait: hasExtrait,
                              dernierePage: _dernierePageDeLExtrait(book),
                            );
                        final isLocked = !isOwned && !isExtraitGratuit;
                        final numStr = ch.numero < 10
                            ? "0${ch.numero}"
                            : "${ch.numero}";
                        return _buildChapterTile(
                          number: numStr,
                          title: ch.titre,
                          description: ch.description.isNotEmpty
                              ? ch.description
                              : (isLocked
                                    ? _texteChapitreVerrouille
                                    : "Extrait gratuit - Disponible à la lecture."),
                          isLocked: isLocked,
                          onTap: () async {
                            Navigator.pop(context);
                            if (isLocked) {
                              _lancerPaiementDirect(book);
                            } else {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ReadingPage(
                                    book: book.toJson(),
                                    isExtrait: !isOwned,
                                    initialPage: ch.pageDepart > 0
                                        ? ch.pageDepart
                                        : null,
                                  ),
                                ),
                              );
                              if (mounted && _isOwned) {
                                _loadReadingProgress();
                              }
                            }
                          },
                        );
                      },
                    );
                  }
                  // Meme fabrication qu'en page, meme retrait.
                  return ListView(
                    children: [
                      _buildSommaireNonDetaille(
                        book,
                        isOwned,
                        contexteFeuille: context,
                      ),
                    ],
                  );
                }(),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Les deux blocs de recommandations, chargés ENSEMBLE mais indépendants.
  ///
  /// Les deux appels partageaient un seul `Future.wait` et un seul `catch`.
  /// Tant que getBooksByAuthorId rendait `[]` sur échec, seul le bloc « du même
  /// auteur » restait vide ; depuis qu'elle lève, une panne confinée à
  /// /api/books/author/:id faisait rejeter tout le `Future.wait` et effaçait
  /// AUSSI les livres de la même catégorie, qui étaient pourtant arrivés.
  ///
  /// Le `catchError((_) => [])` qui a suivi a décorrélé les deux échecs, mais
  /// il les a rendus MUETS : une panne se présentait comme « cet auteur n'a
  /// rien d'autre » et le bloc disparaissait sans un mot. Chaque section a
  /// donc désormais son try/catch, sa panne affichée et son « Réessayer » —
  /// même geste que _chargerLesLivres / _chargerLesAbonnes dans
  /// author_profile_page.dart.
  Future<void> _loadRelatedBooks() async {
    setState(() {
      _isLoadingRelated = true;
      _erreurLivresAuteur = null;
      _erreurLivresCategorie = null;
    });

    // Les deux méthodes ne lèvent jamais : ce `Future.wait` ne sert qu'à
    // attendre la fin des deux, pas à propager un échec.
    await Future.wait([
      _chargerLivresDeLAuteur(),
      _chargerLivresDeLaCategorie(),
    ]);

    if (!mounted) return;
    setState(() => _isLoadingRelated = false);
  }

  Future<void> _chargerLivresDeLAuteur() async {
    // Sans identifiant d'auteur, la route /api/books/author/ répondrait 404 :
    // ce n'est pas une panne à annoncer, il n'y a simplement rien à demander.
    if (widget.book.auteurId.isEmpty) return;
    try {
      final livres = await _bookService.getBooksByAuthorId(
        widget.book.auteurId,
      );
      if (!mounted) return;
      setState(() {
        // Le livre affiché ne se recommande pas lui-même.
        _authorBooks = livres.where((b) => b.id != widget.book.id).toList();
        // Une tentative qui aboutit efface la panne précédente : sans cela le
        // bandeau d'erreur resterait affiché au-dessus des livres arrivés.
        _erreurLivresAuteur = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erreurLivresAuteur = messageLisible(
          e,
          repli: "Les autres livres de cet auteur n'ont pas pu être chargés.",
        );
      });
    }
  }

  Future<void> _chargerLivresDeLaCategorie() async {
    final categorieId = widget.book.categorieId;
    if (categorieId == null || categorieId.isEmpty) return;
    try {
      final livres = await _bookService.getBooksByCategory(categorieId);
      if (!mounted) return;
      setState(() {
        _categoryBooks = livres.where((b) => b.id != widget.book.id).toList();
        _erreurLivresCategorie = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erreurLivresCategorie = messageLisible(
          e,
          repli: "Les livres similaires n'ont pas pu être chargés.",
        );
      });
    }
  }

  /// Relance UNE section, pas les deux : l'autre appel avait abouti, le
  /// refaire ferait clignoter des livres déjà affichés.
  Future<void> _reessayerLivresAuteur() async {
    setState(() => _rechargementLivresAuteur = true);
    await _chargerLivresDeLAuteur();
    if (!mounted) return;
    setState(() => _rechargementLivresAuteur = false);
  }

  Future<void> _reessayerLivresCategorie() async {
    setState(() => _rechargementLivresCategorie = true);
    await _chargerLivresDeLaCategorie();
    if (!mounted) return;
    setState(() => _rechargementLivresCategorie = false);
  }

  /// Met le livre en vente — la SEULE voie de mise en vente de l'application.
  ///
  /// L'écran de modification y menait aussi, à l'insu de l'auteur : son bouton
  /// « Modifier » réécrivait 'publie' à chaque enregistrement, de sorte qu'un
  /// livre retiré de la vente repartait au catalogue parce qu'on avait corrigé
  /// son résumé — et que tous les abonnés recevaient « Nouveau livre publié ».
  /// Ce formulaire ne touche plus au statut (ajouter_livre_page.dart) : le
  /// geste vit ici, sous un libellé que l'auteur lit avant d'appuyer.
  Future<void> _publierLivre(BuildContext context, BookModel book) async {
    try {
      final token = await TokenStorage.getToken();
      // `context.mounted` et non `mounted` : c'est CE context — celui du menu,
      // reçu en paramètre — qui va servir, et lui seul dit s'il est encore
      // valide après l'attente.
      if (!context.mounted) return;
      if (token == null) {
        // Une session expirée se DIT. Le `return` muet laissait l'auteur
        // devant un menu qui se referme sans rien faire, persuadé d'avoir mis
        // son livre en vente.
        AppNotifications.showSnackBar(
          context,
          message: "Votre session a expiré. Reconnectez-vous pour publier.",
          isError: true,
        );
        return;
      }
      await BookService().updateBook(book.id, {'statut': 'publie'}, token);
      if (!mounted) return;
      // On annonce la CONSÉQUENCE, pas seulement le succès : le serveur
      // prévient tous les abonnés à chaque entrée au catalogue
      // (livre/service.go, Update → notifyFollowers). L'auteur doit le savoir
      // au moment où il appuie, pas en lisant les réactions.
      //
      // Et même lecture que le libellé du menu : une œuvre déjà parue revient
      // en vente, elle ne paraît pas une seconde fois.
      final bool remiseEnVente =
          book.statut.trim().toLowerCase() == 'en_revision' ||
          book.publieLe != null;
      AppNotifications.showSnackBar(
        context,
        message: remiseEnVente
            ? '"${book.titre}" est de nouveau en vente. Vos abonnés en sont informés.'
            : '"${book.titre}" est maintenant en vente. Vos abonnés en sont informés.',
        isSuccess: true,
      );
      // Recharge la fiche plutôt qu'un setState à vide : le menu se décide sur
      // `book.statut`, qui vient de changer côté serveur. Sans cela il
      // proposait encore « Publier » un livre déjà publié, et jamais
      // « Retirer de la vente ».
      await _loadFullBookDetails();
    } catch (e) {
      if (!mounted) return;
      AppNotifications.showSnackBar(
        context,
        message: messageLisible(e, repli: "Impossible de publier ce livre."),
        isError: true,
      );
    }
  }

  /// Retire le livre de la boutique sans toucher à ses acheteurs.
  ///
  /// L'action s'appelait « Archiver » et envoyait {'statut': 'archive'} — un
  /// statut que le serveur n'a jamais accepté (oneof=publie brouillon
  /// en_revision, livre/controller.go) : elle répondait 400 à chaque essai, et
  /// c'était pourtant la seule voie offerte pour retirer un livre vendu.
  /// Retirer de la vente = repasser en 'brouillon' : le livre quitte la
  /// boutique, ceux qui l'ont acheté y gardent accès.
  Future<void> _retirerDeLaVente(BuildContext context, BookModel book) async {
    try {
      final token = await TokenStorage.getToken();
      if (!context.mounted) return;
      if (token == null) {
        // Même règle qu'à la mise en vente : un retrait qui n'a pas eu lieu se
        // dit, sinon l'auteur croit son livre hors boutique alors qu'il s'y
        // vend toujours.
        AppNotifications.showSnackBar(
          context,
          message:
              "Votre session a expiré. Reconnectez-vous pour retirer ce "
              "livre de la vente.",
          isError: true,
        );
        return;
      }
      await BookService().updateBook(book.id, {'statut': 'brouillon'}, token);
      if (!mounted) return;
      AppNotifications.showSnackBar(
        context,
        message:
            '"${book.titre}" a été retiré de la vente. Ses acheteurs y gardent accès.',
        isSuccess: true,
      );
      // Recharge la fiche : le menu se décide sur `book.statut`, qui vient de
      // changer côté serveur — sans cela il proposerait encore le retrait.
      await _loadFullBookDetails();
    } catch (e) {
      if (!mounted) return;
      AppNotifications.showSnackBar(
        context,
        message: messageLisible(
          e,
          repli: "Impossible de retirer ce livre de la vente.",
        ),
        isError: true,
      );
    }
  }

  Future<void> _supprimerLivre(BuildContext context, BookModel book) async {
    // L'ancienne garde bloquait la suppression « si le livre a des acheteurs »
    // en testant `book.telechargements > 0`. Or ce champ est rempli depuis
    // `nombre_avis` (book_model.dart) : le serveur n'envoie AUCUN compte de
    // ventes. Un livre acheté trente fois mais jamais noté passait la garde,
    // et ses acheteurs perdaient l'accès — le serveur supprime sans contrôle.
    // Le nombre d'acheteurs n'existant pas côté client, on ne prétend plus le
    // connaître : avertissement honnête + recopie du titre pour confirmer.
    final saisieTitre = TextEditingController();
    final bool estEnVente = book.statut.toLowerCase() == 'publie';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final titreConfirme =
              saisieTitre.text.trim().toLowerCase() ==
              book.titre.trim().toLowerCase();
          return AlertDialog(
            backgroundColor: AppColors.cardBackground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.warning,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Supprimer définitivement ?',
                    style: GoogleFonts.poppins(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Si des lecteurs ont acheté "${book.titre}", ils en perdront '
                  'définitivement l\'accès : leur bibliothèque ne pourra plus '
                  'l\'ouvrir.\n\n'
                  'Pour retirer le livre de la boutique en préservant ses '
                  'acheteurs, utilisez plutôt « Retirer de la vente ».\n\n'
                  'Pour supprimer malgré tout, recopiez le titre exact du livre :',
                  style: GoogleFonts.poppins(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: saisieTitre,
                  onChanged: (_) => setDialogState(() {}),
                  style: TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: book.titre,
                    hintStyle: TextStyle(
                      color: AppColors.textPrimary.withValues(alpha: 0.4),
                    ),
                    filled: true,
                    fillColor: AppColors.surfaceVariant,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusInner,
                      ),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(
                  'Annuler',
                  style: GoogleFonts.poppins(color: AppColors.textSecondary),
                ),
              ),
              if (estEnVente)
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx, false);
                    _retirerDeLaVente(context, book);
                  },
                  child: Text(
                    'Retirer de la vente',
                    style: GoogleFonts.poppins(
                      color: AppColors.secondaryVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ElevatedButton(
                // Tant que le titre n'est pas recopié, la suppression reste
                // hors de portée : c'est le prix d'une action irréversible.
                onPressed: titreConfirme
                    ? () => Navigator.pop(ctx, true)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  disabledBackgroundColor: AppColors.error.withValues(
                    alpha: 0.3,
                  ),
                ),
                child: Text(
                  'Supprimer',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      final token = await TokenStorage.getToken();
      if (token == null || !mounted) return;
      await BookService().deleteBook(book.id, token);
      if (!mounted) return;
      AppNotifications.showSnackBar(
        context,
        message: '"${book.titre}" supprimé.',
        isSuccess: true,
      );
      Navigator.of(context).pop(true); // Retour à la liste
    } catch (e) {
      if (!mounted) return;
      AppNotifications.showSnackBar(
        context,
        message: messageLisible(e, repli: "Impossible de supprimer ce livre."),
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    AppColors.suivreLeTheme(context);
    final book = _fullBook ?? widget.book;
    final isOwned = _isOwned;

    return Scaffold(
      backgroundColor: AppColors.darkSurface, // Dark slate UI background
      appBar: AppBar(
        backgroundColor: AppColors.darkSurface,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'DÉTAILS DU LIVRE',
          style: AppTextStyles.cardTitle12SemiBold,
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: AppColors.textPrimary,
            size: 18,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.share, color: AppColors.textPrimary, size: 20),
            onPressed: () => PartageService().partagerLivre(
              livreId: book.id,
              titreDeSecours: book.titre,
            ),
          ),
          // Favoris — uniquement pour les lecteurs
          if (widget.peutAcheter)
            IconButton(
              icon: _isLoadingFavorite
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: Padding(
                        padding: EdgeInsets.all(4),
                        child: Text(
                          "...",
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    )
                  : Icon(
                      _isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: _isFavorite ? Colors.red : Colors.white,
                      size: 20,
                    ),
              onPressed: _isLoadingFavorite ? null : _toggleFavorite,
            ),
          // Menu de gestion — uniquement pour l'auteur (!peutAcheter)
          if (!widget.peutAcheter)
            PopupMenuButton<String>(
              color: AppColors.cardBackground,
              padding: EdgeInsets.zero,
              icon: Icon(
                Icons.more_vert,
                color: AppColors.textPrimary,
                size: 22,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusInner),
                side: BorderSide(
                  color: AppColors.textPrimary.withValues(alpha: 0.08),
                ),
              ),
              onSelected: (value) async {
                switch (value) {
                  case 'edit':
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AjouterLivrePage(book: book),
                      ),
                    );
                    if (result == true && mounted) {
                      setState(() {});
                    }
                    break;
                  case 'stats':
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StatistiquesLivrePage(book: book),
                      ),
                    );
                    break;
                  case 'publish':
                    await _publierLivre(context, book);
                    break;
                  case 'retirer':
                    await _retirerDeLaVente(context, book);
                    break;
                  case 'delete':
                    await _supprimerLivre(context, book);
                    break;
                }
              },
              itemBuilder: (context) {
                // Le statut 'archive' n'existe pas côté serveur (oneof=publie
                // brouillon en_revision) : le menu testait un état impossible.
                // La seule question est : le livre est-il en vente ?
                final statut = book.statut.trim().toLowerCase();
                final isPublished = statut == 'publie';
                // « Publier » laissait croire à une PREMIÈRE parution. Or
                // cette entrée s'affiche aussi pour un livre archivé depuis le
                // site ('en_revision') ou retiré de la vente depuis ce menu :
                // dans ces cas, l'auteur remet en vente une œuvre déjà parue —
                // le serveur lui garde d'ailleurs sa date de parution
                // d'origine (livre/service.go). `publieLe` est renseigné dès
                // la première mise en vente : il dit exactement cela.
                final dejaParu =
                    statut == 'en_revision' || book.publieLe != null;
                return [
                  PopupMenuItem(
                    value: 'edit',
                    height: 40,
                    child: Row(
                      children: [
                        Icon(
                          Icons.edit_outlined,
                          color: AppColors.secondaryVariant,
                          size: 18,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Modifier',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'stats',
                    height: 40,
                    child: Row(
                      children: [
                        Icon(
                          Icons.insights,
                          color: AppColors.accentInk,
                          size: 18,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Statistiques',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isPublished)
                    PopupMenuItem(
                      value: 'publish',
                      height: 40,
                      child: Row(
                        children: [
                          Icon(
                            Icons.publish_rounded,
                            color: AppColors.success,
                            size: 18,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            dejaParu ? 'Remettre en vente' : 'Publier',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                  // « Archiver » promettait un statut que le serveur refuse ;
                  // l'action honnête est le retour en brouillon, proposée
                  // uniquement quand le livre est effectivement en vente.
                  if (isPublished)
                    PopupMenuItem(
                      value: 'retirer',
                      height: 40,
                      child: Row(
                        children: [
                          Icon(
                            Icons.remove_shopping_cart_outlined,
                            color: AppColors.textSecondary,
                            size: 18,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Retirer de la vente',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'delete',
                    height: 40,
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline,
                          color: AppColors.error,
                          size: 18,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Supprimer',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ];
              },
            ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Book Cover Area
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [AppColors.surfaceVariant, AppColors.darkSurface],
                    ),
                  ),
                  child: Column(
                    children: [
                      SizedBox(height: 30),
                      Container(
                        height: 240,
                        width: 168,
                        decoration: BoxDecoration(
                          color: AppColors.lightSurface,
                          borderRadius: BorderRadius.circular(
                            AppDimensions.radiusCard,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(
                            AppDimensions.radiusCard,
                          ),
                          child:
                              book.imageCouverture != null &&
                                  book.imageCouverture!.isNotEmpty &&
                                  !book.imageCouverture!.contains('example.com')
                              ? Image.network(
                                  book.imageCouverture!,
                                  fit: BoxFit.cover,
                                  height: 240,
                                  width: 168,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Icon(
                                        Icons.book,
                                        size: 60,
                                        color: AppColors.orange,
                                      ),
                                )
                              : Icon(
                                  Icons.book,
                                  size: 60,
                                  color: AppColors.orange,
                                ),
                        ),
                      ),
                      SizedBox(height: 40),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          book.titre,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.pageTitle,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        _getAuthorDisplayName(book),
                        style: AppTextStyles.withColor(
                          AppTextStyles.subtitle,
                          AppColors.primary,
                        ),
                      ),
                      SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // `telechargements` portait ici le nombre d'avis :
                          // le modèle le remplissait depuis `nombre_avis`. Le
                          // champ dit maintenant la vérité de son nom, et
                          // c'est `nombreAvis` qu'on lit — sans quoi cette
                          // ligne compterait des téléchargements en les
                          // appelant « avis ».
                          if (book.nombreAvis > 0 || _reviews.isNotEmpty)
                            Builder(
                              builder: (_) {
                                final moyenne = _moyenneDesAvis;
                                final nombre = book.nombreAvis > 0
                                    ? book.nombreAvis
                                    : _reviews.length;
                                return Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Sans moyenne connue, pas d'étoiles : cinq
                                    // étoiles vides sont un jugement, pas une
                                    // absence de réponse.
                                    if (moyenne != null) ...[
                                      _buildStars(moyenne),
                                      SizedBox(width: 8),
                                    ],
                                    Text(
                                      moyenne != null
                                          ? "${moyenne.toStringAsFixed(1)} ($nombre avis)"
                                          : "Pas encore de note",
                                      style: GoogleFonts.poppins(
                                        color: AppColors.textSecondary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          if (book.nombreMessages > 0) ...[
                            SizedBox(width: 12),
                            Icon(
                              Iconsax.message,
                              color: AppColors.textSecondary,
                              size: 12,
                            ),
                            SizedBox(width: 4),
                            Text(
                              "${book.nombreMessages} message${book.nombreMessages > 1 ? 's' : ''}",
                              style: GoogleFonts.poppins(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                      // Sa note à lui, sur une ligne à elle et sous son nom.
                      //
                      // C'est ce que la boutique montrait à la place de la
                      // moyenne : la note du lecteur passait pour celle de
                      // l'ouvrage. Elle reste affichée — la décision est de la
                      // garder — mais dite, et à côté de la moyenne, non
                      // dessus.
                      if (_noteDuLecteur != null) ...[
                        SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.star_rounded,
                              color: AppColors.warning,
                              size: 14,
                            ),
                            SizedBox(width: 4),
                            Text(
                              "Votre note : $_noteDuLecteur/5",
                              style: GoogleFonts.poppins(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                      SizedBox(height: 30),
                    ],
                  ),
                ),

                // Synopsis
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Description', style: AppTextStyles.sectionTitle),
                      const SizedBox(height: 12),
                      AnimatedCrossFade(
                        firstChild: Text(
                          book.description.isEmpty
                              ? "Aucune description disponible pour ce livre."
                              : book.description,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            height: 1.6,
                          ),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                        secondChild: Text(
                          book.description.isEmpty
                              ? "Aucune description disponible pour ce livre."
                              : book.description,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            height: 1.6,
                          ),
                        ),
                        crossFadeState: _isDescriptionExpanded
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        duration: const Duration(milliseconds: 250),
                      ),
                      if (book.description.length > 100) ...[
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () {
                            setState(() {
                              _isDescriptionExpanded = !_isDescriptionExpanded;
                            });
                          },
                          borderRadius: BorderRadius.circular(
                            AppDimensions.radiusSmall,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 4,
                              horizontal: 2,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _isDescriptionExpanded
                                      ? 'Réduire'
                                      : 'Lire la suite',
                                  style: GoogleFonts.poppins(
                                    color: AppColors.secondaryVariant,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  _isDescriptionExpanded
                                      ? Icons.keyboard_arrow_up_rounded
                                      : Icons.keyboard_arrow_down_rounded,
                                  size: 18,
                                  color: AppColors.secondaryVariant,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 40),

                      // Sommaire
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Sommaire', style: AppTextStyles.sectionTitle),
                          // « 3 CHAPITRES » s'affichait des que la liste
                          // etait vide : un compte invente, jamais celui du
                          // livre. Sans chapitre connu, on n'annonce rien.
                          Text(
                            _chapitres.isNotEmpty
                                ? "${_chapitres.length} CHAPITRES"
                                : "",
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),

                      if (_chapitres.isNotEmpty)
                        ..._chapitres.take(3).toList().asMap().entries.map((
                          entry,
                        ) {
                          final index = entry.key;
                          final ch = entry.value;
                          final bool hasExtrait = _hasExtraitAvailable(book);
                          final isExtraitGratuit =
                              (!isOwned) &&
                              _isChapterInExtrait(
                                ch,
                                index,
                                hasExtrait: hasExtrait,
                                dernierePage: _dernierePageDeLExtrait(book),
                              );
                          final isLocked = !isOwned && !isExtraitGratuit;
                          final numStr = ch.numero < 10
                              ? "0${ch.numero}"
                              : "${ch.numero}";
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: _buildChapterTile(
                              number: numStr,
                              title: ch.titre,
                              description: ch.description.isNotEmpty
                                  ? ch.description
                                  : (isLocked
                                        ? _texteChapitreVerrouille
                                        : "Extrait gratuit - Disponible à la lecture."),
                              isLocked: isLocked,
                              onTap: () async {
                                if (isLocked) {
                                  _lancerPaiementDirect(book);
                                } else {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ReadingPage(
                                        book: book.toJson(),
                                        isExtrait: !isOwned,
                                        initialPage: ch.pageDepart > 0
                                            ? ch.pageDepart
                                            : null,
                                      ),
                                    ),
                                  );
                                  if (mounted && _isOwned) {
                                    _loadReadingProgress();
                                  }
                                }
                              },
                            ),
                          );
                        }).toList()
                      else
                        _buildSommaireNonDetaille(book, isOwned),

                      const SizedBox(height: 12),
                      // « Voir tous les chapitres » n'a de sens que si le
                      // serveur en connaît : sans chapitre, la feuille
                      // n'aurait rien de plus que ce qui est déjà à l'écran,
                      // et le lien promettrait une liste qui n'existe pas.
                      if (_chapitres.isNotEmpty)
                        Center(
                          child: InkWell(
                            onTap: () => _showAllChaptersModal(context),
                            borderRadius: BorderRadius.circular(
                              AppDimensions.radiusSmall,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    "Voir tous les chapitres",
                                    style: GoogleFonts.poppins(
                                      color: AppColors.accentInk,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    color: AppColors.accentInk,
                                    size: 12,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                      SizedBox(height: 40),

                      // Avis de la communauté
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Avis de la communauté',
                            style: AppTextStyles.subtitle,
                          ),
                          InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AllReviewsPage(
                                    book: book,
                                    reviews: _reviews,
                                  ),
                                ),
                              );
                            },
                            child: Text(
                              'Voir tout',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: AppColors.accentInk,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      // Review list
                      if (_isLoadingReviews)
                        Center(
                          child: Text(
                            "Chargement des avis...",
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        )
                      else if (_reviews.isEmpty)
                        Text(
                          "Soyez le premier à donner votre avis !",
                          style: AppTextStyles.grey13,
                        )
                      else
                        ..._reviews.map(
                          (r) => Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _buildReviewCard(
                              r.nomUtilisateur ?? "Avis vérifié",
                              r.creeLe != null
                                  ? DateFormat('dd MMM yyyy').format(r.creeLe!)
                                  : "Récemment",
                              r.note,
                              r.commentaire ?? "",
                              r.photoProfil,
                            ),
                          ),
                        ),
                      SizedBox(height: 24),

                      if (isOwned)
                        Container(
                          width: double.infinity,
                          height: 54,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                              AppDimensions.radiusCard,
                            ),
                            border: Border.all(
                              color: AppColors.accentInk.withOpacity(0.3),
                              width: 1.5,
                            ),
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primary.withOpacity(0.05),
                                AppColors.primary.withOpacity(0.01),
                              ],
                            ),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(
                                AppDimensions.radiusCard,
                              ),
                              onTap: () => _showReviewDialog(context),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.star_rounded,
                                    color: AppColors.accentInk,
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    "Laisser un avis",
                                    style: AppTextStyles.withColor(
                                      AppTextStyles.button14,
                                      AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                      SizedBox(height: 40),

                      // Recommandations.
                      //
                      // Elles etaient cachees par `if (!isOwned)` : seul celui
                      // qui NE possedait PAS le livre les voyait. C'est
                      // l'inverse du bon moment — un lecteur qui vient de finir
                      // un ouvrage est precisement celui a qui proposer le
                      // suivant du meme auteur.
                      //
                      // `_loadRelatedBooks()` tournait deja pour tout le monde
                      // (initState) : la liste etait chargee puis jetee.
                      if (!_isLoadingRelated) ...[
                        // La panne AVANT le vide, section par section : sans
                        // cela un 500 sur /books/author/:id retirait le bloc
                        // « Du même auteur » en silence, ce qui se lit comme
                        // « il n'a rien écrit d'autre ».
                        if (_erreurLivresAuteur != null)
                          _buildRelatedErrorSection(
                            titre: "Du même auteur",
                            message: _erreurLivresAuteur!,
                            enCours: _rechargementLivresAuteur,
                            relancer: _reessayerLivresAuteur,
                          )
                        else if (_authorBooks.isNotEmpty)
                          _buildRelatedSection("Du même auteur", _authorBooks),
                        if (_erreurLivresCategorie != null)
                          _buildRelatedErrorSection(
                            titre: "Livres similaires",
                            message: _erreurLivresCategorie!,
                            enCours: _rechargementLivresCategorie,
                            relancer: _reessayerLivresCategorie,
                          )
                        else if (_categoryBooks.isNotEmpty)
                          _buildRelatedSection(
                            "Livres similaires",
                            _categoryBooks,
                          ),
                      ] else ...[
                        Center(
                          child: Text(
                            "Chargement...",
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(height: 20),
              ],
            ),
          ),

          // Fixed Bottom Bar
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.darkSurface,
                border: Border(
                  top: BorderSide(
                    color: AppColors.textPrimary.withOpacity(0.05),
                    width: 1,
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                child: _isLoadingOwnership
                    ? Center(
                        child: Text(
                          "...",
                          style: TextStyle(color: AppColors.textPrimary),
                        ),
                      )
                    // Vérification de possession en PANNE : on ne sait pas si
                    // le lecteur possède le livre, donc on ne lui montre pas
                    // « Acheter » comme seule vérité — état d'erreur + relance.
                    : _verificationPossessionImpossible && !isOwned
                    ? _bandeauVerificationImpossible()
                    // Un livre gratuit ne se vend pas.
                    //
                    // Proposer un panier et un bouton « Acheter » sur un
                    // ouvrage a prix nul, c'est demander de payer ce que
                    // l'auteur a decide de donner. On l'ouvre, c'est tout.
                    : !isOwned && _estGratuit
                    ? _boutonLireGratuitement()
                    : !isOwned
                    ? widget.peutAcheter
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "PRIX EBOOK",
                                            style: GoogleFonts.poppins(
                                              color: AppColors.textSecondary,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                          FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              _formatPrix(book.prix),
                                              style: AppTextStyles.heroTitle22,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: SizedBox(
                                        height: 50,
                                        child: ElevatedButton(
                                          onPressed: _paiementEnCours
                                              ? null
                                              : () =>
                                                    _lancerPaiementDirect(book),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                AppColors.secondary,
                                            foregroundColor: AppColors.onAccent,
                                            disabledBackgroundColor: AppColors
                                                .secondary
                                                .withValues(alpha: 0.6),
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    AppDimensions.radiusInner,
                                                  ),
                                            ),
                                          ),
                                          child: _paiementEnCours
                                              ? SizedBox(
                                                  height: 20,
                                                  width: 20,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color:
                                                            AppColors.onAccent,
                                                      ),
                                                )
                                              : Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons.shopping_bag,
                                                      size: 18,
                                                    ),
                                                    SizedBox(width: 6),
                                                    Flexible(
                                                      child: Text(
                                                        'Acheter',
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style:
                                                            GoogleFonts.poppins(
                                                              fontSize: 14,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                            ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 12),
                                () {
                                  final bool hasExtrait = _hasExtraitAvailable(
                                    book,
                                  );
                                  return SizedBox(
                                    width: double.infinity,
                                    height: 50,
                                    child: OutlinedButton(
                                      onPressed: hasExtrait
                                          ? () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      ReadingPage(
                                                        book: book.toJson(),
                                                        isExtrait: !isOwned,
                                                      ),
                                                ),
                                              );
                                            }
                                          : null,
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.textPrimary,
                                        disabledForegroundColor: AppColors
                                            .textSecondary
                                            .withValues(alpha: 0.4),
                                        side: BorderSide(
                                          color: hasExtrait
                                              ? AppColors.textPrimary
                                                    .withValues(alpha: 0.2)
                                              : AppColors.textSecondary
                                                    .withValues(alpha: 0.1),
                                        ),
                                        backgroundColor: hasExtrait
                                            ? Colors.transparent
                                            : Colors.white.withValues(
                                                alpha: 0.02,
                                              ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            AppDimensions.radiusInner,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            hasExtrait
                                                ? Icons.menu_book
                                                : Icons.menu_book_outlined,
                                            size: 18,
                                            color: hasExtrait
                                                ? AppColors.textPrimary
                                                : AppColors.textSecondary
                                                      .withValues(alpha: 0.4),
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            hasExtrait
                                                ? "Lire un extrait"
                                                : "Aucun extrait disponible",
                                            style: GoogleFonts.poppins(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: hasExtrait
                                                  ? AppColors.textPrimary
                                                  : AppColors.textSecondary
                                                        .withValues(alpha: 0.4),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }(),
                              ],
                            )
                          : Center(
                              child: Text(
                                "Consultation Auteur",
                                style: GoogleFonts.poppins(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isOwned) ...[
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "Progression de lecture",
                                        style: GoogleFonts.poppins(
                                          color: AppColors.textSecondary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        "$_progressionPourcentage%",
                                        style: GoogleFonts.poppins(
                                          color: AppColors.accentInk,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(
                                      AppDimensions.radiusXs,
                                    ),
                                    child: LinearProgressIndicator(
                                      value: (_progressionPourcentage / 100)
                                          .clamp(0.0, 1.0),
                                      backgroundColor: Colors.white.withValues(
                                        alpha: 0.05,
                                      ),
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        AppColors.primary,
                                      ),
                                      minHeight: 6,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (_isAuthorOfThisBook)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.auto_awesome,
                                    size: 15,
                                    color: AppColors.accentInk,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    "Vous êtes l'auteur de cet ouvrage",
                                    style: GoogleFonts.poppins(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.accentInk,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: () async {
                                final lastPage =
                                    (_readingProgress?.lastPage != null &&
                                        _readingProgress!.lastPage > 0)
                                    ? _readingProgress!.lastPage
                                    : (_readingProgress?.chapitreCourant !=
                                              null &&
                                          _readingProgress!.chapitreCourant > 0)
                                    ? _readingProgress!.chapitreCourant
                                    : null;
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ReadingPage(
                                      book: book.toJson(),
                                      initialPage: lastPage,
                                    ),
                                  ),
                                );
                                if (mounted && _isOwned) {
                                  _loadReadingProgress();
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: AppColors.onAccent,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppDimensions.radiusInner,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.menu_book, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    _isAuthorOfThisBook
                                        ? 'Lire mon ouvrage'
                                        : (_progressionPourcentage >= 100
                                              ? 'Relire l\'ouvrage'
                                              : (_progressionPourcentage > 0
                                                    ? 'Continuer la lecture'
                                                    : 'Commencer la lecture')),
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Une section de recommandations qui n'a pas pu être chargée.
  ///
  /// Elle garde son titre : sans lui, le lecteur ne saurait même pas QUELLE
  /// liste manque. Le message vient du serveur quand il en a donné un, et le
  /// bouton relance cette seule section.
  Widget _buildRelatedErrorSection({
    required String titre,
    required String message,
    required bool enCours,
    required Future<void> Function() relancer,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
        Text(titre, style: AppTextStyles.sectionTitle),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 20,
                    color: AppColors.error,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      message,
                      style: GoogleFonts.poppins(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  // Désactivé pendant la tentative : réappuyer lancerait un
                  // second appel dont la réponse écraserait la première.
                  onPressed: enCours ? null : () => relancer(),
                  child: Text(
                    enCours ? "Nouvelle tentative..." : "Réessayer",
                    style: GoogleFonts.poppins(
                      color: AppColors.accentInk,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRelatedSection(String title, List<BookModel> books) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 32),
        Text(title, style: AppTextStyles.sectionTitle),
        SizedBox(height: 20),
        SizedBox(
          height: 280,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: books.length,
            padding: EdgeInsets.zero,
            clipBehavior: Clip.none,
            itemBuilder: (context, index) {
              final book = books[index];
              return _buildBookCard(book);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBookCard(BookModel book) {
    return GestureDetector(
      onTap: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => BookDetailPage(
              book: book,
              isOwned: _ownedBookIds.contains(book.id),
            ),
          ),
        );
      },
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover Image with Shadow and Rounded Corners
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
                child:
                    book.imageCouverture != null &&
                        book.imageCouverture!.isNotEmpty &&
                        !book.imageCouverture!.contains('example.com')
                    ? Image.network(
                        book.imageCouverture!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _buildPlaceholderCover(),
                      )
                    : _buildPlaceholderCover(),
              ),
            ),
            SizedBox(height: 12),
            // Title
            Text(
              book.titre,
              style: AppTextStyles.cardTitleSmallSemiBold,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 1),
            // Author
            Text(
              book.authorName,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 4),
            // Price and Stats Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  book.prix > 0 ? "${book.prix} F" : "Gratuit",
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.accentInk,
                  ),
                ),
                Row(
                  children: [
                    if (book.noteMoyenne > 0) ...[
                      Icon(
                        Icons.star_rounded,
                        color: AppColors.warning,
                        size: 10,
                      ),
                      SizedBox(width: 2),
                      Text(
                        book.noteMoyenne.toStringAsFixed(1),
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (book.nombreMessages > 0) ...[
                      SizedBox(width: 6),
                      Icon(
                        Iconsax.message,
                        color: AppColors.textHint,
                        size: 10,
                      ),
                      SizedBox(width: 2),
                      Text(
                        "${book.nombreMessages}",
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: AppColors.textHint,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Barre affichée quand la vérification de possession a échoué.
  ///
  /// Elle remplace la barre d'achat : proposer de payer alors qu'on ignore si
  /// le livre est déjà possédé, c'est risquer de faire repayer un acheteur.
  ///
  /// Deux échecs, deux recours : une panne se réessaie, une session finie se
  /// reconnecte. « Réessayer » sur un jeton mort ne pouvait qu'échouer encore.
  Widget _bandeauVerificationImpossible() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _sessionExpiree
              ? "Votre session a expiré. Reconnectez-vous pour retrouver votre bibliothèque."
              : "Impossible de vérifier si vous possédez déjà ce livre.",
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            color: AppColors.textSecondary,
            fontSize: 12.5,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton.icon(
            onPressed: _sessionExpiree
                ? _seReconnecter
                : _reessayerVerificationPossession,
            icon: Icon(
              _sessionExpiree ? Icons.login : Icons.refresh,
              size: 18,
              color: AppColors.textPrimary,
            ),
            label: Text(
              _sessionExpiree ? "Se reconnecter" : "Réessayer",
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: AppColors.textPrimary.withValues(alpha: 0.2),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusInner),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Le seul bouton d'un livre gratuit.
  ///
  /// Il fait les deux gestes d'un coup : le livre entre dans la bibliotheque —
  /// sans quoi le lecteur ne pourrait ni le retrouver ni reprendre ou il en
  /// etait — puis la lecture s'ouvre. Le serveur verifie le prix ; l'appel
  /// echoue si l'ouvrage n'est pas reellement gratuit.
  Widget _boutonLireGratuitement() {
    return SizedBox(
      height: 50,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _acquisitionEnCours ? null : _lireGratuitement,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onAccent,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.6),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusInner),
          ),
        ),
        child: _acquisitionEnCours
            ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.onAccent,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.menu_book, size: 18),
                  SizedBox(width: 8),
                  Text(
                    "Lire gratuitement",
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _lancerPaiementDirect(BookModel book) async {
    if (_paiementEnCours) return;

    final double amount = book.prix.toDouble();
    if (amount <= 0) {
      await _lireGratuitement();
      return;
    }

    // On ignore si ce livre est DÉJÀ acquis : ne pas proposer de le payer.
    //
    // La garde est posée ici, au seul point de départ des achats de la fiche :
    // les huit chapitres verrouillés et la barre du bas y passent tous, et la
    // règle ne peut donc plus diverger d'un bouton à l'autre.
    if (_possessionIncertaine) {
      _traiterAppuiPossessionIncertaine();
      return;
    }

    setState(() => _paiementEnCours = true);

    try {
      final token = await TokenStorage.getToken();
      if (token == null) {
        if (mounted) {
          AppNotifications.showSnackBar(
            context,
            message: "Veuillez vous connecter pour effectuer un achat",
            isError: true,
          );
        }
        return;
      }

      final user = _currentUser ?? await AuthService().getUser(token);
      if (user == null) {
        if (mounted) {
          AppNotifications.showSnackBar(
            context,
            message: "Impossible de récupérer les informations de votre compte",
            isError: true,
          );
        }
        return;
      }

      final paymentService = PaymentService();

      // GARDE ANTI-DOUBLE-DÉBIT.
      //
      // Le serveur crée TOUJOURS une ligne neuve à l'initiation et sa seule
      // garde compte les achats CONFIRMÉS : revenu sur la fiche pendant que
      // son premier paiement attendait l'opérateur, le lecteur pouvait rouvrir
      // une transaction et être débité deux fois pour un seul livre. Le site
      // web porte le même correctif (paiement.ts / transactionEnCours) ; ici,
      // faute de trace locale, on demande au serveur la liste des paiements.
      final poursuivre = await _verifierPaiementDejaOuvert(
        paymentService,
        book,
        token,
        user.id,
      );
      if (!poursuivre) return;
      if (!mounted) return;

      final result = await paymentService.initiateCinetpayPayment(
        livreId: book.id,
        montant: amount,
        authToken: token,
        customerName: user.nomComplet.isNotEmpty
            ? user.nomComplet
            : "Lecteur SpaceLearn",
        customerEmail: user.email.isNotEmpty
            ? user.email
            : "client@spacelearn.com",
      );

      // Le montant OFFICIEL : celui que le serveur a relu en base au moment
      // d'ouvrir la transaction, pas le prix affiché par la fiche. Entre le
      // chargement de l'écran et l'achat, l'auteur a pu changer son prix, et
      // c'est le débit réel qu'il faut annoncer.
      final double montantServeur = result.paiement.montant > 0
          ? result.paiement.montant
          : amount;

      // La transaction est MÉMORISÉE avant d'envoyer le lecteur payer.
      //
      // Cette trace locale n'était écrite que par l'écran de paiement, qu'aucune
      // route n'atteint : la garde anti-double-débit ne disposait donc, sur les
      // chemins réellement empruntés, que de la liste du serveur — inutilisable
      // dès que le réseau flanche, c'est-à-dire précisément au moment où un
      // lecteur revient réessayer.
      await TransactionEnCoursStore.memoriser(
        userId: user.id,
        livreId: book.id,
        transactionId: result.paiement.transactionId,
        montant: montantServeur,
      );

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CinetpayWebViewPage(
            paymentUrl: result.paymentUrl,
            transactionId: result.paiement.transactionId,
            book: book.toJson(),
            montant: montantServeur,
          ),
        ),
      );

      if (mounted) {
        // Au retour, la fiche RECHARGE le livre — la seule vérification de
        // possession ne suffisait pas.
        //
        // `_fullBook` a été reçu avant l'achat : son `fichier_url` est l'URL
        // signée de l'EXTRAIT, que le serveur substitue au manuscrit pour un
        // non-possesseur (livre/service.go). Le bouton « Lire » ouvrait la
        // liseuse avec cet objet, la liseuse trouvait une URL non vide, ne
        // redemandait rien, et écrivait l'aperçu dans l'emplacement du livre
        // complet : l'acheteur relisait ses deux pages d'extrait. Le ménage de
        // l'écran de résultat ne couvre pas ce chemin — on peut fermer la
        // webview ou revenir par un geste retour sans jamais y passer.
        await BookCacheService().clearBookCache(book.id, '', extrait: false);
        if (!mounted) return;
        await _loadFullBookDetails();
      }
    } catch (e) {
      if (mounted) {
        AppNotifications.showSnackBar(
          context,
          message: messageLisible(
            e,
            repli: "Le paiement n'a pas pu être lancé.",
          ),
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _paiementEnCours = false);
      }
    }
  }

  /// Cherche une transaction déjà ouverte pour ce livre avant d'en créer une.
  ///
  /// Rend `false` quand il ne faut PAS lancer de nouveau paiement : soit le
  /// précédent vient d'être confirmé (le livre est déjà accordé), soit le
  /// lecteur a choisi d'attendre la confirmation plutôt que de repayer.
  ///
  /// La règle elle-même n'est plus écrite ici : elle vit dans
  /// [PaymentService.examinerTransactionOuverte], partagée avec les deux autres
  /// écrans qui lancent un paiement. Chacun en portait sa version, et elles
  /// s'étaient mises à se contredire — notamment sur ce qu'il faut faire quand
  /// le statut de la transaction précédente est invérifiable. Cet écran ne
  /// décide plus que de ce qu'il MONTRE.
  Future<bool> _verifierPaiementDejaOuvert(
    PaymentService paymentService,
    BookModel book,
    String token,
    String userId,
  ) async {
    final garde = await paymentService.examinerTransactionOuverte(
      userId: userId,
      livreId: book.id,
      authToken: token,
    );
    if (!mounted) return false;

    if (garde.verdict == VerdictPaiement.dejaAcquis) {
      AppNotifications.showSnackBar(
        context,
        message:
            "Votre paiement précédent a été confirmé : ce livre est déjà dans votre bibliothèque.",
        isSuccess: true,
      );
      await _checkOwnershipStatus();
      return false;
    }

    if (garde.verdict == VerdictPaiement.aConfirmerParLaPersonne) {
      // Ni confirmée ni close : peut-être réglée (webhook en retard, jusqu'à
      // ~13 min), peut-être abandonnée. Seul le lecteur le sait — on lui pose
      // la question au lieu d'ouvrir une seconde transaction en silence.
      final payerQuandMeme = await _confirmerNouveauPaiement(garde);
      return payerQuandMeme == true;
    }

    // VerdictPaiement.laisserPasser — y compris sur une vérification en panne :
    // refuser un achat parce qu'on n'a pas pu lire la liste des paiements
    // fermerait la boutique, et le serveur reste seul à accorder le livre.
    return true;
  }

  /// Demande au lecteur quoi faire d'une transaction encore ouverte.
  Future<bool?> _confirmerNouveauPaiement(GardePaiement enAttente) {
    final quand = enAttente.ouverteLe != null
        ? " ouverte le ${DateFormat('dd/MM/yyyy à HH:mm').format(enAttente.ouverteLe!.toLocal())}"
        : "";
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
        ),
        title: Text(
          'Un paiement est déjà en cours',
          style: GoogleFonts.poppins(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        content: Text(
          'Une transaction pour ce livre$quand attend encore la confirmation '
          'de l\'opérateur (référence ${enAttente.transactionId}).\n\n'
          'Si vous avez déjà réglé, la confirmation peut prendre quelques '
          'minutes : payer à nouveau vous ferait débiter une seconde fois. '
          'Ne relancez un paiement que si vous aviez abandonné le précédent.',
          style: GoogleFonts.poppins(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Attendre la confirmation',
              style: GoogleFonts.poppins(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
              foregroundColor: AppColors.onAccent,
            ),
            child: Text(
              'Payer à nouveau',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _lireGratuitement() async {
    setState(() => _acquisitionEnCours = true);
    try {
      final token = await TokenStorage.getToken();
      if (token == null) {
        if (!mounted) return;
        AppNotifications.showSnackBar(
          context,
          message: "Votre session a expiré. Reconnectez-vous.",
          isError: true,
        );
        return;
      }

      await LibraryService().acquerirGratuitement(widget.book.id, token);
      if (!mounted) return;

      // Le livre est relu apres l'acquisition, et ce n'est pas un luxe.
      //
      // Le serveur masque l'adresse du manuscrit tant que le lecteur ne
      // possede pas l'ouvrage. L'objet affiche sur cette fiche a donc ete
      // recu SANS elle : le passer tel quel au lecteur donnait « Aucun fichier
      // disponible pour ce livre » sur un livre qu'on venait d'obtenir.
      final aJour = await BookService().getBookById(
        widget.book.id,
        authToken: token,
      );
      if (!mounted) return;

      setState(() => _isOwned = true);
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ReadingPage(book: aJour.toJson()),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      // Le message du SERVEUR, tel quel : « Ce livre est payant » (402) ou
      // « Votre session a expiré » ne se réparent pas en vérifiant sa
      // connexion, et c'est pourtant ce que la phrase unique conseillait.
      AppNotifications.showSnackBar(
        context,
        message: messageLisible(
          e,
          repli: "Le livre n'a pas pu être ouvert. Vérifiez votre connexion.",
        ),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _acquisitionEnCours = false);
    }
  }

  Widget _buildPlaceholderCover() {
    return Container(
      color: AppColors.surfaceVariant,
      child: Center(
        child: Icon(Icons.book, color: AppColors.accentInk, size: 30),
      ),
    );
  }

  Widget _buildStars(double rating) {
    int fullStars = rating.floor();
    bool hasHalfStar = (rating - fullStars) >= 0.5;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        if (index < fullStars) {
          return Icon(Icons.star, color: AppColors.warning, size: 18);
        } else if (index == fullStars && hasHalfStar) {
          return Icon(Icons.star_half, color: AppColors.warning, size: 18);
        } else {
          return Icon(Icons.star_border, color: AppColors.warning, size: 18);
        }
      }),
    );
  }

  Widget _buildReviewCard(
    String name,
    String time,
    int stars,
    String comment, [
    String? photoUrl,
  ]) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(color: AppColors.textPrimary.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primary.withOpacity(0.2),
                backgroundImage:
                    (photoUrl != null &&
                        photoUrl.isNotEmpty &&
                        !photoUrl.contains('example.com'))
                    ? NetworkImage(photoUrl)
                    : null,
                child:
                    (photoUrl == null ||
                        photoUrl.isEmpty ||
                        photoUrl.contains('example.com'))
                    ? Icon(Icons.person, color: AppColors.accentInk, size: 18)
                    : null,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: AppTextStyles.cardTitleSmall),
                    Text(
                      time,
                      style: GoogleFonts.poppins(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: List.generate(5, (index) {
                  return Icon(
                    index < stars
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: AppColors.warning,
                    size: 16,
                  );
                }),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            comment,
            style: GoogleFonts.poppins(
              color: AppColors.textSecondary,
              fontStyle: FontStyle.italic,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  void _showReviewDialog(BuildContext context) {
    int selectedStars = 5;
    TextEditingController commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surfaceVariant,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
              ),
              title: Text("Laisser un avis", style: AppTextStyles.sectionTitle),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return IconButton(
                        icon: Icon(
                          index < selectedStars
                              ? Icons.star
                              : Icons.star_border,
                          color: AppColors.warning,
                          size: 32,
                        ),
                        onPressed: () {
                          setDialogState(() {
                            selectedStars = index + 1;
                          });
                        },
                      );
                    }),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: commentController,
                    maxLines: 4,
                    style: TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: "Écrivez votre commentaire ici...",
                      hintStyle: TextStyle(
                        color: AppColors.textPrimary.withOpacity(0.5),
                      ),
                      filled: true,
                      fillColor: AppColors.surfaceVariant,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusInner,
                        ),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    "Annuler",
                    style: GoogleFonts.poppins(color: AppColors.textSecondary),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusSmall,
                      ),
                    ),
                  ),
                  onPressed: () async {
                    // Le dialogue fermait AVANT l'envoi : au premier échec —
                    // réseau, ou 403 « vous ne pouvez noter qu'un ouvrage de
                    // votre bibliothèque » — le commentaire rédigé était
                    // irrécupérable. On ne ferme qu'APRÈS le succès confirmé
                    // par le serveur ; sur échec, le dialogue reste ouvert,
                    // texte intact, et le message du serveur s'affiche.
                    final token = await TokenStorage.getToken();
                    if (!context.mounted) return;
                    if (token == null) {
                      AppNotifications.showSnackBar(
                        context,
                        message:
                            "Veuillez vous connecter pour laisser un avis.",
                        isError: true,
                      );
                      return;
                    }

                    try {
                      await _reviewService.addReview(
                        livreId: widget.book.id,
                        note: selectedStars,
                        commentaire: commentController.text,
                        authToken: token,
                      );
                      // Succès confirmé : la saisie ne risque plus rien.
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                      _loadReviews(); // Reload the reviews
                      if (mounted) {
                        AppNotifications.showSnackBar(
                          this.context,
                          message: "Avis ajouté avec succès !",
                          isSuccess: true,
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        AppNotifications.showSnackBar(
                          context,
                          message: messageLisible(
                            e,
                            repli: "L'avis n'a pas pu être envoyé.",
                          ),
                          isError: true,
                        );
                      }
                    }
                  },
                  child: Text(
                    "Envoyer",
                    style: GoogleFonts.poppins(color: AppColors.onAccent),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Ce qui s'affiche quand le serveur ne rend AUCUN chapitre pour ce livre.
  ///
  /// Trois tuiles tenaient cette place : « 01 Introduction », « 02
  /// Développement », « 03 Conclusion ». Elles n'avaient aucune source — ni le
  /// livre, ni le serveur ne les avaient jamais nommées ; ces titres étaient
  /// écrits ici et s'affichaient pour TOUT ouvrage dont
  /// /api/books/:id/chapters ne rend rien. Un lecteur y lisait la structure de
  /// l'ouvrage, un auteur y voyait un sommaire qu'il n'avait pas saisi.
  ///
  /// Une seule entrée honnête les remplace : elle ouvre ce qui est réellement
  /// accessible (l'ouvrage pour qui le possède, l'extrait sinon), reste
  /// verrouillée quand rien ne l'est, et ne prétend rien décrire.
  ///
  /// [contexteFeuille] est le contexte de la feuille « Tous les chapitres »
  /// quand l'entrée y est posée : c'est LUI qu'il faut refermer, celui de la
  /// page fermerait la fiche.
  Widget _buildSommaireNonDetaille(
    BookModel book,
    bool isOwned, {
    BuildContext? contexteFeuille,
  }) {
    final bool hasExtrait = _hasExtraitAvailable(book);
    final bool ouvrable = isOwned || hasExtrait;
    final String titre = isOwned
        ? "Ouvrir le livre"
        : hasExtrait
        ? "Lire l'extrait gratuit"
        : "Lecture verrouillée";
    final String detail = ouvrable
        ? (isOwned
              ? "Disponible dans l'ouvrage."
              : "Extrait gratuit - Disponible à la lecture.")
        : _texteChapitreVerrouille;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Le sommaire de ce livre n'est pas détaillé.",
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () {
            if (contexteFeuille != null) Navigator.pop(contexteFeuille);
            if (!ouvrable) {
              // Verrouillé : le seul appui qui a un sens ici est celui qui
              // relance une vérification de possession en panne. Ouvrir un
              // paiement depuis une tuile grisée, sans confirmation, n'en a
              // jamais eu — l'achat se fait par le bouton du bas.
              if (_possessionIncertaine) _traiterAppuiPossessionIncertaine();
              return;
            }
            _ouvrirLaLiseuse(book, isOwned);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(AppDimensions.radiusInner),
              border: Border.all(
                color: ouvrable
                    ? AppColors.primary.withOpacity(0.15)
                    : AppColors.textPrimary.withOpacity(0.04),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titre,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: ouvrable
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        detail,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  ouvrable ? Icons.play_circle_outline : Icons.lock_outline,
                  color: ouvrable
                      ? AppColors.accentInk
                      : AppColors.textSecondary,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Ouvre la liseuse, puis relit la progression au retour.
  Future<void> _ouvrirLaLiseuse(BookModel book, bool isOwned) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReadingPage(book: book.toJson(), isExtrait: !isOwned),
      ),
    );
    // Sans ce garde, un retour apres fermeture de la fiche appellerait
    // setState sur un widget demonte.
    if (!mounted) return;
    if (_isOwned) _loadReadingProgress();
  }

  Widget _buildChapterTile({
    required String number,
    required String title,
    required String description,
    required bool isLocked,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      // Une tuile verrouillée avalait TOUS les appuis. Quand la possession est
      // incertaine, sa description dit pourtant « appuyez pour réessayer » :
      // la promesse était morte, le geste ne relançait rien. Le doute rend
      // donc la tuile sensible — l'appui repart vers
      // `_traiterAppuiPossessionIncertaine`, qui relance la vérification ou
      // annonce la session finie. Le verrou ordinaire, lui, reste inerte :
      // l'achat se décide au bouton du bas, prix sous les yeux.
      onTap: isLocked && !_possessionIncertaine ? null : onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppDimensions.radiusInner),
          border: Border.all(
            color: isLocked
                ? AppColors.textPrimary.withOpacity(0.04)
                : AppColors.primary.withOpacity(0.15),
          ),
        ),
        child: Row(
          children: [
            Text(
              "$number.",
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isLocked ? AppColors.textSecondary : AppColors.accentInk,
              ),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isLocked
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    description,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            SizedBox(width: 8),
            Icon(
              isLocked ? Icons.lock_outline : Icons.play_circle_outline,
              color: isLocked ? AppColors.textSecondary : AppColors.accentInk,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
