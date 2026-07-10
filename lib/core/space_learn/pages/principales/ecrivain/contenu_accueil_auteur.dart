import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/themes/app_text_styles.dart';
import 'package:flutter/material.dart';

import 'package:space_learn_flutter/core/space_learn/pages/widgets/auteur/accueil/revenus.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/auteur/accueil/statistique.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/ecrivain/ajouter_livre_page.dart';

import 'package:space_learn_flutter/core/space_learn/pages/widgets/auteur/accueil/sections_dashboard.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/bookService.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/book_model.dart';

class HomeContentAuteur extends StatefulWidget {
  final String profileId;
  final String userName;

  const HomeContentAuteur({
    super.key,
    required this.profileId,
    required this.userName,
  });

  @override
  State<HomeContentAuteur> createState() => _HomeContentAuteurState();
}

class _HomeContentAuteurState extends State<HomeContentAuteur> {
  final BookService _bookService = BookService();
  List<BookModel> _books = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final books = await _bookService.getBooksByAuthorId(widget.profileId);
      if (mounted) {
        setState(() {
          _books = books;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.secondaryVariant,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            Statistique(books: _books),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Revenus(books: _books),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AjouterLivrePage(),
                      ),
                    );
                    if (result == true) _loadData();
                  },
                  icon: const Icon(
                    Icons.add_circle,
                    color: Colors.white,
                    size: 24,
                  ),
                  label: Text(
                    "Publier un nouveau livre",
                    style: AppTextStyles.subtitle,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondaryVariant,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: TopLivresSection(books: _books, isLoading: _isLoading),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: CommentairesRecentsSection(books: _books),
            ),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: ConseilsPublicationSection(),
            ),

            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}
