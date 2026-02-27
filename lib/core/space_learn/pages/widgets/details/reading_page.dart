import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:google_fonts/google_fonts.dart';
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

  bool _showCover = false;
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

  @override
  void initState() {
    super.initState();
    _pdfViewerController = PdfViewerController();
    _savedPage = widget.initialPage;
    _loadProgress();
    _loadSettings();
    _loadBookmarks();
    _startHeartbeat();
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
            _zoomLevel = backendSettings.zoomLevel;
            _isHorizontal = backendSettings.isHorizontal;
          });
          // Update local with backend data
          _saveToLocal(prefs);
        }
      }
    } catch (e) {
      debugPrint("Error syncing settings: $e");
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
      debugPrint("Error saving settings to backend: $e");
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
      debugPrint("Error loading bookmarks: $e");
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
      debugPrint("Error loading progress: $e");
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
      debugPrint("Error saving progress: $e");
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
      debugPrint("Error creating bookmark: $e");
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _heartbeatTimer?.cancel();
    _settingsTimer?.cancel();
    _pdfViewerController.dispose();
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
          if (!_showCover && _showControls && _isDocumentLoaded)
            _buildBottomControls(),

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
                  icon: const Icon(
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
    if (pdfUrl == null || pdfUrl.isEmpty) {
      return _buildErrorView("Aucun fichier disponible pour ce livre.");
    }

    if (!isPdf) {
      // For demonstration of the UI if not a PDF, we show dummy text that looks like the mockup
      return _buildMockEbookContent();
    }

    return SfPdfViewer.network(
      pdfUrl,
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
            const SizedBox(width: 8),
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
            const SizedBox(width: 8),
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
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
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
          const SizedBox(height: 12),
          // Clean Floating Bar (Sainte Bible Style)
          Container(
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.cardBackground, // Premium dark theme
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
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
          padding: const EdgeInsets.all(12.0),
          child: Icon(icon, color: Colors.white.withOpacity(0.8), size: 24),
        ),
      ),
    );
  }

  Widget _buildMockEbookContent() {
    return Container(
      color: _backgroundColor,
      child: const Center(child: Text("Mode PDF activé")),
    );
  }

  void _showSettingsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: const BoxDecoration(
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
                      child: const Icon(
                        Icons.close,
                        size: 20,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Zoom Slider
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.zoom_out, size: 16, color: Colors.black45),
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
                  const Icon(Icons.zoom_in, size: 18, color: Colors.black45),
                ],
              ),
              const Divider(height: 30),

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

              const Divider(height: 30),

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
              const SizedBox(height: 16),
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
                boxShadow: [
                  if (!isSelected)
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                ],
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
          const SizedBox(height: 6),
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
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
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
            const Icon(Icons.menu_book, color: Colors.grey, size: 48),
            const SizedBox(height: 16),
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
            color: isCurrent ? AppColors.primaryLight : Colors.grey[400],
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
            const SizedBox(height: 16),
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
          leading: const Icon(Icons.bookmark, color: AppColors.primaryLight),
          title: Text(
            "Page ${bk.pageNumber}",
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            bk.label ?? "Repère de lecture",
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
            onPressed: () async {
              try {
                final token = await TokenStorage.getToken();
                if (token != null) {
                  await _bookmarkService.deleteBookmark(bk.id, token);
                  await _loadBookmarks();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Marque-page supprimé'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                }
              } catch (e) {
                debugPrint("Error deleting bookmark: $e");
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
                  color: Colors.white,
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
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Divider(color: Colors.white10),
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
                  color: Colors.white24,
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
          color: Colors.white.withOpacity(0.9),
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
            const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
            const SizedBox(height: 24),
            Text(
              "Oups !",
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.readingBrown,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: AppColors.readingBrown.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.readingBrown,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text("Retour"),
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
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.search, color: Colors.blueAccent, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.black87, fontSize: 14),
                decoration: const InputDecoration(
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
                icon: const Icon(
                  Icons.keyboard_arrow_up,
                  color: Colors.blueAccent,
                ),
                onPressed: () {
                  _searchResult!.previousInstance();
                  setState(() {});
                },
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.keyboard_arrow_down,
                  color: Colors.blueAccent,
                ),
                onPressed: () {
                  _searchResult!.nextInstance();
                  setState(() {});
                },
              ),
            ],
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close, color: Colors.grey),
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
