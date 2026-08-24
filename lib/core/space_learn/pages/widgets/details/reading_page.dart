import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/utils/app_notifications.dart';
import 'package:space_learn_flutter/core/themes/app_text_styles.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:space_learn_flutter/core/themes/app_dimensions.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:space_learn_flutter/core/themes/widgets/app_segmented_control.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:space_learn_flutter/core/services/tts_service.dart';
import 'package:space_learn_flutter/core/services/preparation_texte.dart';
import 'package:space_learn_flutter/core/services/book_cache_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:epub_view/epub_view.dart' hide Image;
import '../../../../utils/token_storage.dart';
import '../../../data/dataServices/readingProgressService.dart';
import '../../../data/dataServices/minutes_en_attente.dart';
import '../../../data/dataServices/bookmarkService.dart';
import '../../../data/model/bookmark_model.dart';
import 'package:space_learn_flutter/core/themes/layout/recherche_bar.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/partageService.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/dataServices/readingSettingsService.dart';
import '../../../data/dataServices/reading_time_storage.dart';
import '../../../data/dataServices/paymentService.dart';
import '../../../data/dataServices/authServices.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/bookService.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/cinetpay_webview_page.dart';
import 'package:space_learn_flutter/core/services/lecture_audio_handler.dart';
import 'package:space_learn_flutter/core/utils/message_erreur.dart';
import 'package:space_learn_flutter/core/services/lecture_audio_livre.dart';
import 'package:space_learn_flutter/core/utils/api_routes.dart';

class ReadingPage extends StatefulWidget {
  final Map<String, dynamic> book;
  final int? initialPage;
  final bool isExtrait;

  const ReadingPage({
    super.key,
    required this.book,
    this.initialPage,
    this.isExtrait = false,
  });

  @override
  State<ReadingPage> createState() => _ReadingPageState();
}

class _ReadingPageState extends State<ReadingPage> {
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();
  late PdfViewerController _pdfViewerController;
  final ReadingProgressService _progressService = ReadingProgressService();
  final BookmarkService _bookmarkService = BookmarkService();
  final ReadingSettingsService _settingsService = ReadingSettingsService();

  final bool _showCover = false;
  int _currentPage = 1;
  int _totalPages = 0;
  bool _isDocumentLoaded = false;
  String? _loadError;
  int? _savedPage;
  Timer? _saveTimer;
  Timer? _settingsTimer;
  Timer? _heartbeatTimer;
  DateTime? _lastHeartbeatTick;
  DateTime? _sessionStartTime;
  bool _showControls = true;

  // PDF Reader Settings
  double _brightness = 1.0;
  Color _backgroundColor = AppColors.parchmentLight; // Parchment filter
  double _zoomLevel = 1.0;
  bool _isHorizontal = false;
  bool _isPdf = false;

  List<BookmarkModel> _bookmarks = [];
  List<PdfBookmark> _pdfBookmarks = [];
  Map<String, int> _bookmarkPageMap = {};
  String _currentChapterTitle = "Début du livre";

  // Search
  bool _isSearching = false;
  PdfTextSearchResult? _searchResult;
  final TextEditingController _searchController = TextEditingController();

  // TTS (Synthèse vocale)
  final TtsService _ttsService = TtsService();
  PdfDocument? _pdfDocument;
  bool _showTtsPanel = false;
  bool _isExtractingText = false;
  bool _autoplayNextPage = true;

  // Cache & Mode Hors-ligne
  final BookCacheService _bookCacheService = BookCacheService();
  Uint8List? _cachedBookBytes;

  /// Evite de reproposer l'achat a chaque passage sur la derniere page.
  bool _achatDejaPropose = false;
  bool _isLoadingFile = true;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  EpubController? _epubController;

  /// Le format du fichier ouvert, tel qu'il a été chargé.
  ///
  /// Il se déduisait de l'adresse du fichier, laquelle manque dès qu'on ouvre
  /// un livre déjà téléchargé sans réseau : l'écran concluait alors qu'aucun
  /// fichier n'était disponible, sur un manuscrit pourtant en mémoire.
  bool _estEpub = false;

  @override
  void initState() {
    super.initState();
    _pdfViewerController = PdfViewerController();
    _savedPage = widget.initialPage;
    _loadBookFile();
    _loadProgress();
    _loadSettings();
    _loadBookmarks();
    _lastHeartbeatTick = DateTime.now();
    _sessionStartTime = DateTime.now();
    _startHeartbeat();

    // Rattraper ce qu'une séance précédente n'a pas pu déclarer.
    //
    // On lit dans le métro, dans une cour sans réseau, en avion. Ces minutes-là
    // attendent sur l'appareil ; l'ouverture d'un livre est le bon moment pour
    // réessayer, le réseau est souvent revenu depuis.
    unawaited(MinutesEnAttente.vider());

    // L'ecran ne doit pas s'eteindre pendant la lecture.
    //
    // Rien ne l'empechait : une page lue trente secondes sans toucher l'ecran
    // suffisait a le voir s'assombrir puis se verrouiller. C'est la gene la
    // plus frequente d'une application de lecture, et elle se produit a chaque
    // seance.
    //
    // Le verrou est relache dans dispose : il ne doit pas survivre a la sortie
    // du lecteur, sous peine de vider la batterie sur toutes les autres pages.
    WakelockPlus.enable();

    // Ouvrir un livre reprend la voix a la bibliotheque.
    //
    // Les deux ecrans partagent le meme TtsService, qui est unique : sans
    // cela, l'ecoute lancee depuis la bibliotheque continuerait de tourner
    // par-dessus celle du lecteur, deux voix sur le meme telephone.
    //
    // Apres la frame, et non pendant : arreter() ne rencontre un await que si
    // une ecoute est reellement en cours. Sinon il va jusqu'a notifyListeners
    // sans rendre la main, donc ici, dans la pile de initState — c'est-a-dire
    // en pleine construction du widget. La bibliotheque, encore montee sous
    // cette page, ecoute ce notificateur et appelle setState : Flutter leve
    // « setState() or markNeedsBuild() called during build », et ChangeNotifier
    // rapporte l'exception sous « The LectureAudioLivre sending notification
    // was ».
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(LectureAudioLivre.instance.arreter());
    });

    // Initialisation TTS
    _ttsService.onCompletion = _onTtsCompletion;
    _ttsService.addListener(_onTtsStateChanged);

    // Ce que la notification de lecture annonce.
    lectureAudio?.annoncerLivre(
      titre: (widget.book['titre'] ?? widget.book['title'] ?? 'Lecture')
          .toString(),
      auteur:
          (widget.book['auteur_nom'] ??
                  widget.book['auteurNom'] ??
                  widget.book['auteur'] ??
                  '')
              .toString(),
      couverture:
          (widget.book['image_couverture'] ??
                  widget.book['imageCouverture'] ??
                  '')
              .toString(),
    );
  }

  Future<void> _loadBookFile() async {
    final bookId = (widget.book['id'] ?? widget.book['ID'] ?? '').toString();

    // Le disque d'abord, le réseau ensuite.
    //
    // L'ordre inverse faisait dépendre du réseau la lecture d'un livre déjà
    // téléchargé : `fichier_url` est signée pour quinze minutes, donc absente
    // ou périmée à l'ouverture suivante, et il fallait la redemander au serveur
    // avant même de regarder si le manuscrit était là. Sans couverture, un
    // ouvrage posé sur l'appareil s'annonçait « pas encore dans votre
    // bibliothèque ».
    if (bookId.isNotEmpty && await _ouvrirDepuisLeCache(bookId)) return;

    // Une seule adresse à lire : `fichier_url`.
    //
    // C'est le serveur qui décide ce qu'elle contient — le manuscrit entier
    // pour qui possède le livre, l'aperçu pour les autres — et lui seul la
    // signe. L'adresse de l'extrait voyage bien dans la réponse, mais brute :
    // la préférer ici menait à un 400, et faisait ouvrir l'aperçu de deux pages
    // à un lecteur qui venait d'acheter l'ouvrage.
    String? pdfUrl = widget.book['fichier_url'] ?? widget.book['fichierUrl'];

    // Si le lien du fichier est absent de l'objet initial (ex: livre venant d'être acheté),
    // on interroge le serveur avec le jeton d'authentification pour obtenir l'URL débloquée.
    if ((pdfUrl == null || pdfUrl.isEmpty) && bookId.isNotEmpty) {
      try {
        final token = await TokenStorage.getToken();
        if (token != null && token.isNotEmpty) {
          final freshBook = await BookService().getBookById(
            bookId,
            authToken: token,
          );
          if (freshBook.fichierUrl != null &&
              freshBook.fichierUrl!.isNotEmpty) {
            pdfUrl = freshBook.fichierUrl;
            widget.book['fichier_url'] = freshBook.fichierUrl;
            widget.book['format'] = freshBook.format;
          }
        }
      } catch (e) {
        debugPrint("Impossible de récupérer le fichier frais du livre : $e");
      }
    }

    if (pdfUrl == null || pdfUrl.isEmpty || bookId.isEmpty) {
      final aUnFichier =
          widget.book['a_un_fichier'] == true ||
          widget.book['aUnFichier'] == true;
      final indisponible =
          widget.book['fichier_indisponible'] == true ||
          widget.book['fichierIndisponible'] == true;

      setState(() {
        _isLoadingFile = false;
        if (indisponible) {
          // Le manuscrit est enregistré mais le serveur n'arrive pas à le
          // servir. Ce n'est ni l'absence d'un fichier ni un défaut d'achat :
          // le dire évite au lecteur de chercher ce qu'il a mal fait.
          _loadError =
              "Le fichier de ce livre est momentanément indisponible. "
              "Nous en avons été informés.";
        } else if (aUnFichier) {
          // Le fichier existe mais le serveur le masque : le lecteur doit
          // d'abord acquérir le livre.
          _loadError = widget.isExtrait
              ? "Ce livre ne propose pas d'extrait gratuit. "
                    "Procurez-vous l'ouvrage pour accéder à la lecture complète."
              : "Ce livre n'est pas encore dans votre bibliothèque.";
        } else {
          _loadError = "Aucun fichier disponible pour ce livre.";
        }
      });
      return;
    }

    setState(() {
      _isLoadingFile = false;
    });

    final String format = (widget.book['format'] ?? '')
        .toString()
        .toLowerCase();
    final bool isEpub =
        format == 'epub' || pdfUrl.toLowerCase().endsWith('.epub');

    try {
      // Rien sur le disque : l'aperçu et le manuscrit portent le même
      // identifiant de livre, d'où la distinction `extrait` — sans elle ils
      // s'écrasent l'un l'autre, et le lecteur qui vient d'acheter se voit
      // resservir les deux pages de l'aperçu.
      setState(() {
        _isDownloading = true;
        _downloadProgress = 0.0;
      });

      final bytes = await _bookCacheService.downloadAndCache(
        bookId,
        pdfUrl,
        extrait: widget.isExtrait,
        onProgress: (progress) {
          setState(() {
            _downloadProgress = progress;
          });
        },
      );

      if (bytes != null) {
        setState(() {
          _cachedBookBytes = bytes;
          _estEpub = isEpub;
          _isDownloading = false;
        });
        if (isEpub) {
          _epubController = EpubController(
            document: EpubDocument.openData(bytes),
          );
        }
      } else {
        setState(() {
          _loadError = "Erreur lors du téléchargement du livre.";
          _isDownloading = false;
        });
      }
    } catch (e) {
      setState(() {
        _loadError = messageLisible(
          e,
          repli: "Ce livre n'a pas pu être ouvert.",
        );
        _isDownloading = false;
      });
    }
  }

  /// Ouvre le livre déjà présent sur l'appareil. Rend `false` s'il n'y est pas.
  ///
  /// Aucun appel réseau : c'est tout l'intérêt. Le format se lit sur le fichier
  /// lui-même — son extension — et non sur une adresse qu'on n'a peut-être pas.
  Future<bool> _ouvrirDepuisLeCache(String bookId) async {
    final fichier = await _bookCacheService.fichierEnCache(
      bookId,
      extrait: widget.isExtrait,
    );
    if (fichier == null) return false;

    final bytes = await _bookCacheService.getCachedBookBytes(
      bookId,
      '',
      extrait: widget.isExtrait,
    );
    // Le fichier était là mais illisible : getCachedBookBytes vient de
    // l'effacer. On laisse le téléchargement reprendre la main.
    if (bytes == null) return false;

    final bool isEpub =
        fichier.path.toLowerCase().endsWith('.epub') ||
        (widget.book['format'] ?? '').toString().toLowerCase() == 'epub';

    if (!mounted) return true;
    setState(() {
      _cachedBookBytes = bytes;
      _estEpub = isEpub;
      _isLoadingFile = false;
      _isDownloading = false;
    });

    if (isEpub) {
      _epubController = EpubController(document: EpubDocument.openData(bytes));
    }
    return true;
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    // Load from local first for instant UI response
    _applyPrefs(prefs);

    // Then try to sync from backend
    try {
      final token = await TokenStorage.getToken();
      if (token != null) {
        final backendSettings = await _settingsService.getSettings(token);
        if (backendSettings != null) {
          setState(() {
            _backgroundColor = Color(backendSettings.readingBgColor);
            _brightness = backendSettings.brightness;
            // Sécurité : ne jamais avoir un zoom de 0 ou négatif
            _zoomLevel = backendSettings.zoomLevel > 0
                ? backendSettings.zoomLevel
                : 1.0;
            _isHorizontal = backendSettings.isHorizontal;
          });
          // Update local with backend data
          _saveToLocal(prefs);
        }
      }
    } catch (e) {}
  }

  void _applyPrefs(SharedPreferences prefs) {
    setState(() {
      _brightness = prefs.getDouble('reading_brightness') ?? 1.0;
      final bgColorHex = prefs.getInt('reading_bg_color');
      if (bgColorHex != null) {
        _backgroundColor = Color(bgColorHex);
      }
      _zoomLevel = prefs.getDouble('reading_zoom_level') ?? 1.0;
      if (_zoomLevel <= 0) _zoomLevel = 1.0; // Sécurité
      _isHorizontal = prefs.getBool('reading_is_horizontal') ?? false;
    });
  }

  Future<void> _saveToLocal(SharedPreferences prefs) async {
    await prefs.setDouble('reading_brightness', _brightness);
    await prefs.setInt('reading_bg_color', _backgroundColor.value);
    await prefs.setDouble('reading_zoom_level', _zoomLevel);
    await prefs.setBool('reading_is_horizontal', _isHorizontal);
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await _saveToLocal(prefs);

    // Sync to backend
    try {
      final token = await TokenStorage.getToken();
      if (token != null) {
        await _settingsService.saveSettings(
          ReadingSettings(
            readingBgColor: _backgroundColor.value,
            brightness: _brightness,
            zoomLevel: _zoomLevel,
            isHorizontal: _isHorizontal,
          ),
          token,
        );
      }
    } catch (e) {}
  }

  void _saveSettingsDebounced() {
    _settingsTimer?.cancel();
    _settingsTimer = Timer(const Duration(milliseconds: 500), () {
      _saveSettings();
    });
  }

  Future<void> _loadBookmarks() async {
    try {
      final token = await TokenStorage.getToken();
      final bookId = widget.book['id'] ?? widget.book['ID'];
      if (token != null && bookId != null) {
        final bks = await _bookmarkService.getBookmarksByLivre(bookId, token);
        if (mounted) {
          setState(() {
            _bookmarks = bks;
          });
        }
      }
    } catch (e) {}
  }

  Future<void> _loadProgress() async {
    // Et un extrait n'en relit pas davantage.
    //
    // La progression appartient au livre entier ; l'appliquer a un extrait de
    // dix pages fait sauter n'importe ou. Un extrait s'ouvre toujours a sa
    // premiere page — c'est un debut de lecture, pas une reprise.
    if (widget.isExtrait) return;

    // Si on a déjà une page initiale, on ne surcharge pas le réseau
    if (_savedPage != null && _savedPage! > 0) return;

    try {
      final token = await TokenStorage.getToken();
      if (token != null) {
        final bookId = widget.book['id'] ?? widget.book['ID'];
        // Utilisation de la méthode correcte confirmée par le backend
        final progress = await _progressService.getProgressByLivre(
          bookId,
          token,
        );
        if (progress != null && mounted) {
          setState(() {
            _savedPage = progress.lastPage > 0
                ? progress.lastPage
                : progress.chapitreCourant;
          });
          // Si le document est déjà chargé, on saute maintenant
          if (_isDocumentLoaded &&
              _savedPage! > 0 &&
              _savedPage! <= _totalPages) {
            _pdfViewerController.jumpToPage(_savedPage!);
          }
        }
      }
    } catch (e) {}
  }

  Future<void> _saveProgress(int page) async {
    try {
      final token = await TokenStorage.getToken();
      final bookId = widget.book['id'] ?? widget.book['ID'];
      if (token != null && bookId != null && _totalPages > 0) {
        await _progressService.updateReadingProgress(
          livreId: bookId,
          currentPage: page,
          totalPages: _totalPages,
          authToken: token,
        );
      }
    } catch (e) {}
  }

  /// Secondes déjà comptées localement mais pas encore déclarées au serveur.
  ///
  /// Le compteur de secondes en attente ne vit plus ici.
  ///
  /// C'était un champ d'instance : il mourait avec la page. Fermer un livre sur
  /// quarante secondes en attente les effaçait, et une session lue sans réseau
  /// était perdue en entier. [MinutesEnAttente] le garde sur l'appareil et le
  /// renvoie tant que le serveur ne l'a pas accepté.

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      final now = DateTime.now();
      final elapsedSec = _lastHeartbeatTick != null
          ? now.difference(_lastHeartbeatTick!).inSeconds
          : 15;
      _lastHeartbeatTick = now;

      final bookId = (widget.book['id'] ?? widget.book['ID'] ?? '').toString();

      if (elapsedSec > 0) {
        ReadingTimeStorage.addReadingSeconds(
          bookId: bookId.isNotEmpty ? bookId : null,
          seconds: elapsedSec,
        );
        if (bookId.isNotEmpty) {
          _declarerAuServeur(bookId, elapsedSec);
        }
      }
    });
  }

  /// Déclare le temps de lecture au serveur, en minutes entières.
  ///
  /// Le battement est passé de soixante à quinze secondes sans que le corps de
  /// la requête change : l'application annonçait « une minute » quatre fois par
  /// minute, et le temps de lecture de chaque livre était multiplié par quatre
  /// dans les statistiques de l'auteur. D'où le passage par un solde.
  ///
  /// Deux destinations, deux usages : par livre pour les statistiques de
  /// l'auteur, par lecteur pour son temps cumulé et sa série de jours. Chacune
  /// a son propre solde — l'une peut échouer sans faire renvoyer l'autre.
  void _declarerAuServeur(String bookId, int secondes) {
    unawaited(MinutesEnAttente.porter(livreId: bookId, secondes: secondes));
  }

  void _onPageChanged(int page) {
    // Aucune limite de pages n'est appliquee ici.
    //
    // Le serveur ne livre pas le manuscrit a qui n'a pas achete : il envoie le
    // fichier d'extrait, qui ne contient deja que les pages offertes — dix par
    // defaut, reglables par EXTRAIT_NB_PAGES. L'application posait par-dessus
    // une seconde barriere a la page 2, ecrite en dur : huit des dix pages que
    // l'auteur offre etaient inaccessibles, et changer EXTRAIT_NB_PAGES ne
    // changeait rien.
    //
    // La proposition d'achat arrive maintenant a la derniere page de l'extrait,
    // c'est-a-dire quand le lecteur a vraiment tout vu.

    setState(() {
      _currentPage = page;
    });
    _proposerAchatSiFinDExtrait(page);
    // Un extrait n'ecrit JAMAIS de progression.
    //
    // Cette sauvegarde-ci n'etait pas gardee, alors que celle de la sortie
    // l'etait. Lire les dix pages d'un extrait enregistrait donc « page 9 sur
    // 10 » sur le LIVRE — dont les pages n'ont rien a voir. Deux consequences,
    // et la seconde est pire :
    //
    //   - rouvrir l'extrait sautait directement a la page 9, celle ou la
    //     proposition d'achat s'affiche ;
    //   - le livre etait annonce lu a 90 %, pour quelqu'un qui ne l'a pas
    //     achete. Le jour ou il l'achete, il s'ouvre a sa page 9 sur trois
    //     cents.
    if (!widget.isExtrait) {
      _saveTimer?.cancel();
      _saveTimer = Timer(const Duration(seconds: 2), () {
        _saveProgress(page);
      });
    }

    if (_ttsService.isPlaying || _enchainerSurLaPageSuivante) {
      _enchainerSurLaPageSuivante = false;
      _speakCurrentPage();
    } else if (_ttsService.isPaused) {
      // Le lecteur a mis en pause, puis tourné la page à la main. Les segments
      // gardés par le service sont ceux de la page qu'il vient de quitter :
      // reprendre lui relirait la page précédente. On repart donc de zéro, et
      // le bouton lecture dira la page qu'il a sous les yeux.
      _ttsService.stop();
    }
  }

  /// Propose l'achat quand l'extrait est termine.
  ///
  /// Une seule fois par ouverture : reproposer a chaque changement de page
  /// transformerait la fin de l'extrait en mur infranchissable.
  void _proposerAchatSiFinDExtrait(int page) {
    if (!widget.isExtrait || _achatDejaPropose) return;
    if (_totalPages <= 0 || page < _totalPages) return;
    _achatDejaPropose = true;
    _showExtraitLimitDialog();
  }

  /// La fin de l'extrait, et ce qu'on peut en faire.
  ///
  /// C'etait un AlertDialog avec ses deux boutons en ligne. « Acheter l'œuvre »
  /// est long : sur un ecran etroit il sortait du cadre, et l'action la plus
  /// importante de cet ecran s'affichait tronquee. AlertDialog ne replie ses
  /// actions qu'en dernier recours, et sans maitrise de leur largeur.
  ///
  /// Un Dialog compose a la main les pose donc pleine largeur, empilees :
  /// l'achat d'abord, puis la sortie. Le prix figure sur le bouton — c'est la
  /// question que se pose le lecteur a cet instant, et l'obliger a fermer pour
  /// aller la chercher ailleurs coute une vente.
  void _showExtraitLimitDialog() {
    final prix = widget.book['prix'] ?? widget.book['price'];
    final prixTexte = (prix is num && prix > 0)
        ? "Acheter — $prix FCFA"
        : "Acheter l'œuvre";

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        AppColors.suivreLeTheme(context);
        return Dialog(
          backgroundColor: AppColors.cardBackground,
          insetPadding: const EdgeInsets.symmetric(horizontal: 32),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.lock_outline_rounded,
                    color: AppColors.accentInk,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  "Fin de l'extrait",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 10),
                // Le message citait « 2 pages maximum par defaut ». L'extrait
                // en compte dix, et ce nombre reste reglable : l'ecrire ici le
                // condamne a vieillir en silence.
                Text(
                  "Vous avez lu tout l'extrait offert. La suite vous attend "
                  "dans l'œuvre complète.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: AppColors.textSecondary,
                    fontSize: 13.5,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _lancerPaiementDepuisExtrait();
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
                    child: Text(
                      prixTexte,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    "Continuer sans acheter",
                    style: GoogleFonts.poppins(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _lancerPaiementDepuisExtrait() async {
    final rawPrix = widget.book['prix'];
    final double amount = (rawPrix is num)
        ? rawPrix.toDouble()
        : double.tryParse(rawPrix?.toString() ?? '0') ?? 0.0;

    if (amount <= 0) return;

    try {
      final token = await TokenStorage.getToken();
      if (token == null) {
        if (mounted) {
          AppNotifications.showSnackBar(
            context,
            message: "Veuillez vous connecter pour acheter ce livre",
            isError: true,
          );
        }
        return;
      }

      final user = await AuthService().getUser(token);
      final paymentService = PaymentService();
      final result = await paymentService.initiateCinetpayPayment(
        livreId: widget.book['id']?.toString() ?? '',
        montant: amount,
        authToken: token,
        customerName: user?.nomComplet.isNotEmpty == true
            ? user!.nomComplet
            : "Lecteur SpaceLearn",
        customerEmail: user?.email.isNotEmpty == true
            ? user!.email
            : "client@spacelearn.com",
      );

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CinetpayWebViewPage(
            paymentUrl: result.paymentUrl,
            transactionId: result.paiement.transactionId,
            book: widget.book,
            montant: amount,
          ),
        ),
      );
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
    }
  }

  Future<void> _toggleBookmark() async {
    try {
      final token = await TokenStorage.getToken();
      final bookId = widget.book['id'] ?? widget.book['ID'];
      if (token != null && bookId != null) {
        await _bookmarkService.createBookmark(
          livreId: bookId,
          page: _currentPage,
          chapitre: 1, // Par défaut chapitre 1 pour l'instant
          label: "Marque-page à la page $_currentPage",
          authToken: token,
        );
        if (mounted) {
          AppNotifications.showSnackBar(
            context,
            message: 'Marque-page ajouté à la page $_currentPage',
            isSuccess: true,
          );
        }
      }
    } catch (e) {}
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    if (_currentPage > 0 && _totalPages > 0 && !widget.isExtrait) {
      _saveProgress(_currentPage);
    }
    final now = DateTime.now();
    final bookId = (widget.book['id'] ?? widget.book['ID'] ?? '').toString();
    if (_lastHeartbeatTick != null) {
      final elapsedSec = now.difference(_lastHeartbeatTick!).inSeconds;
      if (elapsedSec > 0) {
        ReadingTimeStorage.addReadingSeconds(
          bookId: bookId.isNotEmpty ? bookId : null,
          seconds: elapsedSec,
        );
        if (bookId.isNotEmpty) {
          _declarerAuServeur(bookId, elapsedSec);
        }
      }
    }
    if (_sessionStartTime != null) {
      final totalSessionSec = now.difference(_sessionStartTime!).inSeconds;
      if (totalSessionSec >= 5) {
        final bookTitle =
            (widget.book['titre'] ??
                    widget.book['Titre'] ??
                    widget.book['title'] ??
                    'Livre')
                .toString();
        ReadingTimeStorage.recordSession(
          bookId: bookId,
          bookTitle: bookTitle,
          durationSeconds: totalSessionSec,
        );
      }
    }
    _heartbeatTimer?.cancel();
    _settingsTimer?.cancel();
    _pdfViewerController.dispose();
    _epubController?.dispose();
    _ttsService.removeListener(_onTtsStateChanged);
    // Le service est un singleton : le rappel posé en initState lui survit et
    // resterait branché sur un écran détruit, dont il piloterait le contrôleur
    // de PDF déjà libéré.
    _ttsService.onCompletion = null;
    _ttsService.stop();
    // Rendre l'ecran a son comportement normal.
    WakelockPlus.disable();
    super.dispose();
  }

  void _updateChapterTitle(int pageNumber) {
    if (_pdfBookmarks.isEmpty) return;

    String foundTitle = _currentChapterTitle;
    for (var bookmark in _pdfBookmarks) {
      final int? bookmarkPage = _bookmarkPageMap[bookmark.title];
      if (bookmarkPage != null && bookmarkPage <= pageNumber) {
        foundTitle = bookmark.title;
      }
    }
    if (foundTitle != _currentChapterTitle) {
      setState(() {
        _currentChapterTitle = foundTitle;
      });
    }
  }

  /// Vrai entre la fin d'une page et le début de la suivante, en lecture suivie.
  ///
  /// Sans lui, la lecture automatique tournait la page puis se taisait. La
  /// raison tient à l'ordre des opérations dans le service : `_dire()` remet
  /// l'état à `stopped` AVANT d'appeler `onCompletion`. Quand la page changeait
  /// et que `_onPageChanged` demandait « le service lit-il encore ? », la
  /// réponse était non, et personne ne relançait la voix. Le lecteur devait
  /// rappuyer sur lecture à chaque page — c'est-à-dire renoncer à écouter son
  /// livre sans toucher l'écran, qui est tout l'objet de la fonction.
  bool _enchainerSurLaPageSuivante = false;

  void _onTtsCompletion() {
    if (_autoplayNextPage && _currentPage < _totalPages) {
      _enchainerSurLaPageSuivante = true;
      _pdfViewerController.nextPage();
    } else {
      _ttsService.stop();
    }
  }

  void _onTtsStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _speakCurrentPage() async {
    if (!_isDocumentLoaded) return;

    String textToRead = "";

    if (_isPdf && _pdfDocument != null) {
      setState(() {
        _isExtractingText = true;
      });
      try {
        final text = PdfTextExtractor(_pdfDocument!).extractText(
          startPageIndex: _currentPage - 1,
          endPageIndex: _currentPage - 1,
        );
        // Retire le numero de page et recolle les mots coupes en fin de
        // ligne, qui se disaient jusqu'ici en deux morceaux.
        textToRead = texteDepuisPdf(text);
      } catch (e) {
        debugPrint("Erreur lors de l'extraction de texte PDF: $e");
      } finally {
        if (mounted) {
          setState(() {
            _isExtractingText = false;
          });
        }
      }
    } else if (!_isPdf && _epubController != null) {
      setState(() {
        _isExtractingText = true;
      });
      try {
        final value = _epubController!.currentValue;
        if (value != null && value.chapter != null) {
          final htmlContent = value.chapter!.HtmlContent ?? '';
          // Le nettoyage tenait en un retrait des balises : le contenu des
          // <style> se lisait a voix haute, les entites se prononcaient, et
          // les paragraphes disparaissaient — donc aucune respiration.
          textToRead = texteDepuisHtml(htmlContent);
        }
      } catch (e) {
        debugPrint("Erreur lors de l'extraction de texte EPUB: $e");
      } finally {
        if (mounted) {
          setState(() {
            _isExtractingText = false;
          });
        }
      }
    }

    if (textToRead.trim().isEmpty) {
      if (mounted) {
        AppNotifications.showSnackBar(
          context,
          message: "Aucun texte lisible trouvé sur cette page.",
          isError: true,
        );
      }
      return;
    }

    await _ttsService.speak(textToRead);
  }

  /// Un nom de voix lisible.
  ///
  /// Les moteurs renvoient des identifiants — « fr-fr-x-frd-local »,
  /// « fr-FR-language ». On en tire le pays et un numero d'ordre : c'est peu,
  /// mais c'est deja plus qu'une chaine technique dans une liste de choix.
  String _nomLisibleVoix(Map<String, String> voix) {
    final locale = (voix['locale'] ?? '').toLowerCase();
    final pays = locale.startsWith('fr-ca')
        ? 'Canada'
        : locale.startsWith('fr-be')
        ? 'Belgique'
        : locale.startsWith('fr-ch')
        ? 'Suisse'
        : 'France';

    final rang = _ttsService.voixDisponibles.indexOf(voix) + 1;
    return 'Voix $rang · $pays';
  }

  /// Ce qui distingue vraiment deux voix.
  ///
  /// Six entrees nommees « Français (France) — voix N », toutes « Qualité
  /// élevée », ne se distinguent pas : on ne peut pas choisir. L'identifiant
  /// du moteur, lui, differe toujours — c'est laid, mais c'est la seule chose
  /// qui separe deux lignes tant qu'on ne les a pas entendues.
  String _qualiteLisible(Map<String, String> voix) {
    final identifiant = (voix['name'] ?? '').trim();
    final qualite = switch ((voix['quality'] ?? '').toLowerCase()) {
      'very high' => 'très élevée',
      'high' => 'élevée',
      'low' || 'very low' => 'réduite',
      _ => 'standard',
    };
    if (identifiant.isEmpty) return 'Qualité $qualite';
    return '$identifiant · qualité $qualite';
  }

  Widget _buildTtsPlayerPanel() {
    // Le panneau flotte AU-DESSUS de la page, il n'est pas dedans : son encre
    // doit venir de sa propre surface.
    //
    // Elle venait de la luminance de _backgroundColor — le fond du livre,
    // réglé séparément par « Fond de page ». Les deux référentiels n'ont aucun
    // rapport, et se croisaient dans les deux configurations les plus
    // courantes. Thème sombre avec le fond parchemin, qui est le réglage par
    // défaut : encre readingBrown #4A3728 sur panneau cardDark #1A1A1A, soit
    // 1,42:1. Thème clair avec le fond « Nuit » : blanc sur cardLight #FFFFFF,
    // soit 1:1. Le panneau s'affichait bien, entièrement illisible — d'où
    // « je ne vois pas la partie audio ».
    final Color panelBg = AppColors.cardBackground.withValues(alpha: 0.95);
    final Color itemColor = AppColors.textPrimary;

    return Positioned(
      bottom: 24,
      left: 24,
      right: 24,
      child: Container(
        padding: const EdgeInsets.all(16),
        // En paysage, ou chez un lecteur ayant grossi la police du système, le
        // panneau dépassait la hauteur disponible. Le Stack le rognait par le
        // haut, sans bandes de débordement et sans rien dire — et ce qui
        // disparaissait en premier était l'explication « aucune voix française
        // installée », c'est-à-dire le message destiné à la seule personne qui
        // en avait besoin. Il défile maintenant à l'intérieur de sa carte.
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        decoration: BoxDecoration(
          color: panelBg,
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // L'etat de la voix, quand il empeche de lire.
              //
              // Le service resolvait deja une voix francaise au demarrage et
              // exposait le resultat, mais aucun ecran ne le lisait : sur un
              // appareil sans voix francaise, appuyer sur lecture ne produisait
              // rien du tout. Un silence n'apprend rien a celui qui attend.
              if (_ttsService.etatVoix != EtatVoix.ok &&
                  _ttsService.etatVoix != EtatVoix.inconnu)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 18,
                        color: AppColors.warning,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _ttsService.etatVoix == EtatVoix.moteurIndisponible
                              ? "Votre appareil n'a pas de moteur de synthèse "
                                    "vocale. La lecture à voix haute ne peut pas "
                                    "fonctionner."
                              : "Aucune voix française n'est installée sur votre "
                                    "appareil. Ajoutez-la dans Paramètres › "
                                    "Accessibilité › Synthèse vocale — un "
                                    "téléchargement unique, de préférence en "
                                    "Wi-Fi.",
                          style: GoogleFonts.poppins(
                            color: itemColor,
                            fontSize: 12,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _ttsService.isPlaying
                              ? (_isPdf
                                    ? "Lecture en cours - Page $_currentPage"
                                    : "Lecture en cours - $_currentChapterTitle")
                              : _ttsService.isPaused
                              ? "Lecture en pause"
                              : "Synthèse vocale prête",
                          style: GoogleFonts.poppins(
                            color: _ttsService.isPlaying
                                ? AppColors.accentInk
                                : itemColor.withOpacity(0.7),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          _isExtractingText
                              ? "Extraction du texte..."
                              : widget.book['titre'] ?? "Livre",
                          style: GoogleFonts.lora(
                            color: itemColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          _autoplayNextPage
                              ? Icons.autorenew
                              : Icons.play_disabled,
                          color: _autoplayNextPage
                              ? AppColors.accentInk
                              : itemColor.withOpacity(0.4),
                          size: 20,
                        ),
                        tooltip: "Lecture automatique",
                        onPressed: () {
                          setState(() {
                            _autoplayNextPage = !_autoplayNextPage;
                          });
                        },
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        // Les paliers etaient compares par egalite de nombres a
                        // virgule — fragile — et codes en dur jusqu'a 1.0, ce
                        // qui vaut le double de la vitesse normale sur Android
                        // mais le plafond dur d'iOS, bien plus rapide encore.
                        // On avance par index, et on s'arrete au plafond que
                        // l'appareil declare.
                        onPressed: () =>
                            _ttsService.setRate(_vitesseSuivante()),
                        child: Text(
                          _getSpeedLabel(_ttsService.speechRate),
                          style: GoogleFonts.poppins(
                            color: AppColors.accentInk,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 16),
              if (_ttsService.isPlaying)
                Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: _TtsAudioWaveform(color: AppColors.accentInk),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: Icon(Icons.skip_previous, color: itemColor, size: 28),
                    onPressed: () {
                      if (_isPdf) {
                        if (_currentPage > 1) {
                          _pdfViewerController.previousPage();
                        }
                      } else if (_epubController != null) {
                        final toc = _epubController!.tableOfContents();
                        final currentChapterIdx =
                            (_epubController!.currentValue?.chapterNumber ??
                                1) -
                            1;
                        if (currentChapterIdx - 1 >= 0 &&
                            currentChapterIdx - 1 < toc.length) {
                          final prevChapter = toc[currentChapterIdx - 1];
                          _epubController!.jumpTo(
                            index: prevChapter.startIndex,
                          );
                        }
                      }
                    },
                  ),
                  GestureDetector(
                    onTap: () {
                      // Sans voix utilisable, l'appui ne produisait rien : le
                      // service sortait sans parler et sans rien dire. On
                      // repete l'explication plutot que de laisser croire a une
                      // panne.
                      if (!_ttsService.voixFrancaiseDisponible) {
                        AppNotifications.showSnackBar(
                          context,
                          message:
                              _ttsService.etatVoix ==
                                  EtatVoix.moteurIndisponible
                              ? "Aucun moteur de synthèse vocale sur cet appareil."
                              : "Installez une voix française dans les réglages "
                                    "de votre appareil pour écouter les livres.",
                          isError: true,
                        );
                        return;
                      }

                      // La reprise appelait _speakCurrentPage(), qui relisait
                      // la page depuis le haut : le stop() en tete de speak()
                      // effacait la position memorisee. resume() reprend au
                      // segment en cours.
                      if (_ttsService.isPlaying) {
                        _ttsService.pause();
                      } else if (_ttsService.isPaused) {
                        _ttsService.resume();
                      } else {
                        _speakCurrentPage();
                      }
                    },
                    child: Container(
                      height: 56,
                      width: 56,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: _isExtractingText
                          ? Center(
                              child: SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  color: AppColors.onAccent,
                                  strokeWidth: 2.5,
                                ),
                              ),
                            )
                          : Icon(
                              _ttsService.isPlaying
                                  ? Icons.pause
                                  : Icons.play_arrow,
                              color: AppColors.onAccent,
                              size: 32,
                            ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.stop,
                      color: _ttsService.isStopped
                          ? itemColor.withOpacity(0.4)
                          : itemColor,
                      size: 28,
                    ),
                    onPressed: _ttsService.isStopped
                        ? null
                        : () {
                            _ttsService.stop();
                          },
                  ),
                  IconButton(
                    icon: Icon(Icons.skip_next, color: itemColor, size: 28),
                    onPressed: () {
                      if (_isPdf) {
                        if (_currentPage < _totalPages) {
                          _pdfViewerController.nextPage();
                        }
                      } else if (_epubController != null) {
                        final toc = _epubController!.tableOfContents();
                        final currentChapterIdx =
                            (_epubController!.currentValue?.chapterNumber ??
                                1) -
                            1;
                        if (currentChapterIdx + 1 < toc.length) {
                          final nextChapter = toc[currentChapterIdx + 1];
                          _epubController!.jumpTo(
                            index: nextChapter.startIndex,
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Paliers de vitesse, en multiples de la vitesse normale.
  ///
  /// Ce sont bien des multiplicateurs : l'echelle de flutter_tts place la
  /// vitesse normale a 0,5, et le service convertit. Le plafond depend de
  /// l'appareil — Android accepte jusqu'a trois fois la vitesse normale, iOS
  /// ecrete au double sans le signaler — d'ou le filtre sur ce que le service
  /// a lu au demarrage.
  static const List<double> _multiplicateurs = [0.8, 1.0, 1.2, 1.5, 2.0];

  List<double> get _paliers => _multiplicateurs
      .map((m) => m * TtsService.vitesseNormale)
      .where((v) => v <= _ttsService.vitesseMax + 0.001)
      .toList();

  double _vitesseSuivante() {
    final paliers = _paliers;
    if (paliers.isEmpty) return TtsService.vitesseNormale;
    // Comparaison par proximite : l'egalite entre nombres a virgule est
    // fragile, et 0.75 ne se compare pas fiablement a lui-meme.
    var index = 0;
    var ecartMin = double.infinity;
    for (var i = 0; i < paliers.length; i++) {
      final ecart = (paliers[i] - _ttsService.speechRate).abs();
      if (ecart < ecartMin) {
        ecartMin = ecart;
        index = i;
      }
    }
    return paliers[(index + 1) % paliers.length];
  }

  String _getSpeedLabel(double rate) {
    final multiplicateur = rate / TtsService.vitesseNormale;
    return "${multiplicateur.toStringAsFixed(1)}x";
  }

  @override
  Widget build(BuildContext context) {
    AppColors.suivreLeTheme(context);
    final String? pdfUrl =
        widget.book['fichier_url'] ?? widget.book['fichierUrl'];
    final String? imageUrl =
        widget.book['image_couverture'] ?? widget.book['imageCouverture'];

    final String format = (widget.book['format'] ?? '')
        .toString()
        .toLowerCase();
    final bool isPdf =
        format == 'pdf' ||
        (pdfUrl != null && pdfUrl.toLowerCase().endsWith('.pdf'));

    if (_isPdf != isPdf) {
      Future.microtask(() => setState(() => _isPdf = isPdf));
    }

    return Scaffold(
      backgroundColor: _backgroundColor,
      drawer: _buildDrawer(),
      body: Stack(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => setState(() => _showControls = !_showControls),
            child: _buildBody(pdfUrl, imageUrl, isPdf),
          ),

          // Voile d'assombrissement, pour lire dans le noir.
          //
          // Le reglage existait deja — charge des preferences, envoye au
          // serveur — mais aucune commande ne permettait de l'atteindre, et il
          // s'appliquait en Opacity sur le contenu : le texte devenait
          // translucide et se delavait sur le fond, au lieu de s'assombrir.
          //
          // Un voile noir par-dessus assombrit vraiment, sans toucher au
          // contraste entre le texte et sa page. Il ne peut pas eclaircir
          // au-dela du reglage systeme — c'est la limite de l'approche, mais
          // elle ne demande aucune permission.
          if (_brightness < 1.0)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: Colors.black.withValues(
                    alpha: (1.0 - _brightness) * 0.72,
                  ),
                ),
              ),
            ),

          // Header Layer (Solid)
          if (!_showCover && _showControls) _buildHeader(),

          if (_isSearching) _buildSearchBar(),

          // Footer Layer (Solid)
          if (!_showCover &&
              _showControls &&
              _isDocumentLoaded &&
              !_showTtsPanel)
            _buildBottomControls(),

          // Panneau de contrôle Audio (TTS)
          //
          // Il ne dépend plus de _showControls tant qu'une voix parle. Une tape
          // sur la page — pour tourner, ou par simple prise en main — effaçait
          // la barre d'outils et, avec elle, le panneau : la lecture continuait
          // et il ne restait plus rien à l'écran pour la mettre en pause. Une
          // lecture en cours est un état du livre, pas du mobilier d'interface.
          if (!_showCover &&
              _isDocumentLoaded &&
              _showTtsPanel &&
              (_showControls || !_ttsService.isStopped))
            _buildTtsPlayerPanel(),

          // Close button if no cover
          if (_showCover)
            Positioned(
              top: 50,
              left: 20,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.close,
                    color: AppColors.readingBrown,
                    size: 20,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Ce qu'on regarde en attendant que le livre s'ouvre.
  ///
  /// L'ecran disait « Chargement du livre… » sous un nuage, et rien d'autre :
  /// ni QUEL livre — on venait pourtant d'appuyer sur son titre — ni ou en
  /// etait le telechargement, alors que le pourcentage est connu a chaque
  /// octet. Une barre qui avance sans chiffre, sur un ecran anonyme, ne dit pas
  /// si l'on attend trois secondes ou trois minutes.
  ///
  /// Il ne distinguait pas non plus les deux attentes. Ouvrir un livre deja
  /// telecharge ne prend qu'un instant ; le rapatrier depuis le serveur peut
  /// durer sur un forfait mobile. Les annoncer du meme mot fait redouter la
  /// seconde a chaque fois qu'on ouvre un livre.
  Widget _ecranDOuverture(String? imageUrl) {
    final bool sombre = _backgroundColor.computeLuminance() < 0.5;
    final Color couleurTexte = sombre ? Colors.white : AppColors.readingBrown;
    final Color couleurDiscrete = couleurTexte.withValues(alpha: 0.6);

    final String titre = (widget.book['titre'] ?? widget.book['title'] ?? '')
        .toString()
        .trim();
    final String auteur =
        (widget.book['auteur_nom'] ??
                widget.book['auteurNom'] ??
                widget.book['auteur'] ??
                '')
            .toString()
            .trim();

    final bool telechargement = _isDownloading;
    final int pourcent = (_downloadProgress * 100).round();

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _couvertureEnAttente(imageUrl, titre, couleurTexte),
            const SizedBox(height: 28),

            if (titre.isNotEmpty)
              Text(
                titre,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: couleurTexte,
                ),
              ),
            if (auteur.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                auteur,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: couleurDiscrete,
                ),
              ),
            ],

            const SizedBox(height: 28),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
              child: LinearProgressIndicator(
                value: telechargement && _downloadProgress > 0
                    ? _downloadProgress
                    : null,
                minHeight: 5,
                backgroundColor: couleurTexte.withValues(alpha: 0.12),
                color: AppColors.accentInk,
              ),
            ),
            const SizedBox(height: 12),

            Text(
              telechargement
                  ? (_downloadProgress > 0
                        ? "Téléchargement… $pourcent %"
                        : "Téléchargement…")
                  : "Ouverture…",
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: couleurTexte,
              ),
            ),

            // La promesse qui rend l'attente acceptable : elle n'aura lieu
            // qu'une fois. Inutile de la faire quand le livre est deja la.
            if (telechargement) ...[
              const SizedBox(height: 6),
              Text(
                "Ce livre restera disponible hors connexion.",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: couleurDiscrete,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// La couverture, ou un carton a son initiale.
  Widget _couvertureEnAttente(
    String? imageUrl,
    String titre,
    Color couleurTexte,
  ) {
    final adresse = ApiRoutes.sanitizeImageUrl(imageUrl, useGin: true);

    return Container(
      width: 118,
      height: 168,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        color: AppColors.accentInk.withValues(alpha: 0.10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: adresse != null
          ? Image.network(
              adresse,
              fit: BoxFit.cover,
              // Une couverture qui ne se charge pas ne doit pas laisser un
              // rectangle casse : le carton a l'initiale prend le relais.
              errorBuilder: (_, _, _) => _cartonInitiale(titre, couleurTexte),
            )
          : _cartonInitiale(titre, couleurTexte),
    );
  }

  Widget _cartonInitiale(String titre, Color couleurTexte) {
    return Center(
      child: Text(
        titre.isNotEmpty ? titre.substring(0, 1).toUpperCase() : "?",
        style: GoogleFonts.poppins(
          fontSize: 44,
          fontWeight: FontWeight.bold,
          color: AppColors.accentInk,
        ),
      ),
    );
  }

  Widget _buildBody(String? pdfUrl, String? imageUrl, bool isPdf) {
    if (_isLoadingFile || _isDownloading) {
      return _ecranDOuverture(imageUrl);
    }

    if (_loadError != null) {
      return _buildErrorView(_loadError!);
    }

    // Le fichier chargé fait foi, pas son adresse.
    //
    // `fichier_url` est signée pour quinze minutes : elle manque dès qu'on
    // ouvre un livre sans réseau. Cette méthode refusait alors d'afficher un
    // manuscrit pourtant déjà en mémoire, et annonçait « Aucun fichier
    // disponible pour ce livre » sur un ouvrage posé sur l'appareil.
    if (_cachedBookBytes == null) {
      if (pdfUrl == null || pdfUrl.isEmpty) {
        return _buildErrorView("Aucun fichier disponible pour ce livre.");
      }

      final String format = (widget.book['format'] ?? '')
          .toString()
          .toLowerCase();
      final bool isEpub =
          format == 'epub' || pdfUrl.toLowerCase().endsWith('.epub');

      if (!isPdf && !isEpub) {
        // For demonstration of the UI if not a PDF, we show dummy text that looks like the mockup
        return _buildMockEbookContent();
      }

      return const Center(child: CircularProgressIndicator());
    }

    if (_estEpub) {
      if (_epubController == null) {
        return Center(child: CircularProgressIndicator());
      }

      final isDark = _backgroundColor.computeLuminance() < 0.5;
      final Color textColor = isDark ? Colors.white : AppColors.readingBrown;

      return Container(
        color: _backgroundColor,
        child: Theme(
          data: Theme.of(context).copyWith(
            textTheme: TextTheme(
              bodyMedium: GoogleFonts.lora(
                fontSize: 16.0 * _zoomLevel,
                color: textColor,
                height: 1.5,
              ),
              bodyLarge: GoogleFonts.lora(
                fontSize: 18.0 * _zoomLevel,
                color: textColor,
                height: 1.5,
              ),
              bodySmall: GoogleFonts.lora(
                fontSize: 14.0 * _zoomLevel,
                color: textColor,
                height: 1.5,
              ),
            ),
          ),
          child: EpubView(
            controller: _epubController!,
            onDocumentLoaded: (document) {
              if (mounted) {
                setState(() {
                  _isDocumentLoaded = true;
                  _totalPages = document.Chapters?.length ?? 0;
                });
              }
            },
            onChapterChanged: (value) {
              if (mounted && value != null && value.chapter != null) {
                setState(() {
                  _currentChapterTitle = value.chapter!.Title ?? '';
                });

                if (_ttsService.isPlaying) {
                  _speakCurrentPage();
                }
              }
            },
          ),
        ),
      );
    }

    return SfPdfViewer.memory(
      _cachedBookBytes!,
      key: _pdfViewerKey,
      controller: _pdfViewerController,
      pageLayoutMode: PdfPageLayoutMode.single,
      // La correspondance etait inversee : « Horizontal » donnait un
      // defilement vertical, et inversement. Le reglage faisait donc le
      // contraire de ce qu'il annoncait, et le lecteur qui cherchait a
      // corriger le sens l'inversait une seconde fois.
      scrollDirection: _isHorizontal
          ? PdfScrollDirection.horizontal
          : PdfScrollDirection.vertical,
      enableDoubleTapZooming: true,
      onDocumentLoaded: (PdfDocumentLoadedDetails details) {
        if (mounted) {
          final List<PdfBookmark> bks = [];
          final Map<String, int> pageMap = {};

          for (int i = 0; i < details.document.bookmarks.count; i++) {
            final bookmark = details.document.bookmarks[i];
            bks.add(bookmark);
            if (bookmark.destination != null) {
              pageMap[bookmark.title] =
                  details.document.pages.indexOf(bookmark.destination!.page) +
                  1;
            }
          }

          setState(() {
            _pdfDocument = details.document;
            _pdfBookmarks = bks;
            _bookmarkPageMap = pageMap;
            _totalPages = details.document.pages.count;
            _isDocumentLoaded = true;
          });

          if (_savedPage != null &&
              _savedPage! > 0 &&
              _savedPage! <= _totalPages) {
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted) {
                _pdfViewerController.jumpToPage(_savedPage!);
                _updateChapterTitle(_savedPage!);
              }
            });
          }
        }
      },
      onPageChanged: (PdfPageChangedDetails details) {
        if (mounted) {
          _onPageChanged(details.newPageNumber);
          _updateChapterTitle(details.newPageNumber);
        }
      },
    );
  }

  Widget _buildHeader() {
    final bool isDark = _backgroundColor.computeLuminance() < 0.5;
    final Color textColor = isDark ? Colors.white : AppColors.readingBrown;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top,
          left: 10,
          right: 10,
          bottom: 10,
        ),
        decoration: BoxDecoration(color: _backgroundColor),
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back_ios_new, color: textColor, size: 20),
              onPressed: () => Navigator.of(context).pop(),
            ),
            Builder(
              builder: (context) => IconButton(
                icon: Icon(Icons.menu, color: textColor),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    _currentChapterTitle.toUpperCase(),
                    style: GoogleFonts.lora(
                      color: textColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            SizedBox(width: 8),
            IconButton(
              icon: Icon(
                _showTtsPanel ? Icons.headphones : Icons.headphones_outlined,
                color: _showTtsPanel
                    ? AppColors.accentInk
                    : textColor.withOpacity(0.7),
              ),
              onPressed: () {
                setState(() {
                  _showTtsPanel = !_showTtsPanel;
                });
              },
            ),
            SizedBox(width: 8),
            IconButton(
              icon: Icon(
                _backgroundColor.computeLuminance() < 0.5
                    ? Icons.wb_sunny_outlined
                    : Icons.nightlight_round_outlined,
                color: textColor.withOpacity(0.7),
              ),
              onPressed: _showSettingsModal,
            ),
          ],
        ),
      ),
    );
  }

  /// Une fleche de page, eteinte quand il n'y a plus rien de ce cote.
  ///
  /// Eteinte plutot qu'absente : une commande qui disparait deplace celles
  /// d'a cote, et l'oeil doit les retrouver a chaque tournee.
  Widget _flechePage({
    required IconData icone,
    required Color couleur,
    required bool actif,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: actif ? onTap : null,
      borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(
          icone,
          size: 20,
          color: actif ? couleur : couleur.withValues(alpha: 0.25),
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    final bool isDark = _backgroundColor.computeLuminance() < 0.5;
    final Color textColor = isDark ? Colors.white : AppColors.readingBrown;

    return Positioned(
      bottom: 24,
      left: 24,
      right: 24,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tourner la page, sans avoir a le deviner.
          //
          // Le compteur ne faisait qu'afficher « PAGE 1 SUR 10 » : rien
          // n'indiquait comment atteindre la deuxieme. Il fallait glisser
          // lateralement, geste qu'aucun element de l'ecran ne suggerait — et
          // que le reglage du sens de lecture contredisait. Les deux fleches
          // encadrent maintenant le compteur.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _backgroundColor.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _flechePage(
                  icone: Icons.chevron_left,
                  couleur: textColor,
                  actif: _currentPage > 1,
                  onTap: () => _pdfViewerController.previousPage(),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    "PAGE $_currentPage SUR $_totalPages",
                    style: GoogleFonts.poppins(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                _flechePage(
                  icone: Icons.chevron_right,
                  couleur: textColor,
                  actif: _currentPage < _totalPages,
                  onTap: () => _pdfViewerController.nextPage(),
                ),
              ],
            ),
          ),
          SizedBox(height: 12),
          // Clean Floating Bar (Sainte Bible Style)
          Container(
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.cardBackground, // Premium dark theme
              borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildFloatingBarIcon(
                  icon: Icons.list,
                  onTap: () => _showTableOfContentsModal(initialTab: 0),
                ),
                _buildFloatingBarIcon(
                  icon: _bookmarks.any((b) => b.pageNumber == _currentPage)
                      ? Icons.bookmark
                      : Icons.bookmark_border,
                  onTap: _toggleBookmark,
                ),
                _buildFloatingBarIcon(
                  icon: Icons.search,
                  onTap: () {
                    setState(() {
                      _isSearching = !_isSearching;
                      if (!_isSearching) {
                        _searchResult?.clear();
                        _searchController.clear();
                      }
                    });
                  },
                ),
                _buildFloatingBarIcon(
                  icon: Icons.share_outlined,
                  onTap: () => PartageService().partagerLivre(
                    livreId: (widget.book['id'] ?? widget.book['ID'] ?? '')
                        .toString(),
                    titreDeSecours: (widget.book['titre'] ?? 'ce livre')
                        .toString(),
                  ),
                ),
                _buildFloatingBarIcon(
                  icon: Icons.close,
                  onTap: () => setState(() => _showControls = false),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingBarIcon({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
        child: Padding(
          padding: EdgeInsets.all(12.0),
          child: Icon(
            icon,
            color: AppColors.textPrimary.withOpacity(0.8),
            size: 24,
          ),
        ),
      ),
    );
  }

  Widget _buildMockEbookContent() {
    return Container(
      color: _backgroundColor,
      child: Center(child: Text("Mode PDF activé")),
    );
  }

  /// Feuille de réglages de lecture.
  ///
  /// Elle était peinte en noir et blanc écrits en dur : elle restait claire en
  /// mode sombre, seule surface de l'application à ne pas suivre le thème. Le
  /// curseur n'annonçait ni ce qu'il réglait ni sa valeur — deux loupes de
  /// 16 px pour toute indication — et l'interrupteur s'intitulait « Défilement
  /// vertical » quel que soit son état, alors qu'il bascule vers l'horizontal.
  void _showSettingsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBackground,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          // Une feuille est une route a part : elle lit la palette sans s'y
          // abonner, donc elle garde celle du dernier ecran construit.
          AppColors.suivreLeTheme(context);
          return SafeArea(
            top: false,
            // La feuille defile.
            //
            // Son contenu tenait tant qu'il etait fixe. La liste des voix, qui
            // depend de l'appareil, l'a fait deborder de cent cinquante-sept
            // pixels des qu'il y en a six. Une hauteur qu'on ne maitrise pas
            // doit pouvoir defiler ; on la borne aussi a quatre-vingts pour
            // cent de l'ecran, pour qu'on voie qu'il s'agit d'une feuille.
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimensions.spaceXl,
                    0,
                    AppDimensions.spaceXl,
                    AppDimensions.spaceXl,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        "Confort de lecture",
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          fontSize: 19,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spaceXl),

                      // Le meme curseur ne fait pas la meme chose selon le format :
                      // sur un PDF la mise en page est figee, on ne peut qu'agrandir
                      // l'image ; un EPUB recompose son texte. L'intitule le dit,
                      // plutot que de laisser croire a un reglage qui n'existe pas.
                      _titreReglage(
                        _isPdf ? "Agrandissement" : "Taille du texte",
                      ),
                      const SizedBox(height: AppDimensions.spaceXs),
                      Row(
                        children: [
                          Icon(
                            _isPdf ? Icons.zoom_out : Icons.text_decrease,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                          Expanded(
                            child: Slider(
                              value: _zoomLevel,
                              min: 0.5,
                              max: 3.0,
                              // Des crans : un zoom continu ne se retrouve jamais.
                              divisions: 10,
                              label: "${(_zoomLevel * 100).round()} %",
                              onChanged: (val) {
                                setState(() {
                                  _zoomLevel = val;
                                  _pdfViewerController.zoomLevel = val;
                                });
                                setModalState(() {});
                                _saveSettingsDebounced();
                              },
                            ),
                          ),
                          Icon(
                            _isPdf ? Icons.zoom_in : Icons.text_increase,
                            size: 22,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: AppDimensions.spaceMd),
                          // La valeur, sinon on règle à l'aveugle.
                          SizedBox(
                            width: 48,
                            child: Text(
                              "${(_zoomLevel * 100).round()} %",
                              textAlign: TextAlign.end,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.accentInk,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: AppDimensions.spaceXl),

                      _titreReglage("Luminosité"),
                      const SizedBox(height: AppDimensions.spaceXs),
                      Row(
                        children: [
                          Icon(
                            Icons.brightness_low,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                          Expanded(
                            child: Slider(
                              value: _brightness,
                              min: 0.25,
                              max: 1.0,
                              divisions: 15,
                              label: "${(_brightness * 100).round()} %",
                              onChanged: (val) {
                                setState(() => _brightness = val);
                                setModalState(() {});
                                _saveSettingsDebounced();
                              },
                            ),
                          ),
                          Icon(
                            Icons.brightness_high,
                            size: 20,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: AppDimensions.spaceMd),
                          SizedBox(
                            width: 48,
                            child: Text(
                              "${(_brightness * 100).round()} %",
                              textAlign: TextAlign.end,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.accentInk,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: AppDimensions.spaceXl),

                      // Le choix de la voix.
                      //
                      // Le service en retenait une — la meilleure qualite annoncee
                      // par le moteur, francais de France en premier — et gardait
                      // la liste pour lui. Or laquelle « sonne bien » ne se decide
                      // pas depuis le code : cela s'ecoute, et cela varie d'une
                      // oreille a l'autre.
                      if (_ttsService.voixDisponibles.length > 1) ...[
                        _titreReglage("Voix"),
                        const SizedBox(height: AppDimensions.spaceSm),
                        ..._ttsService.voixDisponibles.map((voix) {
                          final nom = voix['name'] ?? '';
                          final choisie = nom == _ttsService.nomVoix;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: GestureDetector(
                              // On selectionne et on ecoute aussitot : lire un
                              // identifiant ne dit rien du timbre, et comparer six
                              // voix sans les entendre est impossible.
                              onTap: () async {
                                await _ttsService.choisirVoix(voix);
                                setModalState(() {});
                                setState(() {});
                                if (!_ttsService.isPlaying) {
                                  // `apercu` empêche la fin de l'échantillon de
                                  // déclencher le passage à la page suivante :
                                  // écouter quatre voix faisait avancer le
                                  // livre de quatre pages, position enregistrée
                                  // au passage.
                                  await _ttsService.speak(
                                    "Voici ma voix pour la lecture de vos livres.",
                                    apercu: true,
                                  );
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: choisie
                                      ? AppColors.primary.withValues(
                                          alpha: 0.15,
                                        )
                                      : AppColors.surfaceVariant,
                                  borderRadius: BorderRadius.circular(
                                    AppDimensions.radiusInner,
                                  ),
                                  border: Border.all(
                                    color: choisie
                                        ? AppColors.primary
                                        : AppColors.border,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      choisie
                                          ? Icons.radio_button_checked
                                          : Icons.radio_button_unchecked,
                                      size: 18,
                                      color: choisie
                                          ? AppColors.accentInk
                                          : AppColors.textHint,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _nomLisibleVoix(voix),
                                            style: GoogleFonts.poppins(
                                              color: AppColors.textPrimary,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Text(
                                            _qualiteLisible(voix),
                                            style: GoogleFonts.poppins(
                                              color: AppColors.textSecondary,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: AppDimensions.spaceXl),
                      ],

                      _titreReglage("Sens de lecture"),
                      const SizedBox(height: AppDimensions.spaceSm),
                      // Deux choix nommés plutôt qu'un interrupteur : le libellé
                      // « Défilement vertical » restait écrit même une fois passé à
                      // l'horizontal, et rien ne disait vers quoi l'on basculait.
                      AppSegmentedControl(
                        labels: const ["Vertical", "Horizontal"],
                        selectedIndex: _isHorizontal ? 1 : 0,
                        onChanged: (index) {
                          setState(() => _isHorizontal = index == 1);
                          setModalState(() {});
                          _saveSettings();
                        },
                      ),

                      const SizedBox(height: AppDimensions.spaceXl),

                      _titreReglage("Fond de page"),
                      const SizedBox(height: AppDimensions.spaceSm),
                      Row(
                        children: [
                          Expanded(
                            child: _buildThemeOption(
                              "Original",
                              AppColors.parchmentLight,
                              AppColors.textOnLight,
                              setModalState,
                            ),
                          ),
                          const SizedBox(width: AppDimensions.spaceMd),
                          Expanded(
                            child: _buildThemeOption(
                              "Nuit",
                              AppColors.readingDark,
                              AppColors.textOnDark,
                              setModalState,
                            ),
                          ),
                          const SizedBox(width: AppDimensions.spaceMd),
                          Expanded(
                            child: _buildThemeOption(
                              "Sépia",
                              AppColors.parchment,
                              AppColors.readingBrownDark,
                              setModalState,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Intitulé de section de la feuille de réglages.
  Widget _titreReglage(String texte) {
    return Text(
      texte.toUpperCase(),
      style: GoogleFonts.poppins(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: AppColors.textSecondary,
      ),
    );
  }

  Widget _buildThemeOption(
    String name,
    Color bg,
    Color text,
    StateSetter setModalState, {
    bool applyBold = false,
  }) {
    final isSelected = _backgroundColor.toARGB32() == bg.toARGB32();

    return GestureDetector(
      onTap: () {
        setState(() => _backgroundColor = bg);
        setModalState(() {});
        _saveSettings();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 76,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
              border: Border.all(
                // Le choix retenu se signalait par une bordure noire de 2 px —
                // invisible sur la vignette « Nuit », qui est noire.
                color: isSelected ? AppColors.accentInk : AppColors.border,
                width: isSelected ? 2.5 : 1,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              "Aa",
              style: GoogleFonts.poppins(
                color: text,
                fontSize: 24,
                fontWeight: applyBold ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.spaceSm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isSelected) ...[
                Icon(Icons.check_circle, size: 13, color: AppColors.accentInk),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: isSelected
                        ? AppColors.accentInk
                        : AppColors.textSecondary,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showTableOfContentsModal({int initialTab = 0}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        AppColors.suivreLeTheme(context);
        return DefaultTabController(
          length: 3,
          initialIndex: initialTab,
          child: Container(
            height: MediaQuery.of(context).size.height * 0.7,
            // Meme confusion : la feuille entiere etait peinte dans la couleur
            // du texte. Elle prend la surface des cartes, comme toutes les
            // autres feuilles de l'application.
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppDimensions.radiusPill),
              ),
            ),
            child: Column(
              children: [
                SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textSecondary.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
                  ),
                ),
                TabBar(
                  indicatorColor: AppColors.primaryLight,
                  labelColor: AppColors.primaryLight,
                  unselectedLabelColor: AppColors.textSecondary,
                  labelStyle: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  tabs: const [
                    Tab(text: "Chapitres"),
                    Tab(text: "Signets"),
                    Tab(text: "Notes"),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      // Tab 1: PDF Chapters
                      _buildChaptersList(),
                      // Tab 2: User Bookmarks
                      _buildUserBookmarksList(onlyWithNotes: false),
                      // Tab 3: User Notes
                      _buildUserBookmarksList(onlyWithNotes: true),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildChaptersList() {
    final chapters = List.from(_pdfBookmarks);
    if (chapters.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.menu_book, color: AppColors.textSecondary, size: 48),
            SizedBox(height: 16),
            Text(
              "Aucun chapitre trouvé.",
              style: GoogleFonts.poppins(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: chapters.length,
      itemBuilder: (context, index) {
        if (index >= chapters.length) return const SizedBox.shrink();
        final bookmark = chapters[index];
        final bool isCurrent = _currentChapterTitle == bookmark.title;
        final int? page = _bookmarkPageMap[bookmark.title];

        return ListTile(
          leading: Icon(
            Icons.segment,
            color: isCurrent ? AppColors.accentInk : AppColors.textSecondary,
          ),
          title: Text(
            bookmark.title,
            style: GoogleFonts.poppins(
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              color: isCurrent ? AppColors.accentInk : Colors.black,
            ),
          ),
          trailing: page != null
              ? Text("p. $page", style: GoogleFonts.poppins(fontSize: 12))
              : null,
          onTap: () {
            if (page != null) {
              _pdfViewerController.jumpToPage(page);
            }
            Navigator.pop(context);
          },
        );
      },
    );
  }

  Widget _buildUserBookmarksList({bool onlyWithNotes = false}) {
    List<BookmarkModel> bookmarks = List.from(_bookmarks);

    if (onlyWithNotes) {
      bookmarks = bookmarks
          .where((bk) => bk.label != null && bk.label!.isNotEmpty)
          .toList();
    }

    if (bookmarks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              onlyWithNotes ? Icons.edit_note : Icons.bookmark_border,
              color: AppColors.textSecondary,
              size: 48,
            ),
            SizedBox(height: 16),
            Text(
              onlyWithNotes
                  ? "Aucune note trouvée."
                  : "Vous n'avez pas encore de marque-page.",
              style: GoogleFonts.poppins(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: bookmarks.length,
      itemBuilder: (context, index) {
        if (index >= bookmarks.length) return const SizedBox.shrink();
        final bk = bookmarks[index];
        return ListTile(
          leading: Icon(Icons.bookmark, color: AppColors.accentInk),
          title: Text(
            "Page ${bk.pageNumber}",
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            bk.label ?? "Repère de lecture",
            style: AppTextStyles.greyBody12,
          ),
          trailing: IconButton(
            icon: Icon(Icons.delete_outline, color: AppColors.error, size: 20),
            onPressed: () async {
              try {
                final token = await TokenStorage.getToken();
                if (token != null) {
                  await _bookmarkService.deleteBookmark(bk.id, token);
                  await _loadBookmarks();
                  if (mounted) {
                    AppNotifications.showSnackBar(
                      context,
                      message: 'Marque-page supprimé',
                      isSuccess: true,
                    );
                  }
                }
              } catch (e) {}
            },
          ),
          onTap: () {
            final page = bk.pageNumber;
            _pdfViewerController.jumpToPage(page);
            Navigator.pop(context);
          },
        );
      },
    );
  }

  Widget _buildDrawer() {
    final bookTitle = widget.book['titre'] ?? 'Livre SpaceLearn';
    final imageUrl =
        widget.book['image_couverture'] ?? widget.book['imageCouverture'];

    return Drawer(
      backgroundColor: AppColors.cardBackground, // Dark theme as in Bible app
      child: Column(
        children: [
          DrawerHeader(
            padding: EdgeInsets.zero,
            decoration: BoxDecoration(
              color: AppColors.scaffoldBackground,
              image: (imageUrl != null && imageUrl.isNotEmpty)
                  ? DecorationImage(
                      image: NetworkImage(imageUrl),
                      fit: BoxFit.cover,
                      colorFilter: ColorFilter.mode(
                        Colors.black.withOpacity(0.6),
                        BlendMode.darken,
                      ),
                    )
                  : null,
            ),
            child: Container(
              padding: const EdgeInsets.all(16),
              alignment: Alignment.bottomLeft,
              child: Text(
                bookTitle,
                style: GoogleFonts.lora(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildDrawerItem(
                  icon: Icons.menu_book,
                  title: "Le Livre",
                  onTap: () => Navigator.pop(context),
                ),
                _buildDrawerItem(
                  icon: Icons.format_list_bulleted,
                  title: "Table des matières",
                  onTap: () {
                    Navigator.pop(context);
                    _showTableOfContentsModal(initialTab: 0);
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.bookmark_border,
                  title: "Mes Signets",
                  onTap: () {
                    Navigator.pop(context);
                    _showTableOfContentsModal(initialTab: 1);
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.edit_note_outlined,
                  title: "Mes Remarques",
                  onTap: () {
                    Navigator.pop(context);
                    _showTableOfContentsModal(initialTab: 2);
                  },
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Divider(color: AppColors.textHint),
                ),
                _buildDrawerItem(
                  icon: Icons.settings_outlined,
                  title: "Paramètres de lecture",
                  onTap: () {
                    Navigator.pop(context);
                    _showSettingsModal();
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.exit_to_app,
                  title: "Quitter le lecteur",
                  onTap: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            child: Image.asset(
              'asset/logo_sp.png',
              height: 30,
              errorBuilder: (context, error, stackTrace) => Text(
                "SPACE LEARN",
                style: GoogleFonts.poppins(
                  color: AppColors.textHint,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textSecondary, size: 22),
      title: Text(
        title,
        style: GoogleFonts.poppins(
          color: AppColors.textPrimary.withOpacity(0.9),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
    );
  }

  Widget _buildErrorView(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: AppColors.error),
            SizedBox(height: 24),
            Text(
              "Oups !",
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.readingBrown,
              ),
            ),
            SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: AppColors.readingBrown.withOpacity(0.7),
              ),
            ),
            SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.readingBrown,
                foregroundColor: AppColors.textPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppDimensions.radiusInner,
                  ),
                ),
              ),
              child: Text("Retour"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 70,
      left: 20,
      right: 20,
      child: Container(
        height: 50,
        padding: EdgeInsets.symmetric(horizontal: 16),
        // Le fond etait AppColors.textPrimary — une couleur de TEXTE employee
        // comme surface — avec du texte noir par-dessus. En theme clair,
        // textPrimary est presque noir : on tapait donc du noir sur du noir,
        // sans voir ce qu'on cherchait.
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppDimensions.radiusInner),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: CustomSearchBar(
                controller: _searchController,
                autofocus: true,
                hintText: 'Rechercher dans le texte...',
                onChanged: (value) {
                  if (value.isEmpty) {
                    setState(() {
                      _searchResult?.clear();
                    });
                  }
                },
                onSubmitted: (value) async {
                  if (value.isNotEmpty) {
                    _searchResult = _pdfViewerController.searchText(value);
                    setState(() {});
                  }
                },
              ),
            ),
            if (_searchResult != null &&
                _searchResult!.totalInstanceCount > 0) ...[
              Text(
                '${_searchResult!.currentInstanceIndex} / ${_searchResult!.totalInstanceCount}',
                style: GoogleFonts.poppins(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.keyboard_arrow_up, color: AppColors.accentInk),
                onPressed: () {
                  _searchResult!.previousInstance();
                  setState(() {});
                },
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.keyboard_arrow_down,
                  color: AppColors.accentInk,
                ),
                onPressed: () {
                  _searchResult!.nextInstance();
                  setState(() {});
                },
              ),
            ],
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.close, color: AppColors.textSecondary),
              onPressed: () {
                setState(() {
                  _isSearching = false;
                  _searchResult?.clear();
                  _searchController.clear();
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TtsAudioWaveform extends StatefulWidget {
  final Color color;
  const _TtsAudioWaveform({required this.color});

  @override
  State<_TtsAudioWaveform> createState() => _TtsAudioWaveformState();
}

class _TtsAudioWaveformState extends State<_TtsAudioWaveform>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<double> _baseHeights = [0.2, 0.5, 0.8, 0.4, 0.7, 0.3, 0.6];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AppColors.suivreLeTheme(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(_baseHeights.length, (index) {
            final double value = (index * 0.15 + _controller.value) % 1.0;
            final double scale = 0.3 + 0.7 * (0.5 - (0.5 - value).abs()) * 2;
            final double height = 18.0 * _baseHeights[index] * scale;

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2.5),
              width: 3.5,
              height: height.clamp(4.0, 24.0),
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
              ),
            );
          }),
        );
      },
    );
  }
}
