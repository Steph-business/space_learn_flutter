import 'package:flutter/material.dart';

class ContinueReadingSection extends StatelessWidget {
  final Map<String, dynamic> book;
  final Map<String, dynamic> chapter;
  final int chapterIndex;
  final VoidCallback? onTap;

  const ContinueReadingSection({
    super.key,
    required this.book,
    required this.chapter,
    required this.chapterIndex,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final chapters = book['chapters'] as List?;
    final totalChapters = chapters?.length ?? 1;
    final progress = (chapterIndex + 1) / totalChapters;

    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              const Icon(Icons.book, color: Colors.deepPurple, size: 40),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book['title'] ?? "Titre du livre",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${chapter['title'] ?? 'Chapitre'} - Chapitre ${chapterIndex + 1}",
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.grey,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.deepPurple,
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
  }
}
