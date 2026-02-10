import 'dart:async';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:space_learn_flutter/core/themes/app_colors.dart';
import '../../../../utils/tokenStorage.dart';
import '../../../../utils/api_routes.dart';
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

  bool _showCover = true;
  int _currentPage = 1;
  int _totalPages = 0;
  bool _isDocumentLoaded = false;
  String? _loadError;
  int? _savedPage;
  Timer? _saveTimer;

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
        print(
          "📖 [ReadingPage] Loading progress for book ID: ${widget.book['id']}",
        );
        final progress = await _progressService.getReadingProgress(
          widget.book['id'],
          token,
        );
        if (progress != null && mounted) {
          print(
            "✅ [ReadingPage] Progress loaded: Page ${progress.chapitreCourant}",
          );
          setState(() {
            _savedPage = progress.chapitreCourant;
          });
        } else {
          print("⚠️ [ReadingPage] No saved progress found.");
        }
      }
    } catch (e) {
      print("❌ [ReadingPage] Error loading progress: $e");
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
      print("Error saving progress: $e");
    }
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });

    // Debounce save
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 2), () {
      _saveProgress(page);
    });
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    // Try to save one last time if needed, but async in dispose is tricky.
    // The debouncer should handle most cases.
    _pdfViewerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String? rawPdfUrl = _getBookFileUrl(widget.book);
    final String? rawImageUrl = _getBookImage(widget.book);

    // Sanitize URLs (ensure they use Gin base if relative)
    final String? pdfUrl = ApiRoutes.sanitizeImageUrl(rawPdfUrl, useGin: true);
    final String? imageUrl = ApiRoutes.sanitizeImageUrl(
      rawImageUrl,
      useGin: true,
    );

    final String title = _getBookTitle(widget.book);

    final String format = (widget.book['format'] ?? '')
        .toString()
        .toLowerCase();
    final bool isPdf =
        format == 'pdf' ||
        (pdfUrl != null && pdfUrl.toLowerCase().contains('.pdf'));

    print("📖 [ReadingPage] Title: $title");
    print("📂 [ReadingPage] PDF URL: $pdfUrl");
    print("🖼️ [ReadingPage] Image URL: $imageUrl");

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        title: Text(
          title,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (isPdf && !_showCover && _isDocumentLoaded && _loadError == null)
            IconButton(
              icon: const Icon(Icons.menu_book, color: Colors.white),
              onPressed: () {
                _pdfViewerKey.currentState?.openBookmarkView();
              },
            ),
        ],
      ),
      body: _loadError != null
          ? _buildErrorView(_loadError!)
          : _buildBody(pdfUrl, imageUrl, isPdf),
      bottomNavigationBar:
          (!_showCover &&
              isPdf &&
              _isDocumentLoaded &&
              _totalPages > 0 &&
              _loadError == null)
          ? _buildBottomNavigation()
          : null,
    );
  }

  Widget _buildBody(String? pdfUrl, String? imageUrl, bool isPdf) {
    if (_showCover &&
        imageUrl != null &&
        imageUrl.isNotEmpty &&
        !imageUrl.contains('example.com')) {
      return _buildCoverView(imageUrl);
    }

    if (pdfUrl == null || pdfUrl.isEmpty) {
      return _buildErrorView("Aucun fichier disponible pour ce livre.");
    }

    if (!isPdf) {
      return _buildErrorView(
        "Le format de ce livre n'est pas encore supporté par la liseuse.",
      );
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
            _loadError = null;
          });

          // Jump to saved page if available
          if (_savedPage != null &&
              _savedPage! > 1 &&
              _savedPage! <= _totalPages) {
            // Small delay to ensure viewer is ready
            Future.delayed(const Duration(milliseconds: 100), () {
              _pdfViewerController.jumpToPage(_savedPage!);
            });
          }
        }
      },
      onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
        if (mounted) {
          print("❌ [ReadingPage] Load failed: ${details.error}");
          setState(() {
            _loadError =
                "Impossible de charger le document. Vérifiez votre connexion internet.\n\nErreur: ${details.error}";
          });
        }
      },
      onPageChanged: (PdfPageChangedDetails details) {
        if (mounted) {
          _onPageChanged(details.newPageNumber);
        }
      },
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.chevron_left,
                  color: Colors.white,
                  size: 24,
                ),
                onPressed: _currentPage > 1
                    ? () => _pdfViewerController.previousPage()
                    : null,
              ),
              Text(
                "Page $_currentPage / $_totalPages",
                style: GoogleFonts.poppins(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.chevron_right,
                  color: Colors.white,
                  size: 24,
                ),
                onPressed: _currentPage < _totalPages
                    ? () => _pdfViewerController.nextPage()
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCoverView(String imageUrl) {
    final String title = _getBookTitle(widget.book);
    final String author = _getAuthorName();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.35,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.book, size: 100, color: Colors.grey),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            author,
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: const Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => setState(() => _showCover = false),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              elevation: 0,
            ),
            child: Text(
              _savedPage != null && _savedPage! > 1
                  ? "Reprendre la lecture"
                  : "Commencer la lecture",
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (_savedPage != null && _savedPage! > 1)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                "Page $_savedPage",
                style: GoogleFonts.poppins(
                  color: const Color(0xFF94A3B8),
                  fontSize: 12,
                ),
              ),
            ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  String _getAuthorName() {
    // Essayer de récupérer le nom depuis l'objet Auteur/auteur
    final auteurObj =
        widget.book['Auteur'] ??
        widget.book['auteur'] ??
        widget.book['author'] ??
        widget.book['Utilisateur'];

    if (auteurObj is Map) {
      return auteurObj['NomComplet']?.toString() ??
          auteurObj['nom_complet']?.toString() ??
          auteurObj['nom']?.toString() ??
          'Auteur inconnu';
    }

    // Si c'est directement une String
    if (auteurObj is String) return auteurObj;

    // Fallback on top level name
    return widget.book['auteur_nom']?.toString() ??
        widget.book['author_name']?.toString() ??
        'Auteur inconnu';
  }

  // Robust Data Extraction Helpers
  String _getBookTitle(Map<String, dynamic> book) {
    return book['titre']?.toString() ??
        book['title']?.toString() ??
        'Sans titre';
  }

  String? _getBookImage(Map<String, dynamic> book) {
    return book['image_couverture']?.toString() ??
        book['imageCouverture']?.toString() ??
        book['image']?.toString();
  }

  String? _getBookFileUrl(Map<String, dynamic> book) {
    return book['fichier_url']?.toString() ??
        book['fichierUrl']?.toString() ??
        book['url']?.toString();
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
