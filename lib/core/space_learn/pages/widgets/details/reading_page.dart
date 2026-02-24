import 'dart:async';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../utils/token_storage.dart';
import '../../../data/dataServices/readingProgressService.dart';

class ReadingPage extends StatefulWidget {
  final Map<String, dynamic> book;

  const ReadingPage({super.key, required this.book});

  @override
  State<ReadingPage> createState() => _ReadingPageState();
}

class _ReadingPageState extends State<ReadingPage> {
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();
  late PdfViewerController _pdfViewerController;
  final ReadingProgressService _progressService = ReadingProgressService();

  bool _showCover = false;
  int _currentPage = 1;
  int _totalPages = 0;
  bool _isDocumentLoaded = false;
  String? _loadError;
  int? _savedPage;
  Timer? _saveTimer;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _pdfViewerController = PdfViewerController();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    try {
      final token = await TokenStorage.getToken();
      if (token != null) {
        final bookId = widget.book['id'] ?? widget.book['ID'];
        final progress = await _progressService.getReadingProgress(
          bookId,
          token,
        );
        if (progress != null && mounted) {
          setState(() {
            _savedPage = progress.chapitreCourant;
          });
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

  @override
  void dispose() {
    _saveTimer?.cancel();
    _pdfViewerController.dispose();
    super.dispose();
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
      backgroundColor: const Color(0xFFFDF7E2), // Parchment background
      body: Stack(
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
          setState(() {
            _totalPages = details.document.pages.count;
            _isDocumentLoaded = true;
          });
          if (_savedPage != null &&
              _savedPage! > 1 &&
              _savedPage! <= _totalPages) {
            Future.delayed(const Duration(milliseconds: 200), () {
              _pdfViewerController.jumpToPage(_savedPage!);
            });
          }
        }
      },
      onPageChanged: (PdfPageChangedDetails details) {
        if (mounted) {
          _onPageChanged(details.newPageNumber);
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
                  'CHAPITRE II',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF4A3728).withOpacity(0.6),
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                    letterSpacing: 1.5,
                  ),
                ),
                Text(
                  'Les lueurs de l\'aube',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF4A3728),
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            _buildCircularButton(
              icon: Icons.text_fields,
              onPressed: () {}, // Text settings
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
                  max: _totalPages.toDouble(),
                  onChanged: (val) {
                    _pdfViewerController.jumpToPage(val.toInt());
                  },
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildNavIcon(Icons.menu_book),
                  _buildNavIcon(Icons.bookmark_border),
                  _buildNavIcon(Icons.search),
                  _buildNavIcon(Icons.share_outlined),
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
            style: GoogleFonts.lora(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF4A3728),
            ),
          ),
          const SizedBox(height: 40),
          RichText(
            text: TextSpan(
              style: GoogleFonts.lora(
                fontSize: 18,
                color: const Color(0xFF4A3728),
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
