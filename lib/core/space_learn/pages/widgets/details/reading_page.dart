import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
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

  bool _showCover = false;
  int _currentPage = 1;
  int _totalPages = 0;
  bool _isDocumentLoaded = false;
  String? _loadError;
  int? _savedPage;
  Timer? _saveTimer;
  bool _showControls = true;

  // Local Settings
  double _fontSize = 18.0;
  double _brightness = 1.0;
  String _fontFamily = 'Lora'; // Lora (Serif) or Poppins (Sans)
  Color _backgroundColor = const Color(0xFFFDF7E2); // Parchment

  List<BookmarkModel> _bookmarks = [];
  List<PdfBookmark> _pdfBookmarks = [];
  Map<String, int> _bookmarkPageMap = {};
  String _currentChapterTitle = "Début du livre";

  @override
  void initState() {
    super.initState();
    _pdfViewerController = PdfViewerController();
    _savedPage = widget.initialPage;
    _loadProgress();
    _loadSettings();
    _loadBookmarks();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _fontSize = prefs.getDouble('reading_font_size') ?? 18.0;
      _brightness = prefs.getDouble('reading_brightness') ?? 1.0;
      _fontFamily = prefs.getString('reading_font_family') ?? 'Lora';
      final bgColorHex = prefs.getInt('reading_bg_color');
      if (bgColorHex != null) {
        _backgroundColor = Color(bgColorHex);
      }
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('reading_font_size', _fontSize);
    await prefs.setDouble('reading_brightness', _brightness);
    await prefs.setString('reading_font_family', _fontFamily);
    await prefs.setInt('reading_bg_color', _backgroundColor.value);
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
            _savedPage = progress.chapitreCourant;
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
          note: "Marque-page à la page $_currentPage",
          authToken: token,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Marque-page ajouté à la page $_currentPage'),
              backgroundColor: const Color(0xFF22D3EE),
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

    return Scaffold(
      backgroundColor: _backgroundColor,
      body: Opacity(
        opacity: 0.5 + (_brightness * 0.5), // Simulate brightness
        child: Stack(
          children: [
            // Content Layer
            GestureDetector(
              onTap: () => setState(() => _showControls = !_showControls),
              child: _buildBody(pdfUrl, imageUrl, isPdf),
            ),

            // Header Layer
            if (!_showCover && _showControls) _buildHeader(),

            // Footer Layer
            if (!_showCover && _showControls && _isDocumentLoaded)
              _buildBottomControls(),

            // Close button if no cover
            if (_showCover)
              Positioned(
                top: 50,
                left: 20,
                child: _buildCircularButton(
                  icon: Icons.close,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
          ],
        ),
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
      scrollDirection: PdfScrollDirection.horizontal,
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
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 10,
          left: 20,
          right: 20,
          bottom: 20,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFFFDF7E2).withOpacity(0.9),
              const Color(0xFFFDF7E2).withOpacity(0.0),
            ],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildCircularButton(
              icon: Icons.arrow_back_ios_new,
              onPressed: () => Navigator.of(context).pop(),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'CHAPITRE',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF4A3728).withOpacity(0.6),
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                    letterSpacing: 1.5,
                  ),
                ),
                Text(
                  _currentChapterTitle,
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF4A3728),
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            _buildCircularButton(
              icon: Icons.text_fields,
              onPressed: _showSettingsModal,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircularButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.05),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: const Color(0xFF4A3728), size: 20),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildBottomControls() {
    double percentRead = _totalPages > 0
        ? (_currentPage / _totalPages) * 100
        : 0;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              const Color(0xFFFDF7E2).withOpacity(0.95),
              const Color(0xFFFDF7E2).withOpacity(0.0),
            ],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'PAGE $_currentPage SUR $_totalPages',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF4A3728).withOpacity(0.5),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${percentRead.toInt()}% LU',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF4A3728).withOpacity(0.5),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: const Color(0xFF22D3EE),
                  inactiveTrackColor: const Color(0xFF4A3728).withOpacity(0.1),
                  thumbColor: Colors.white,
                  overlayColor: const Color(0xFF22D3EE).withOpacity(0.2),
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 6,
                  ),
                ),
                child: Slider(
                  value: _currentPage.toDouble(),
                  min: 1,
                  max: _totalPages.toDouble() > 0 ? _totalPages.toDouble() : 1,
                  onChanged: (val) {
                    _pdfViewerController.jumpToPage(val.toInt());
                  },
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.menu_book,
                      color: const Color(0xFF4A3728).withOpacity(0.7),
                      size: 28,
                    ),
                    onPressed: _showTableOfContentsModal,
                  ),
                  IconButton(
                    icon: Icon(
                      _bookmarks.any((b) => b.page == _currentPage)
                          ? Icons.bookmark
                          : Icons.bookmark_border,
                      color: const Color(0xFF4A3728).withOpacity(0.7),
                      size: 28,
                    ),
                    onPressed: _toggleBookmark,
                  ),
                  _buildNavIcon(Icons.search),
                  IconButton(
                    icon: Icon(
                      Icons.share_outlined,
                      color: const Color(0xFF4A3728).withOpacity(0.7),
                      size: 28,
                    ),
                    onPressed: () async {
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
                          final title =
                              widget.book['titre'] ?? 'SpaceLearn Book';
                          Share.share(
                            "Je lis '$title' sur SpaceLearn ! Rejoins-moi !",
                          );
                        }
                      } catch (e) {
                        debugPrint("Error sharing: $e");
                        final title = widget.book['titre'] ?? 'SpaceLearn Book';
                        Share.share(
                          "Je lis '$title' sur SpaceLearn ! Rejoins-moi !",
                        );
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

  Widget _buildNavIcon(IconData icon) {
    return Icon(
      icon,
      color: const Color(0xFF4A3728).withOpacity(0.7),
      size: 28,
    );
  }

  Widget _buildMockEbookContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(30, 140, 30, 200),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'II. Les lueurs de l\'aube',
            style:
                (_fontFamily == 'Lora'
                        ? GoogleFonts.lora()
                        : GoogleFonts.poppins())
                    .copyWith(
                      fontSize: _fontSize + 14,
                      fontWeight: FontWeight.w800,
                      color: _backgroundColor.computeLuminance() > 0.5
                          ? const Color(0xFF4A3728)
                          : Colors.white,
                    ),
          ),
          const SizedBox(height: 40),
          RichText(
            text: TextSpan(
              style:
                  (_fontFamily == 'Lora'
                          ? GoogleFonts.lora()
                          : GoogleFonts.poppins())
                      .copyWith(
                        fontSize: _fontSize,
                        color: _backgroundColor.computeLuminance() > 0.5
                            ? const Color(0xFF4A3728)
                            : Colors.white.withOpacity(0.9),
                        height: 1.7,
                      ),
              children: [
                TextSpan(
                  text: 'L',
                  style: GoogleFonts.lora(
                    fontSize: 60,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF22D3EE),
                  ),
                ),
                const TextSpan(
                  text:
                      ' e soleil commençait à peine à poindre derrière les collines arides qui entouraient la petite ville. L\'air était encore frais, chargé de l\'humidité nocturne et de l\'odeur terreuse des jardins environnants. Dans le silence de la chambre, le craquement régulier du plancher annonçait les premiers pas de la journée.\n\nJe restais immobile, les yeux fixés sur le plafond où dansaient des ombres incertaines. Chaque minute qui passait semblait étirer le temps, le rendant presque tangible. C\'était cette sensation particulière, ce moment suspendu entre le rêve et la réalité, où tout semble possible mais où rien n\'a encore commencé.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showSettingsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Paramètres de lecture",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 24),
              // Font size
              Row(
                children: [
                  const Icon(Icons.text_fields, size: 16),
                  Expanded(
                    child: Slider(
                      value: _fontSize,
                      min: 12,
                      max: 30,
                      activeColor: const Color(0xFF22D3EE),
                      onChanged: (val) {
                        setState(() => _fontSize = val);
                        setModalState(() {});
                        _saveSettings();
                      },
                    ),
                  ),
                  const Icon(Icons.text_fields, size: 24),
                ],
              ),
              const SizedBox(height: 16),
              // Brightness
              Row(
                children: [
                  const Icon(Icons.light_mode, size: 16),
                  Expanded(
                    child: Slider(
                      value: _brightness,
                      min: 0.2,
                      max: 1.0,
                      activeColor: const Color(0xFF22D3EE),
                      onChanged: (val) {
                        setState(() => _brightness = val);
                        setModalState(() {});
                        _saveSettings();
                      },
                    ),
                  ),
                  const Icon(Icons.light_mode, size: 24),
                ],
              ),
              const SizedBox(height: 24),
              // Font family & Background
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ToggleButtons(
                    borderRadius: BorderRadius.circular(8),
                    isSelected: [
                      _fontFamily == 'Lora',
                      _fontFamily == 'Poppins',
                    ],
                    color: Colors.grey,
                    selectedColor: Colors.white,
                    fillColor: const Color(0xFF22D3EE),
                    onPressed: (index) {
                      setState(() {
                        _fontFamily = index == 0 ? 'Lora' : 'Poppins';
                      });
                      setModalState(() {});
                      _saveSettings();
                    },
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text("Serif", style: GoogleFonts.lora()),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text("Sans", style: GoogleFonts.poppins()),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      _buildColorOption(const Color(0xFFFDF7E2), setModalState),
                      const SizedBox(width: 8),
                      _buildColorOption(Colors.white, setModalState),
                      const SizedBox(width: 8),
                      _buildColorOption(
                        const Color(0xFF1E293B),
                        setModalState,
                        isDark: true,
                      ),
                    ],
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

  Widget _buildColorOption(
    Color color,
    StateSetter setModalState, {
    bool isDark = false,
  }) {
    bool isSelected = _backgroundColor.value == color.value;
    return GestureDetector(
      onTap: () {
        setState(() => _backgroundColor = color);
        setModalState(() {});
        _saveSettings();
      },
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? const Color(0xFF22D3EE) : Colors.grey[300]!,
            width: 2,
          ),
        ),
      ),
    );
  }

  void _showTableOfContentsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DefaultTabController(
        length: 2,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.6,
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
                indicatorColor: const Color(0xFF22D3EE),
                labelColor: const Color(0xFF22D3EE),
                unselectedLabelColor: Colors.grey,
                labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                tabs: const [
                  Tab(text: "Chapitres"),
                  Tab(text: "Mes Marque-pages"),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    // Tab 1: PDF Chapters
                    _buildChaptersList(),
                    // Tab 2: User Bookmarks
                    _buildUserBookmarksList(),
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
    if (_pdfBookmarks.isEmpty) {
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
      itemCount: _pdfBookmarks.length,
      itemBuilder: (context, index) {
        final bookmark = _pdfBookmarks[index];
        final bool isCurrent = _currentChapterTitle == bookmark.title;
        final int? page = _bookmarkPageMap[bookmark.title];

        return ListTile(
          leading: Icon(
            Icons.segment,
            color: isCurrent ? const Color(0xFF22D3EE) : Colors.grey[400],
          ),
          title: Text(
            bookmark.title,
            style: GoogleFonts.poppins(
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              color: isCurrent ? const Color(0xFF22D3EE) : Colors.black,
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

  Widget _buildUserBookmarksList() {
    if (_bookmarks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bookmark_border, color: Colors.grey, size: 48),
            const SizedBox(height: 16),
            Text(
              "Vous n'avez pas encore de marque-page.",
              style: GoogleFonts.poppins(color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              "Cliquez sur l'icône marque-page pendant la lecture.",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: _bookmarks.length,
      itemBuilder: (context, index) {
        final bk = _bookmarks[index];
        return ListTile(
          leading: const Icon(Icons.bookmark, color: Color(0xFF22D3EE)),
          title: Text(
            "Page ${bk.page}",
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            bk.note ?? "Repère de lecture",
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
            final page = bk.page;
            _pdfViewerController.jumpToPage(page);
            Navigator.pop(context);
          },
        );
      },
    );
  }

  Widget _buildErrorView(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.info_outline, size: 60, color: Colors.grey),
            const SizedBox(height: 20),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
