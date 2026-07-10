import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/themes/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/book_model.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/ecrivain/ajouter_livre_page.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/review_service.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/review_model.dart';

class TopLivresSection extends StatelessWidget {
  final List<BookModel> books;
  final bool isLoading;

  const TopLivresSection({
    super.key,
    required this.books,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    // Sort books by downloads (views) descending and take top 2 (original design had 2 items)
    final sortedBooks = List<BookModel>.from(books);
    sortedBooks.sort((a, b) => b.telechargements.compareTo(a.telechargements));
    final topBooks = sortedBooks.take(2).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Top Livres", style: AppTextStyles.subtitle),
              Row(
                children: [
                  Text(
                    "Lectures",
                    style: GoogleFonts.poppins(
                      color: Colors.white38,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Text(
                    "Revenus",
                    style: GoogleFonts.poppins(
                      color: Colors.white38,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (topBooks.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  "Aucun livre publié",
                  style: GoogleFonts.poppins(color: Colors.white38),
                ),
              ),
            )
          else
            ...List.generate(topBooks.length, (index) {
              final book = topBooks[index];
              return Column(
                children: [
                  _buildItem(context, "${index + 1}", book),
                  if (index < topBooks.length - 1)
                    const Divider(color: Colors.white10, height: 24),
                ],
              );
            }),
          const SizedBox(height: 8),
          Center(
            child: Text(
              "Voir tous mes livres",
              style: GoogleFonts.poppins(
                color: AppColors.secondaryVariant,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(BuildContext context, String rank, BookModel book) {
    final views = book.telechargements.toString();
    final revenue =
        "${(book.prix * book.telechargements).toStringAsFixed(0)} FCFA";

    return Row(
      children: [
        Text(
          rank,
          style: GoogleFonts.poppins(color: Colors.white38, fontSize: 13),
        ),
        const SizedBox(width: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Container(
            width: 30,
            height: 38,
            color: Colors.white10,
            child: const Icon(Icons.book, size: 18, color: Colors.white24),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                book.titre,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                "$views lectures",
                style: GoogleFonts.poppins(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          revenue,
          style: GoogleFonts.poppins(
            color: AppColors.secondaryVariant,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AjouterLivrePage(book: book),
              ),
            );
          },
          icon: const Icon(
            Icons.edit_note_rounded,
            color: Colors.white54,
            size: 22,
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }
}

class CommentairesRecentsSection extends StatefulWidget {
  final List<BookModel> books;
  const CommentairesRecentsSection({super.key, required this.books});

  @override
  State<CommentairesRecentsSection> createState() => _CommentairesRecentsSectionState();
}

class _CommentairesRecentsSectionState extends State<CommentairesRecentsSection> {
  final ReviewService _reviewService = ReviewService();
  List<ReviewModel> _comments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void didUpdateWidget(CommentairesRecentsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.books.length != oldWidget.books.length) {
      _loadComments();
    }
  }

  Future<void> _loadComments() async {
    if (widget.books.isEmpty) {
      if (mounted) {
        setState(() {
          _comments = [];
          _isLoading = false;
        });
      }
      return;
    }

    try {
      final List<ReviewModel> allReviews = [];
      final futures = widget.books.map((book) => _reviewService.getBookReviews(book.id));
      final results = await Future.wait(futures);
      
      for (final list in results) {
        allReviews.addAll(list);
      }

      allReviews.sort((a, b) {
        if (a.creeLe == null && b.creeLe == null) return 0;
        if (a.creeLe == null) return 1;
        if (b.creeLe == null) return -1;
        return b.creeLe!.compareTo(a.creeLe!);
      });

      if (mounted) {
        setState(() {
          _comments = allReviews;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Commentaires Récents", style: AppTextStyles.subtitle),
          const SizedBox(height: 16),
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.secondaryVariant),
                ),
              ),
            )
          else if (_comments.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  "Aucun commentaire récent",
                  style: GoogleFonts.poppins(color: Colors.white38, fontSize: 13),
                ),
              ),
            )
          else
            ...List.generate(
              _comments.length > 5 ? 5 : _comments.length,
              (index) {
                final comment = _comments[index];
                final book = widget.books.firstWhere(
                  (b) => b.id == comment.livreId,
                  orElse: () => BookModel(id: '', auteurId: '', titre: '', description: '', format: '', prix: 0, stock: 0, statut: ''),
                );
                return Column(
                  children: [
                    _buildComment(comment, book.titre),
                    if (index < (_comments.length > 5 ? 5 : _comments.length) - 1)
                      const Divider(color: Colors.white10, height: 24),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildComment(ReviewModel comment, String bookTitle) {
    final author = comment.nomUtilisateur != null && comment.nomUtilisateur!.isNotEmpty
        ? comment.nomUtilisateur!
        : "Lecteur";
    final text = comment.commentaire ?? "";
    final photo = comment.photoProfil;

    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: Colors.white10,
          child: photo != null && photo.isNotEmpty
              ? ClipOval(
                  child: Image.network(
                    photo,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.person, color: Colors.white24);
                    },
                  ),
                )
              : const Icon(Icons.person, color: Colors.white24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              RichText(
                text: TextSpan(
                  style: GoogleFonts.poppins(color: Colors.white38, fontSize: 12),
                  children: [
                    TextSpan(text: author),
                    if (bookTitle.isNotEmpty) ...[
                      const TextSpan(text: " sur "),
                      TextSpan(
                        text: '"$bookTitle"',
                        style: const TextStyle(fontStyle: FontStyle.italic),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        ElevatedButton(
          onPressed: () {},
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.secondaryVariant,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            "Répondre",
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class ConseilsPublicationSection extends StatelessWidget {
  const ConseilsPublicationSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Conseils de Publication", style: AppTextStyles.subtitle),
          const SizedBox(height: 16),
          _buildTip("📣", "Promouvoir sur les réseaux sociaux (FB, Insta)"),
          const SizedBox(height: 12),
          _buildTip("📔", "Créer des couvertures accrocheuses"),
          const SizedBox(height: 12),
          _buildTip("💬", "Participer aux discussions communautaires"),
        ],
      ),
    );
  }

  Widget _buildTip(String icon, String text) {
    return Row(
      children: [
        Text(icon, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: AppTextStyles.body)),
      ],
    );
  }
}
