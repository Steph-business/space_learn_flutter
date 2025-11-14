import 'package:flutter/material.dart';

import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/themes/app_text_styles.dart';

class ReadingPage extends StatefulWidget {
  final Map<String, dynamic> book;
  final Map<String, dynamic> chapter;
  final int chapterIndex;

  const ReadingPage({
    super.key,
    required this.book,
    required this.chapter,
    required this.chapterIndex,
  });

  @override
  State<ReadingPage> createState() => _ReadingPageState();
}

class _ReadingPageState extends State<ReadingPage> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextChapter() {
    final chapters = widget.book['chapters'] as List?;
    if (chapters != null && widget.chapterIndex < chapters.length - 1) {
      final nextChapter = chapters[widget.chapterIndex + 1];
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ReadingPage(
            book: widget.book,
            chapter: nextChapter,
            chapterIndex: widget.chapterIndex + 1,
          ),
        ),
      );
    }
  }

  void _previousChapter() {
    final chapters = widget.book['chapters'] as List?;
    if (chapters != null && widget.chapterIndex > 0) {
      final prevChapter = chapters[widget.chapterIndex - 1];
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ReadingPage(
            book: widget.book,
            chapter: prevChapter,
            chapterIndex: widget.chapterIndex - 1,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final chapters = widget.book['chapters'] as List?;
    final totalChapters = chapters?.length ?? 0;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text(
          widget.book['title'] ?? 'Lecture',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Text(
              '${widget.chapterIndex + 1}/$totalChapters',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Barre de progression
          LinearProgressIndicator(
            value: (widget.chapterIndex + 1) / totalChapters,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),

          // Contenu du chapitre
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Titre du chapitre
                  Text(
                    widget.chapter['title'] ?? 'Chapitre',
                    style: AppTextStyles.heading,
                  ),
                  const SizedBox(height: 20),

                  // Contenu du chapitre
                  Text(
                    widget.chapter['content'] ?? 'Contenu non disponible.',
                    style: AppTextStyles.bodyText1.copyWith(
                      height: 1.6,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Navigation entre chapitres
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton.icon(
                  onPressed: widget.chapterIndex > 0 ? _previousChapter : null,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Chapitre précédent'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.chapterIndex > 0
                        ? AppColors.primary
                        : Colors.grey,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: widget.chapterIndex < totalChapters - 1
                      ? _nextChapter
                      : null,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Chapitre suivant'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.chapterIndex < totalChapters - 1
                        ? AppColors.primary
                        : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
