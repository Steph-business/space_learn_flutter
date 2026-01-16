import 'package:flutter/material.dart';
import 'package:space_learn_flutter/core/themes/app_colors.dart';

class ReadingPage extends StatelessWidget {
  final Map<String, dynamic> book;

  const ReadingPage({super.key, required this.book});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text(
          book['title'] ?? 'Lecture',
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
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.menu_book, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              "Liseuse PDF / EPUB",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "Ouverture du fichier : ${book['fichier_url'] ?? 'Inconnu'}",
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                // Logic to open actual file viewer would go here
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Ouverture de la liseuse...")),
                );
              },
              child: const Text("Ouvrir le fichier"),
            ),
          ],
        ),
      ),
    );
  }
}
