import 'package:flutter/material.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/bookModel.dart';
import '../../details/book_detail_page.dart';

class PublicationCard extends StatelessWidget {
  final BookModel book;
  final String? authorName;

  const PublicationCard({super.key, required this.book, this.authorName});

  @override
  Widget build(BuildContext context) {
    bool isPublished = book.statut == "publie";

    // Convert BookModel to the format expected by BookDetailPage if necessary
    // or update BookDetailPage to accept BookModel
    final bookData = {
      'id': book.id,
      'title': book.titre,
      'author': authorName ?? 'Mon livre',
      'description': book.description,
      'image': book.imageCouverture,
      'price': book.prix,
      'format': book.format,
      'fichier_url': book.fichierUrl,
      'note_moyenne': book.noteMoyenne ?? 0.0,
      'telechargements': book.telechargements ?? 0,
      'cree_le': book.creeLe,
      'chapters': [], // Add chapters if available in your model
    };

    final String formattedDate = book.creeLe != null
        ? "${book.creeLe!.day}/${book.creeLe!.month}/${book.creeLe!.year}"
        : "N/A";

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BookDetailPage(book: bookData),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Section
            Container(
              width: 80,
              height: 110,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey[100],
              ),
              child: book.imageCouverture != null &&
                      book.imageCouverture!.isNotEmpty &&
                      !book.imageCouverture!.contains('example.com')
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        book.imageCouverture!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.book,
                            color: Colors.grey,
                            size: 30,
                          );
                        },
                      ),
                    )
                  : const Icon(Icons.book, color: Colors.grey, size: 30),
            ),
            const SizedBox(width: 16),
            // Content Section
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          book.titre,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: Color(0xFF1E293B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isPublished
                              ? Colors.green.shade50
                              : Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isPublished ? "Publié" : book.statut,
                          style: TextStyle(
                            color: isPublished
                                ? Colors.green.shade700
                                : Colors.orange.shade700,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    authorName ?? book.authorName,
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Stats Row
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        (book.noteMoyenne ?? 0.0).toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Icon(
                        Icons.download_rounded,
                        color: Color(0xFF64748B),
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "${book.telechargements ?? 0}",
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Bottom Row: Price & Date
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: "${book.prix} ",
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const TextSpan(
                              text: "FCFA",
                              style: TextStyle(
                                fontWeight: FontWeight.normal,
                              ),
                            ),
                          ],
                          style: const TextStyle(
                            fontSize: 15,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_outlined,
                            color: Colors.grey,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            formattedDate,
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
