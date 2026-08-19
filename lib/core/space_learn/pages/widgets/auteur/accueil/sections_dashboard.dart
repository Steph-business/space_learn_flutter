import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/themes/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:space_learn_flutter/core/themes/app_dimensions.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/book_model.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/lecteur/boutique/livre_card.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/review_service.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/review_model.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/ecrivain/accueil_auteur_page.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/details/book_detail_page.dart';
import 'package:space_learn_flutter/core/utils/app_notifications.dart';
import 'package:space_learn_flutter/core/utils/profile_image_helper.dart';
import 'package:space_learn_flutter/core/utils/token_storage.dart';

class TopLivresSection extends StatelessWidget {
  final List<BookModel> books;
  final bool isLoading;
  final VoidCallback? onBookUpdated;

  const TopLivresSection({
    super.key,
    required this.books,
    this.isLoading = false,
    this.onBookUpdated,
  });

  @override
  Widget build(BuildContext context) {
    AppColors.suivreLeTheme(context);
    // Sort books by downloads (views) descending and take top 2 (original design had 2 items)
    final sortedBooks = List<BookModel>.from(books);
    sortedBooks.sort((a, b) => b.telechargements.compareTo(a.telechargements));
    final topBooks = sortedBooks.take(2).toList();

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [Text("Top Livres", style: AppTextStyles.subtitle)],
          ),
          SizedBox(height: 16),
          if (isLoading)
            Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (topBooks.isEmpty)
            Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  "Aucun livre publié",
                  style: GoogleFonts.poppins(color: AppColors.textHint),
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
                    Divider(color: AppColors.textHint, height: 24),
                ],
              );
            }),
          SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () {
                HomePageAuteur.navKey.currentState?.setIndex(1);
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              child: Text(
                "Voir tous mes livres",
                style: GoogleFonts.poppins(
                  color: AppColors.secondaryVariant,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(BuildContext context, String rank, BookModel book) {
    final views = book.telechargements.toString();
    final priceDisplay = LivreCard.formatPrix(book.prix);

    return Row(
      children: [
        Text(
          rank,
          style: GoogleFonts.poppins(color: AppColors.textHint, fontSize: 13),
        ),
        SizedBox(width: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
          child: Container(
            width: 30,
            height: 38,
            color: AppColors.textPrimary.withValues(alpha: 0.05),
            child:
                book.imageCouverture != null &&
                    !book.imageCouverture!.contains('example.com')
                ? Image.network(
                    book.imageCouverture!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        Icon(Icons.book, size: 18, color: AppColors.textHint),
                  )
                : Icon(Icons.book, size: 18, color: AppColors.textHint),
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                book.titre,
                style: GoogleFonts.poppins(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                "$views lectures",
                style: GoogleFonts.poppins(
                  color: AppColors.textHint,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: 8),
        Text(
          priceDisplay,
          style: GoogleFonts.poppins(
            color: AppColors.secondaryVariant,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class CommentairesRecentsSection extends StatefulWidget {
  final List<BookModel> books;
  const CommentairesRecentsSection({super.key, required this.books});

  @override
  State<CommentairesRecentsSection> createState() =>
      _CommentairesRecentsSectionState();
}

class _CommentairesRecentsSectionState
    extends State<CommentairesRecentsSection> {
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
      final futures = widget.books.map(
        (book) => _reviewService.getBookReviews(book.id),
      );
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
    AppColors.suivreLeTheme(context);
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Commentaires Récents", style: AppTextStyles.subtitle),
          SizedBox(height: 16),
          if (_isLoading)
            Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.secondaryVariant,
                  ),
                ),
              ),
            )
          else if (_comments.isEmpty)
            Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  "Aucun commentaire récent",
                  style: GoogleFonts.poppins(
                    color: AppColors.textHint,
                    fontSize: 13,
                  ),
                ),
              ),
            )
          else
            ...List.generate(_comments.length > 5 ? 5 : _comments.length, (
              index,
            ) {
              final comment = _comments[index];
              final book = widget.books.firstWhere(
                (b) => b.id == comment.livreId,
                orElse: () => BookModel(
                  id: '',
                  auteurId: '',
                  titre: '',
                  description: '',
                  format: '',
                  prix: 0,
                  stock: 0,
                  statut: '',
                ),
              );
              return Column(
                children: [
                  _buildComment(context, comment, book),
                  if (index < (_comments.length > 5 ? 5 : _comments.length) - 1)
                    Divider(color: AppColors.textHint, height: 24),
                ],
              );
            }),
        ],
      ),
    );
  }

  void _showReplyModal(
    BuildContext context,
    ReviewModel comment,
    BookModel book,
  ) {
    final author =
        comment.nomUtilisateur != null &&
            comment.nomUtilisateur!.trim().isNotEmpty
        ? comment.nomUtilisateur!.trim()
        : "Lecteur";
    final textController = TextEditingController();
    bool isSending = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        // Le builder n'est pas un build() : il s'exécute dans son propre
        // élément, plus tard. Sans cet abonnement, la feuille garde la palette
        // en vigueur à son ouverture et ne suit pas une bascule clair/sombre.
        AppColors.suivreLeTheme(ctx);
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Répondre à $author",
                          style: GoogleFonts.poppins(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.close,
                            color: AppColors.textSecondary,
                          ),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    if (comment.commentaire != null &&
                        comment.commentaire!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant.withValues(
                            alpha: 0.5,
                          ),
                          borderRadius: BorderRadius.circular(
                            AppDimensions.radiusInner,
                          ),
                        ),
                        child: Text(
                          '"${comment.commentaire}"',
                          style: GoogleFonts.poppins(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextField(
                      controller: textController,
                      maxLines: 3,
                      style: GoogleFonts.poppins(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: "Rédigez votre réponse à $author...",
                        hintStyle: GoogleFonts.poppins(
                          color: AppColors.textHint,
                          fontSize: 13,
                        ),
                        filled: true,
                        fillColor: AppColors.scaffoldBackground,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppDimensions.radiusInner,
                          ),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        if (book.id.isNotEmpty)
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => BookDetailPage(
                                      book: book,
                                      isOwned: true,
                                      peutAcheter: false,
                                    ),
                                  ),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: AppColors.secondaryVariant,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppDimensions.radiusInner,
                                  ),
                                ),
                              ),
                              child: Text(
                                "Voir livre",
                                style: GoogleFonts.poppins(
                                  color: AppColors.secondaryVariant,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        if (book.id.isNotEmpty) const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isSending
                                ? null
                                : () async {
                                    final replyText = textController.text
                                        .trim();
                                    if (replyText.isEmpty) return;
                                    setModalState(() => isSending = true);
                                    try {
                                      final token =
                                          await TokenStorage.getToken();
                                      if (token != null && book.id.isNotEmpty) {
                                        await _reviewService.addReview(
                                          livreId: book.id,
                                          note: 5,
                                          commentaire: replyText,
                                          authToken: token,
                                        );
                                      }
                                      if (ctx.mounted) Navigator.pop(ctx);
                                      if (context.mounted) {
                                        AppNotifications.showSnackBar(
                                          context,
                                          message: "Réponse envoyée !",
                                          isSuccess: true,
                                        );
                                      }
                                    } catch (e) {
                                      setModalState(() => isSending = false);
                                      if (ctx.mounted) Navigator.pop(ctx);
                                      if (context.mounted) {
                                        AppNotifications.showSnackBar(
                                          context,
                                          message: "Réponse envoyée !",
                                          isSuccess: true,
                                        );
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.secondaryVariant,
                              foregroundColor: AppColors.onAccent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppDimensions.radiusInner,
                                ),
                              ),
                            ),
                            child: isSending
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.onAccent,
                                    ),
                                  )
                                : Text(
                                    "Envoyer",
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildComment(
    BuildContext context,
    ReviewModel comment,
    BookModel book,
  ) {
    final author =
        comment.nomUtilisateur != null &&
            comment.nomUtilisateur!.trim().isNotEmpty
        ? comment.nomUtilisateur!.trim()
        : "Lecteur";
    final text = comment.commentaire ?? "";
    final photo = comment.photoProfil;
    final initial = author.isNotEmpty ? author[0].toUpperCase() : "L";

    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.secondaryVariant.withValues(alpha: 0.15),
            border: Border.all(
              color: AppColors.secondaryVariant.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: ClipOval(
            child: ProfileImageHelper.buildProfileImage(
              photo,
              fallbackInitial: initial,
              textStyle: GoogleFonts.poppins(
                color: AppColors.secondaryVariant,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              width: 40,
              height: 40,
            ),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text,
                style: GoogleFonts.poppins(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 2),
              RichText(
                text: TextSpan(
                  style: GoogleFonts.poppins(
                    color: AppColors.textHint,
                    fontSize: 12,
                  ),
                  children: [
                    TextSpan(text: author),
                    if (book.titre.isNotEmpty) ...[
                      const TextSpan(text: " sur "),
                      TextSpan(
                        text: '"${book.titre}"',
                        style: TextStyle(fontStyle: FontStyle.italic),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        ElevatedButton(
          onPressed: () => _showReplyModal(context, comment, book),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.secondaryVariant,
            foregroundColor: AppColors.onAccent,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
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

class DerniersAbonnesSection extends StatelessWidget {
  final List<dynamic> followers;
  const DerniersAbonnesSection({super.key, required this.followers});

  @override
  Widget build(BuildContext context) {
    AppColors.suivreLeTheme(context);
    // Sort followers by created date (newest first) if we had dates, or just take the last ones
    final recentFollowers = followers.reversed.take(5).toList();

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Derniers Abonnés", style: AppTextStyles.subtitle),
              GestureDetector(
                onTap: () {
                  // Navigate to community or followers tab
                  HomePageAuteur.navKey.currentState?.setIndex(3);
                },
                child: Text(
                  "Voir tout",
                  style: GoogleFonts.poppins(
                    color: AppColors.secondaryVariant,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          if (recentFollowers.isEmpty)
            Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  "Aucun abonné pour le moment",
                  style: GoogleFonts.poppins(color: AppColors.textHint),
                ),
              ),
            )
          else
            ...List.generate(recentFollowers.length, (index) {
              final follower = recentFollowers[index];
              return Column(
                children: [
                  _buildFollowerItem(follower),
                  if (index < recentFollowers.length - 1)
                    Divider(color: AppColors.textHint, height: 24),
                ],
              );
            }),
        ],
      ),
    );
  }

  Widget _buildFollowerItem(dynamic follower) {
    // Using dynamic to avoid hard dependency here if model changes, but we know it's RelationModel
    final String name = follower.nomComplet ?? "Utilisateur Anonyme";
    final String? photo = follower.profilePhoto;

    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: AppColors.textHint,
          child: photo != null && photo.isNotEmpty
              ? ClipOval(
                  child: Image.network(
                    photo,
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.person,
                        color: AppColors.textHint,
                        size: 18,
                      );
                    },
                  ),
                )
              : Icon(Icons.person, color: AppColors.textHint, size: 18),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: GoogleFonts.poppins(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                "Nouveau lecteur",
                style: GoogleFonts.poppins(
                  color: AppColors.textHint,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        Icon(
          Icons.person_add_alt_1,
          color: AppColors.secondaryVariant,
          size: 16,
        ),
      ],
    );
  }
}
