import 'package:flutter/material.dart';

class TemplatesWidget extends StatelessWidget {
  const TemplatesWidget({super.key});

  Widget _templateCard(
    BuildContext context,
    String name,
    IconData icon,
    Color color,
    String description,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          // Afficher un dialog de confirmation
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text('Utiliser le template "$name"'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(description),
                    const SizedBox(height: 16),
                    const Text(
                      'Cette action va créer un nouveau chapitre avec la structure du template sélectionné.',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Annuler'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      // Créer un nouveau chapitre avec le template
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Template "$name" appliqué avec succès ! Un nouveau chapitre a été créé.',
                          ),
                          backgroundColor: Colors.green,
                          duration: const Duration(seconds: 3),
                        ),
                      );
                      // Ici, on pourrait naviguer vers l'éditeur de texte avec le contenu du template pré-rempli
                      // Pour l'instant, on reste sur la page actuelle avec le feedback
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: color),
                    child: const Text('Utiliser'),
                  ),
                ],
              );
            },
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(icon, color: color, size: 30),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Templates disponibles",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 16),
          _templateCard(
            context,
            "Roman classique",
            Icons.book_rounded,
            Colors.blue,
            "Structure traditionnelle avec introduction, développement et conclusion. Idéal pour les récits longs.",
          ),
          const SizedBox(height: 12),
          _templateCard(
            context,
            "Article de blog",
            Icons.article_rounded,
            Colors.orange,
            "Format optimisé pour le web avec titre accrocheur, introduction et sections thématiques.",
          ),
          const SizedBox(height: 12),
          _templateCard(
            context,
            "Essai académique",
            Icons.school_rounded,
            Colors.purple,
            "Structure formelle avec thèse, arguments et bibliographie. Parfait pour les travaux universitaires.",
          ),
        ],
      ),
    );
  }
}
