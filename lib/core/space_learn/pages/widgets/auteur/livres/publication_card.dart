import 'package:flutter/material.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/book_model.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/details/book_detail_page.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/ecrivain/ajouter_livre_page.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/ecrivain/statistiques_livre_page.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/bookService.dart';
import 'package:space_learn_flutter/core/utils/token_storage.dart';

class PublicationCard extends StatelessWidget {
  final BookModel book;
  final String? authorName;
  final VoidCallback? onBookUpdated;

  const PublicationCard({
    super.key,
    required this.book,
    this.authorName,
    this.onBookUpdated,
  });

  void _navigateToBookDetail(BuildContext context, BookModel book) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            BookDetailPage(book: book, isOwned: true, showCart: false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Determine an appropriate format for the date
    final String formattedDate = book.creeLe != null
        ? "${_monthName(book.creeLe!.month)} ${book.creeLe!.year}"
        : "N/A";

    return GestureDetector(
      onTap: () {
        _navigateToBookDetail(context, book);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Image Section
            Container(
              width: 70,
              height: 90,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.white10,
              ),
              child:
                  book.imageCouverture != null &&
                      book.imageCouverture!.isNotEmpty &&
                      !book.imageCouverture!.contains('example.com')
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        book.imageCouverture!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.book,
                            color: Colors.white24,
                            size: 30,
                          );
                        },
                      ),
                    )
                  : const Icon(Icons.book, color: Colors.white24, size: 30),
            ),
            const SizedBox(width: 16),

            // Content Section
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.titre,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    formattedDate,
                    style: TextStyle(color: Colors.grey[400], fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "${book.prix} €",
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // Action Buttons Section
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildActionButton(
                  icon: Icons.edit,
                  label: "Modifier",
                  color: const Color(0xFF0EA5E9),
                  onTap: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AjouterLivrePage(book: book),
                      ),
                    );
                    if (result == true && onBookUpdated != null) {
                      onBookUpdated!();
                    }
                  },
                ),
                const SizedBox(width: 12),
                _buildActionButton(
                  icon: Icons.bar_chart,
                  label: "Statistiques",
                  color: const Color(0xFF10B981), // Green
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => StatistiquesLivrePage(book: book),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 12),
                PopupMenuButton<String>(
                  color: const Color(0xFF1E293B),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.white.withOpacity(0.05)),
                  ),
                  offset: const Offset(0, 40),
                  onSelected: (value) {
                    if (value == 'archive') {
                      _handleArchive(context);
                    } else if (value == 'delete') {
                      _handleDelete(context);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'archive',
                      child: Row(
                        children: [
                          Icon(
                            Icons.archive_outlined,
                            color: Colors.white70,
                            size: 20,
                          ),
                          SizedBox(width: 12),
                          Text(
                            "Archiver",
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(height: 1),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline,
                            color: Colors.redAccent,
                            size: 20,
                          ),
                          SizedBox(width: 12),
                          Text(
                            "Supprimer",
                            style: TextStyle(color: Colors.redAccent),
                          ),
                        ],
                      ),
                    ),
                  ],
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.more_horiz,
                      color: Colors.white70,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    Color iconColor = Colors.white,
    bool isIconOnly = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(isIconOnly ? 6 : 10),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          if (!isIconOnly) ...[
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[400],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _monthName(int month) {
    const months = [
      "",
      "Jan",
      "Fév",
      "Mars",
      "Avr",
      "Mai",
      "Juin",
      "Juil",
      "Août",
      "Sept",
      "Oct",
      "Nov",
      "Déc",
    ];
    if (month >= 1 && month <= 12) return months[month];
    return "$month";
  }

  void _handleArchive(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Fonction d'archivage en cours de développement."),
        backgroundColor: Color(0xFF1E293B),
      ),
    );
  }

  void _handleDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          "Supprimer l'œuvre",
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          "Êtes-vous sûr de vouloir supprimer ce livre ? Cette action est irréversible.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Annuler",
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final token = await TokenStorage.getToken();
                if (token != null) {
                  await BookService().deleteBook(book.id, token);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Livre supprimé avec succès"),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                  if (onBookUpdated != null) {
                    onBookUpdated!();
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Erreur lors de la suppression : $e"),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text(
              "Supprimer",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
