import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/themes/app_text_styles.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' hide Image;
import 'package:space_learn_flutter/core/services/tts_service.dart';
import 'package:space_learn_flutter/core/services/book_cache_service.dart';
import 'dart:typed_data';
import 'package:google_fonts/google_fonts.dart';
import 'package:epub_view/epub_view.dart' hide Image;
import 'package:http/http.dart' as http;
import '../../../../utils/api_routes.dart';
import '../../../../utils/token_storage.dart';
import '../../../data/dataServices/readingProgressService.dart';
import '../../../data/dataServices/bookmarkService.dart';
import '../../../data/model/bookmark_model.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/dataServices/readingSettingsService.dart';
import '../../../data/dataServices/readerStatsService.dart';

class ReadingPage extends StatefulWidget {
  final Map<String, dynamic> book;
  final int? initialPage;

  const ReadingPage({super.key, required this.book, this.initialPage});

  @override
  State<ReadingPage> createState() => _ReadingPageState();
}

class _ReadingPageState extends State<ReadingPage> {
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();
  late PdfViewerController _pdfViewerController;
  final ReadingProgressService _progressService = ReadingProgressService();
  final BookmarkService _bookmarkService = BookmarkService();
  final ReadingSettingsService _settingsService = ReadingSettingsService();
  final ReaderStatsService _statsService = ReaderStatsService();

  final bool _showCover = false;
  int _currentPage = 1;
  int _totalPages = 0;
  bool _isDocumentLoaded = false;
  String? _loadError;
  int? _savedPage;
  Timer? _saveTimer;
  Timer? _settingsTimer;
  Timer? _heartbeatTimer;
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
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  EpubController? _epubController;

  @override
  void initState() {
    super.initState();
    _pdfViewerController = PdfViewerController();
    _savedPage = widget.initialPage;
    _loadBookFile();
    _loadProgress();
    _loadSettings();
    _loadBookmarks();
    _startHeartbeat();
    
    // Initialisation TTS
    _ttsService.onCompletion = _onTtsCompletion;
    _ttsService.addListener(_onTtsStateChanged);
  }

  Future<void> _loadBookFile() async {
    final String? pdfUrl = widget.book['fichier_url'] ?? widget.book['fichierUrl'];
    final bookId = (widget.book['id'] ?? widget.book['ID'] ?? '').toString();

    if (pdfUrl == null || pdfUrl.isEmpty || bookId.isEmpty) {
      setState(() {
        _loadError = "Aucun fichier disponible pour ce livre.";
      });
      return;
    }

    final String format = (widget.book['format'] ?? '').toString().toLowerCase();
    final bool isEpub = format == 'epub' || pdfUrl.toLowerCase().endsWith('.epub');

    try {
      final isCached = await _bookCacheService.isBookCached(bookId, pdfUrl);
      if (isCached) {
        final bytes = await _bookCacheService.getCachedBookBytes(bookId, pdfUrl);
        if (bytes != null) {
          setState(() {
            _cachedBookBytes = bytes;
            _isDownloading = false;
          });
          if (isEpub) {
            _epubController = EpubController(
              document: EpubDocument.openData(bytes),
            );
          }
          return;
        }
      }

      // Not cached, download it
      setState(() {
        _isDownloading = true;
        _downloadProgress = 0.0;
      });

      final bytes = await _bookCacheService.downloadAndCache(
        bookId,
        pdfUrl,
        onProgress: (progress) {
          setState(() {
            _downloadProgress = progress;
          });
        },
      );

      if (bytes != null) {
        setState(() {
          _cachedBookBytes = bytes;
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
        _loadError = "Erreur lors de la préparation du fichier : $e";
        _isDownloading = false;
      });
    }
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
    } catch (e) {
    }
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
    } catch (e) {
    }
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
    } catch (e) {
    }
  }

  Future<void> _loadProgress() async {
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
    } catch (e) {
    }
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
    } catch (e) {
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      final bookId = widget.book['id'] ?? widget.book['ID'];
      if (bookId != null) {
        _statsService.recordReadingTime(bookId.toString());
      }
    });
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 2), () {
      _saveProgress(page);
    });

    if (_ttsService.isPlaying) {
      _speakCurrentPage();
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Marque-page ajouté à la page $_currentPage'),
              backgroundColor: AppColors.primaryLight,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _heartbeatTimer?.cancel();
    _settingsTimer?.cancel();
    _pdfViewerController.dispose();
    _epubController?.dispose();
    _ttsService.removeListener(_onTtsStateChanged);
    _ttsService.stop();
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

  void _onTtsCompletion() {
    if (_autoplayNextPage && _currentPage < _totalPages) {
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
        textToRead = text;
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
          final regExp = RegExp(r'<[^>]*>', multiLine: true, caseSensitive: true);
          textToRead = htmlContent.replaceAll(regExp, ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Aucun texte lisible trouvé sur cette page."),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    await _ttsService.speak(textToRead);
  }

  Widget _buildTtsPlayerPanel() {
    final bool isDark = _backgroundColor.computeLuminance() < 0.5;
    final Color panelBg = AppColors.cardBackground.withOpacity(0.95);
    final Color itemColor = isDark ? Colors.white : AppColors.readingBrown;

    return Positioned(
      bottom: 24,
      left: 24,
      right: 24,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: panelBg,
          borderRadius: BorderRadius.circular(20),
          
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
                          color: _ttsService.isPlaying ? AppColors.primary : itemColor.withOpacity(0.7),
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
                        _autoplayNextPage ? Icons.autorenew : Icons.play_disabled,
                        color: _autoplayNextPage ? AppColors.primary : itemColor.withOpacity(0.4),
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
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () {
                        double nextRate = 0.5;
                        if (_ttsService.speechRate == 0.5) {
                          nextRate = 0.6;
                        } else if (_ttsService.speechRate == 0.6) {
                          nextRate = 0.75;
                        } else if (_ttsService.speechRate == 0.75) {
                          nextRate = 1.0;
                        } else if (_ttsService.speechRate == 1.0) {
                          nextRate = 0.4;
                        } else {
                          nextRate = 0.5;
                        }
                        _ttsService.setRate(nextRate);
                      },
                      child: Text(
                        _getSpeedLabel(_ttsService.speechRate),
                        style: GoogleFonts.poppins(
                          color: AppColors.primary,
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
                child: _TtsAudioWaveform(color: AppColors.primary),
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
                      final currentChapterIdx = (_epubController!.currentValue?.chapterNumber ?? 1) - 1;
                      if (currentChapterIdx - 1 >= 0 && currentChapterIdx - 1 < toc.length) {
                        final prevChapter = toc[currentChapterIdx - 1];
                        _epubController!.jumpTo(index: prevChapter.startIndex);
                      }
                    }
                  },
                ),
                GestureDetector(
                  onTap: () {
                    if (_ttsService.isPlaying) {
                      _ttsService.pause();
                    } else if (_ttsService.isPaused) {
                      _speakCurrentPage();
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
                                color: AppColors.textPrimary,
                                strokeWidth: 2.5,
                              ),
                            ),
                          )
                        : Icon(
                            _ttsService.isPlaying ? Icons.pause : Icons.play_arrow,
                            color: AppColors.textPrimary,
                            size: 32,
                          ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.stop, 
                    color: _ttsService.isStopped ? itemColor.withOpacity(0.4) : itemColor, 
                    size: 28
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
                      final currentChapterIdx = (_epubController!.currentValue?.chapterNumber ?? 1) - 1;
                      if (currentChapterIdx + 1 < toc.length) {
                        final nextChapter = toc[currentChapterIdx + 1];
                        _epubController!.jumpTo(index: nextChapter.startIndex);
                      }
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getSpeedLabel(double rate) {
    if (rate == 0.5) return "1.0x";
    if (rate == 0.6) return "1.2x";
    if (rate == 0.75) return "1.5x";
    if (rate == 1.0) return "2.0x";
    if (rate == 0.4) return "0.8x";
    return "${(rate / 0.5).toStringAsFixed(1)}x";
  }

  @override
  Widget build(BuildContext context) {
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
          // Content Layer (Dimmed)
          Opacity(
            opacity: 0.5 + (_brightness * 0.5), // Simulate brightness
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => setState(() => _showControls = !_showControls),
              child: _buildBody(pdfUrl, imageUrl, isPdf),
            ),
          ),

          // Header Layer (Solid)
          if (!_showCover && _showControls) _buildHeader(),

          if (_isSearching) _buildSearchBar(),

          // Footer Layer (Solid)
          if (!_showCover && _showControls && _isDocumentLoaded && !_showTtsPanel)
            _buildBottomControls(),

          // Panneau de contrôle Audio (TTS)
          if (!_showCover && _showControls && _isDocumentLoaded && _showTtsPanel)
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

  Widget _buildBody(String? pdfUrl, String? imageUrl, bool isPdf) {
    if (_loadError != null) {
      return _buildErrorView(_loadError!);
    }

    if (pdfUrl == null || pdfUrl.isEmpty) {
      return _buildErrorView("Aucun fichier disponible pour ce livre.");
    }

    if (_isDownloading) {
      final isDark = _backgroundColor.computeLuminance() < 0.5;
      final Color textColor = isDark ? Colors.white : AppColors.readingBrown;
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.cloud_download_outlined,
                size: 64,
                color: AppColors.primary,
              ),
              SizedBox(height: 24),
              Text(
                "Téléchargement du livre...",
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              SizedBox(height: 8),
              Text(
                "Votre livre sera disponible hors-ligne après cette étape.",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: textColor.withOpacity(0.6),
                ),
              ),
              SizedBox(height: 24),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: _downloadProgress > 0 ? _downloadProgress : null,
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  minHeight: 8,
                ),
              ),
              SizedBox(height: 12),
              Text(
                _downloadProgress > 0
                    ? "${(_downloadProgress * 100).toStringAsFixed(0)} %"
                    : "Connexion en cours...",
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final String format = (widget.book['format'] ?? '').toString().toLowerCase();
    final bool isEpub = format == 'epub' || (pdfUrl != null && pdfUrl.toLowerCase().endsWith('.epub'));

    if (!isPdf && !isEpub) {
      // For demonstration of the UI if not a PDF, we show dummy text that looks like the mockup
      return _buildMockEbookContent();
    }

    if (_cachedBookBytes == null) {
      return Center(child: CircularProgressIndicator());
    }

    if (isEpub) {
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
      scrollDirection: _isHorizontal
          ? PdfScrollDirection.vertical
          : PdfScrollDirection.horizontal,
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
                    ? AppColors.primary
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
          // Page Indicator (Centered, floating above the bar)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: _backgroundColor.withOpacity(0.95),
              borderRadius: BorderRadius.circular(20),
              
            ),
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
          SizedBox(height: 12),
          // Clean Floating Bar (Sainte Bible Style)
          Container(
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.cardBackground, // Premium dark theme
              borderRadius: BorderRadius.circular(16),
              
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
                  onTap: () async {
                    try {
                      final bookId = widget.book['id'] ?? widget.book['ID'];
                      final url = ApiRoutes.shareBook.replaceFirst(
                        ':id',
                        bookId.toString(),
                      );
                      final response = await http.get(Uri.parse(url));
                      if (response.statusCode == 200) {
                        final data = json.decode(response.body)['data'];
                        Share.share(
                          data['share_text'] ??
                              "Découvrez ce livre sur SpaceLearn !",
                          subject:
                              data['title'] ??
                              widget.book['titre'] ??
                              "SpaceLearn",
                        );
                      } else {
                        final title = widget.book['titre'] ?? 'SpaceLearn Book';
                        Share.share(
                          "Je lis '$title' sur SpaceLearn ! Rejoins-moi !",
                        );
                      }
                    } catch (e) {
                      final title = widget.book['titre'] ?? 'SpaceLearn Book';
                      Share.share(
                        "Je lis '$title' sur SpaceLearn ! Rejoins-moi !",
                      );
                    }
                  },
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
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: EdgeInsets.all(12.0),
          child: Icon(icon, color: AppColors.textPrimary.withOpacity(0.8), size: 24),
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

  void _showSettingsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.iosSurface, // Light background like iOS
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Thèmes et réglages",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: Colors.black87,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.05),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close,
                        size: 20,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24),

              // Zoom Slider
              SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.zoom_out, size: 16, color: Colors.black45),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 4,
                        activeTrackColor: Colors.black,
                        inactiveTrackColor: Colors.black.withOpacity(0.1),
                        thumbColor: Colors.white,
                        overlayColor: Colors.transparent,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 10,
                          elevation: 2,
                        ),
                      ),
                      child: Slider(
                        value: _zoomLevel,
                        min: 0.5,
                        max: 3.0,
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
                  ),
                  Icon(Icons.zoom_in, size: 18, color: Colors.black45),
                ],
              ),
              Divider(height: 30),

              // Orientation Toggle
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  _isHorizontal ? Icons.swap_vert : Icons.swap_horiz,
                  color: Colors.black87,
                ),
                title: Text(
                  "Défilement vertical",
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                trailing: Switch(
                  value: _isHorizontal,
                  onChanged: (val) {
                    setState(() => _isHorizontal = val);
                    setModalState(() {});
                    _saveSettings();
                  },
                  activeColor: Colors.black,
                ),
              ),

              Divider(height: 30),

              // Themes Grid
              GridView.count(
                shrinkWrap: true,
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.2,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildThemeOption(
                    "Original",
                    Colors.white,
                    Colors.black,
                    setModalState,
                  ),
                  _buildThemeOption(
                    "Nuit",
                    AppColors.readingDark,
                    Colors.white,
                    setModalState,
                  ),
                  _buildThemeOption(
                    "Sépia",
                    AppColors.parchment,
                    AppColors.readingBrownDark,
                    setModalState,
                  ),
                ],
              ),
              SizedBox(height: 16),
            ],
          ),
        ),
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
    bool isSelected = _backgroundColor.value == bg.value;

    return GestureDetector(
      onTap: () {
        setState(() {
          _backgroundColor = bg;
        });
        setModalState(() {});
        _saveSettings();
      },
      child: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? Colors.black : Colors.transparent,
                  width: 2,
                ),
                
              ),
              child: Center(
                child: Text(
                  "Aa",
                  style: TextStyle(
                    color: text,
                    fontSize: 24,
                    fontWeight: applyBold ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 6),
          Text(
            name,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.black54,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
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
      builder: (context) => DefaultTabController(
        length: 3,
        initialIndex: initialTab,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: AppColors.textPrimary,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            children: [
              SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textSecondary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              TabBar(
                indicatorColor: AppColors.primaryLight,
                labelColor: AppColors.primaryLight,
                unselectedLabelColor: Colors.grey,
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
      ),
    );
  }

  Widget _buildChaptersList() {
    final chapters = List.from(_pdfBookmarks);
    if (chapters.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.menu_book, color: Colors.grey, size: 48),
            SizedBox(height: 16),
            Text(
              "Aucun chapitre trouvé.",
              style: GoogleFonts.poppins(color: Colors.grey),
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
            color: isCurrent ? AppColors.primaryLight : AppColors.textSecondary,
          ),
          title: Text(
            bookmark.title,
            style: GoogleFonts.poppins(
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              color: isCurrent ? AppColors.primaryLight : Colors.black,
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
              color: Colors.grey,
              size: 48,
            ),
            SizedBox(height: 16),
            Text(
              onlyWithNotes
                  ? "Aucune note trouvée."
                  : "Vous n'avez pas encore de marque-page.",
              style: GoogleFonts.poppins(color: Colors.grey),
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
          leading: Icon(Icons.bookmark, color: AppColors.primaryLight),
          title: Text(
            "Page ${bk.pageNumber}",
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            bk.label ?? "Repère de lecture",
            style: AppTextStyles.greyBody12,
          ),
          trailing: IconButton(
            icon: Icon(Icons.delete_outline, color: Colors.red, size: 20),
            onPressed: () async {
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              try {
                final token = await TokenStorage.getToken();
                if (token != null) {
                  await _bookmarkService.deleteBookmark(bk.id, token);
                  await _loadBookmarks();
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Text('Marque-page supprimé'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              } catch (e) {
              }
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
              'assets/images/logo.png', // Fallback if exists
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
      leading: Icon(icon, color: Colors.blueGrey[200], size: 22),
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
            Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
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
                  borderRadius: BorderRadius.circular(12),
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
        decoration: BoxDecoration(
          color: AppColors.textPrimary,
          borderRadius: BorderRadius.circular(15),
          
        ),
        child: Row(
          children: [
            Icon(Icons.search, color: AppColors.primary, size: 22),
            SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _searchController,
                autofocus: true,
                style: TextStyle(color: Colors.black87, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Rechercher dans le texte...',
                  hintStyle: TextStyle(color: Colors.grey),
                  border: InputBorder.none,
                ),
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
                  color: Colors.grey[600],
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.keyboard_arrow_up,
                  color: AppColors.primary,
                ),
                onPressed: () {
                  _searchResult!.previousInstance();
                  setState(() {});
                },
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.keyboard_arrow_down,
                  color: AppColors.primary,
                ),
                onPressed: () {
                  _searchResult!.nextInstance();
                  setState(() {});
                },
              ),
            ],
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.close, color: Colors.grey),
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

class _TtsAudioWaveformState extends State<_TtsAudioWaveform> with SingleTickerProviderStateMixin {
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
                borderRadius: BorderRadius.circular(2.0),
              ),
            );
          }),
        );
      },
    );
  }
}