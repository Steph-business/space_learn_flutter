import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/themes/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/bookService.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/relationService.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/book_model.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/user_model.dart';
import 'package:space_learn_flutter/core/utils/token_storage.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/details/book_detail_page.dart';
import 'package:space_learn_flutter/core/utils/profile_image_helper.dart';

class AuthorProfilePage extends StatefulWidget {
  final UserModel author;
  final bool initialIsFollowing;

  const AuthorProfilePage({
    super.key,
    required this.author,
    this.initialIsFollowing = false,
  });

  @override
  State<AuthorProfilePage> createState() => _AuthorProfilePageState();
}

class _AuthorProfilePageState extends State<AuthorProfilePage> {
  final BookService _bookService = BookService();
  final RelationService _relationService = RelationService();

  List<BookModel> _authorBooks = [];
  bool _isLoadingBooks = true;
  bool _isFollowing = false;
  int _followerCount = 0;

  @override
  void initState() {
    super.initState();
    _isFollowing = widget.initialIsFollowing;
    _loadAuthorData();
  }

  Future<void> _loadAuthorData() async {
    setState(() => _isLoadingBooks = true);
    try {
      final results = await Future.wait([
        _bookService.getBooksByAuthorId(widget.author.id),
        _relationService.getFollowers(widget.author.id),
      ]);

      if (mounted) {
        setState(() {
          _authorBooks = results[0] as List<BookModel>;
          _followerCount = (results[1] as List).length;
          _isLoadingBooks = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingBooks = false);
      }
    }
  }

  Future<void> _toggleFollow() async {
    final token = await TokenStorage.getToken();
    if (token == null) return;

    final originalFollowing = _isFollowing;
    final originalCount = _followerCount;

    setState(() {
      _isFollowing = !_isFollowing;
      _followerCount += _isFollowing ? 1 : -1;
    });

    try {
      if (_isFollowing) {
        await _relationService.followUser(widget.author.id, token);
      } else {
        await _relationService.unfollowUser(widget.author.id, token);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isFollowing = originalFollowing;
          _followerCount = originalCount;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(child: _buildProfileInfo()),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverToBoxAdapter(
              child: Text(
                "Ses livres",
                style: AppTextStyles.sectionTitle,
              ),
            ),
          ),
          _buildBooksGrid(),
          SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: AppColors.cardBackground,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.secondary, AppColors.scaffoldBackground],
                ),
              ),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: 40),
                  CircleAvatar(
                    radius: 45,
                    backgroundColor: AppColors.cardBackground,
                    backgroundImage: ProfileImageHelper.getProfileImageProvider(widget.author.profilePhoto),
                    child: widget.author.profilePhoto == null
                        ? Text(
                            widget.author.nomComplet
                                .substring(0, 1)
                                .toUpperCase(),
                            style: AppTextStyles.statBig,
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileInfo() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          SizedBox(height: 16),
          Text(
            widget.author.nomComplet,
            style: AppTextStyles.pageTitle,
          ),
          Text(
            widget.author.biography ?? "Écrivain passionné sur SpaceLearn",
            textAlign: TextAlign.center,
            style: AppTextStyles.grey14,
          ),
          SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStatWidget(_followerCount.toString(), "Abonnés"),
              SizedBox(width: 40),
              _buildStatWidget(_authorBooks.length.toString(), "Livres"),
            ],
          ),
          SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _toggleFollow,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isFollowing
                    ? AppColors.textHint
                    : AppColors.secondary,
                foregroundColor: AppColors.textPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: _isFollowing
                      ? BorderSide(color: AppColors.textHint)
                      : BorderSide.none,
                ),
              ),
              child: Text(
                _isFollowing ? "Suivi" : "Suivre ${widget.author.nomComplet}",
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatWidget(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.poppins(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: AppTextStyles.greyMedium12,
        ),
      ],
    );
  }

  Widget _buildBooksGrid() {
    if (_isLoadingBooks) {
      return SliverToBoxAdapter(
        child: Center(
          child: Text(
            "Chargement des livres...",
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    if (_authorBooks.isEmpty) {
      return SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(40.0),
            child: Text(
              "Aucun livre publié pour le moment.",
              style: GoogleFonts.poppins(color: AppColors.textSecondary),
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.65,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          final book = _authorBooks[index];
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BookDetailPage(book: book),
                ),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(12),
                
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                      child: book.imageCouverture != null
                          ? Image.network(
                              book.imageCouverture!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                            )
                          : Container(
                              color: Colors.blueGrey,
                              child: Center(
                                child: Icon(Icons.book, color: AppColors.textPrimary),
                              ),
                            ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          book.titre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.cardTitle,
                        ),
                        Text(
                          book.prix == 0 ? "Gratuit" : "${book.prix}FCFA",
                          style: GoogleFonts.poppins(
                            color: AppColors.secondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }, childCount: _authorBooks.length),
      ),
    );
  }
}