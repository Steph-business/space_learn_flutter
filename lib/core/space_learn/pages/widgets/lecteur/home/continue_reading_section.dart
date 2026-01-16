import 'package:flutter/material.dart';

class ContinueReadingSection extends StatelessWidget {
  final Map<String, dynamic> book;
  final VoidCallback? onTap;

  const ContinueReadingSection({super.key, required this.book, this.onTap});

  @override
  Widget build(BuildContext context) {
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
                      "Continuer la lecture (PDF/EPUB)",
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 8),
                    // Removed progress bar as it was chapter based.
                    // Could be replaced by last page read if implemented.
                  ],
                ),
              ),
              const Icon(Icons.play_arrow, color: Colors.deepPurple),
            ],
          ),
        ),
      ),
    );
  }
}
