import 'package:flutter/material.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/book_model.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/details/book_detail_page.dart';

class PublicationCard extends StatelessWidget {
  final BookModel book;
  final String? authorName;

  const PublicationCard({super.key, required this.book, this.authorName});

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
    bool isPublished = book.statut == "publie";

    final String formattedDate = book.creeLe != null
        ? "${book.creeLe!.day}/${book.creeLe!.month}/${book.creeLe!.year}"
        : "N/A";

    return GestureDetector(
      onTap: () {
        _navigateToBookDetail(context, book);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
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
                color: Colors.white10,
              ),
              child:
                  book.imageCouverture != null &&
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
                  : const Icon(Icons.book, color: Colors.white24, size: 30),
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
                            color: Colors.white,
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
                              ? Colors.green.withOpacity(0.2)
                              : Colors.orange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isPublished ? "Publié" : book.statut,
                          style: TextStyle(
                            color: isPublished
                                ? Colors.green.shade400
                                : Colors.orange.shade400,
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
                      color: Colors.grey[400],
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
                        book.noteMoyenne.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
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
                        "${book.telechargements}",
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[400],
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
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => BookDetailPage(
                                book: book,
                                isOwned: true,
                                showCart: false,
                              ),
                            ),
                          );
                        },
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: "${book.prix} ",
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const TextSpan(
                                text: "€",
                                style: TextStyle(fontWeight: FontWeight.normal),
                              ),
                            ],
                            style: const TextStyle(
                              fontSize: 15,
                              color: Color(0xFF38BDF8),
                            ),
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
