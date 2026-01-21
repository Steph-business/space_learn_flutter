import 'package:flutter/material.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/bookModel.dart';
import 'publication_card.dart';

class PublicationsList extends StatelessWidget {
  final List<BookModel> books;
  final String? authorName;
  const PublicationsList({super.key, required this.books, this.authorName});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Publications",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        ...books.map((book) => PublicationCard(book: book, authorName: authorName)),
      ],
    );
  }
}
