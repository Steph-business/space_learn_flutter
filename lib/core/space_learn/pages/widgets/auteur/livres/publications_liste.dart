import 'package:flutter/material.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/book_model.dart';
import 'publication_card.dart';

class PublicationsList extends StatelessWidget {
  final List<BookModel> books;
  final String? authorName;
  final VoidCallback? onBookUpdated;
  const PublicationsList({
    super.key,
    required this.books,
    this.authorName,
    this.onBookUpdated,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...books.map(
          (book) => PublicationCard(
            book: book,
            authorName: authorName,
            onBookUpdated: onBookUpdated,
          ),
        ),
      ],
    );
  }
}