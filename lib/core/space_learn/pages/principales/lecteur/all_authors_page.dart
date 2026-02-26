import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/authServices.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/bookService.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/relationService.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/book_model.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/user_model.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/relationModel.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/libraryService.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/library_model.dart';
import 'package:space_learn_flutter/core/utils/token_storage.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/details/author_profile_page.dart';

class AllAuthorsPage extends StatefulWidget {
  const AllAuthorsPage({super.key});

  @override
  State<AllAuthorsPage> createState() => _AllAuthorsPageState();
}

class _AllAuthorsPageState extends State<AllAuthorsPage> {
  final BookService _bookService = BookService();
  final RelationService _relationService = RelationService();

  List<UserModel> _authors = [];
  Set<String> _followingIds = {};
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final token = await TokenStorage.getToken();
      final libraryService = LibraryService();

      final List<Future<dynamic>> futures = [_bookService.getAllBooks()];

      UserModel? currentUser;
      if (token != null) {
        final authService = AuthService();
        currentUser = await authService.getUser(token);
      }

      if (token != null && currentUser != null) {
        futures.add(_relationService.getFollowing(currentUser.id));
        futures.add(libraryService.getUserLibrary(token));
      } else {
        futures.add(Future.value(<RelationModel>[]));
        futures.add(Future.value(<LibraryModel>[]));
      }

      final results = await Future.wait(futures);

      final allBooks = results[0] as List<BookModel>;
      final following = results[1] as List<RelationModel>;
      final library = results[2] as List<LibraryModel>;

      final Map<String, UserModel> authorsMap = {};
      final Map<String, int> authorBookCount = {};
      final Map<String, Set<String>> authorCategories = {};

      // Calculate stats from all books
      for (var book in allBooks) {
        final authorId = book.auteurId;
        if (authorId.isEmpty) continue;

        authorBookCount[authorId] = (authorBookCount[authorId] ?? 0) + 1;
        if (book.categorie?.nom != null) {
          authorCategories
              .putIfAbsent(authorId, () => {})
              .add(book.categorie!.nom);
        }

        if (book.auteur != null &&
            book.auteur!.nomComplet != 'Auteur inconnu') {
          authorsMap[authorId] = book.auteur!;
        } else if (!authorsMap.containsKey(authorId)) {
          authorsMap[authorId] = UserModel(
            id: authorId,
            profilId: authorId,
            email: '',
            nomComplet: book.authorName,
            isProfileComplete: false,
          );
        }
      }

      // Source 1: User's Library (very reliable for names via joins)
      for (var item in library) {
        final authorId = item.livre?.auteurId;
        if (authorId != null && authorId.isNotEmpty) {
          if (item.livre!.auteur != null &&
              item.livre!.auteur!.nomComplet != 'Auteur inconnu') {
            authorsMap[authorId] = item.livre!.auteur!;
          } else if (item.auteurNom != null &&
              item.auteurNom!.isNotEmpty &&
              item.auteurNom != 'Auteur inconnu') {
            authorsMap[authorId] = UserModel(
              id: authorId,
              profilId: authorId,
              email: '',
              nomComplet: item.auteurNom!,
              isProfileComplete: false,
            );
          }
        }
      }

      // Source 2: Following list
      for (var f in following) {
        if (f.nomComplet != null && f.nomComplet!.isNotEmpty) {
          authorsMap[f.suitId] = UserModel(
            id: f.suitId,
            profilId: f.suitId,
            email: '',
            nomComplet: f.nomComplet!,
            profilePhoto: f.profilePhoto,
            isProfileComplete: false,
          );
        }
      }

      if (mounted) {
        setState(() {
          _authors = authorsMap.values.toList();
          _followingIds = following.map((f) => f.suitId).toSet();

          // Store stats in the authors' biography if empty to attract users
          for (var author in _authors) {
            final count = authorBookCount[author.id] ?? 0;
            final cats = authorCategories[author.id] ?? {};

            if (author.biography == null ||
                author.biography!.isEmpty ||
                author.biography == "Auteur SpaceLearn") {
              String insight =
                  "$count livre${count > 1 ? 's' : ''} publié${count > 1 ? 's' : ''}";
              if (cats.isNotEmpty) {
                insight += " • Spécialiste : ${cats.first}";
              }
              // We create a temporary modified user for the UI
              authorsMap[author.id] = UserModel(
                id: author.id,
                profilId: author.profilId,
                email: author.email,
                nomComplet: author.nomComplet,
                profilePhoto: author.profilePhoto,
                biography: insight,
                isProfileComplete: author.isProfileComplete,
              );
            }
          }
          _authors = authorsMap.values.toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Erreur lors du chargement des auteurs";
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleFollow(UserModel author) async {
    final token = await TokenStorage.getToken();
    if (token == null) return;

    final isFollowing = _followingIds.contains(author.id);

    setState(() {
      if (isFollowing) {
        _followingIds.remove(author.id);
      } else {
        _followingIds.add(author.id);
      }
    });

    try {
      if (isFollowing) {
        await _relationService.unfollowUser(author.id, token);
      } else {
        await _relationService.followUser(author.id, token);
      }
    } catch (e) {
      // Revert if error
      if (mounted) {
        setState(() {
          if (isFollowing) {
            _followingIds.add(author.id);
          } else {
            _followingIds.remove(author.id);
          }
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Erreur : ${e.toString()}")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Iconsax.arrow_left_2, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          "Tous les auteurs",
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF06B6D4)),
            )
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_error!, style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadData,
                    child: const Text("Réessayer"),
                  ),
                ],
              ),
            )
          : _authors.isEmpty
          ? const Center(
              child: Text(
                "Aucun auteur trouvé",
                style: TextStyle(color: Colors.white70),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _authors.length,
              itemBuilder: (context, index) {
                final author = _authors[index];
                final isFollowing = _followingIds.contains(author.id);

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AuthorProfilePage(
                                author: author,
                                initialIsFollowing: isFollowing,
                              ),
                            ),
                          );
                        },
                        child: CircleAvatar(
                          radius: 30,
                          backgroundColor: Colors.white10,
                          backgroundImage: author.profilePhoto != null
                              ? NetworkImage(author.profilePhoto!)
                              : null,
                          child: author.profilePhoto == null
                              ? Text(
                                  author.nomComplet
                                      .substring(0, 1)
                                      .toUpperCase(),
                                  style: const TextStyle(
                                    color: Color(0xFF06B6D4),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                  ),
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AuthorProfilePage(
                                  author: author,
                                  initialIsFollowing: isFollowing,
                                ),
                              ),
                            );
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                author.nomComplet,
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                author.biography ?? "Auteur SpaceLearn",
                                style: GoogleFonts.poppins(
                                  color: Colors.grey[400],
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => _toggleFollow(author),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isFollowing
                              ? Colors.white.withOpacity(0.1)
                              : const Color(0xFF06B6D4),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: isFollowing
                                ? BorderSide(
                                    color: Colors.white.withOpacity(0.1),
                                  )
                                : BorderSide.none,
                          ),
                        ),
                        child: Text(isFollowing ? "Suivi" : "Suivre"),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
