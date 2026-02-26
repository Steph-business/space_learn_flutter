import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/book_model.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/discussionModel.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/discussionService.dart';
import 'package:space_learn_flutter/core/utils/token_storage.dart';
import 'forum_messages_page.dart';

class ForumDiscussionPage extends StatefulWidget {
  final String title;
  final String subtitle;
  final BookModel? book;

  const ForumDiscussionPage({
    super.key,
    required this.title,
    required this.subtitle,
    this.book,
  });

  @override
  State<ForumDiscussionPage> createState() => _ForumDiscussionPageState();
}

class _ForumDiscussionPageState extends State<ForumDiscussionPage> {
  final DiscussionService _discussionService = DiscussionService();
  List<Discussion> _discussions = [];
  bool _isLoading = true;

  String _selectedCategory = "Tout";

  final List<String> _categories = [
    "Tout",
    "Théories",
    "Personnages",
    "Animations",
  ];

  String _timeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inDays >= 7) {
      final weeks = diff.inDays ~/ 7;
      return "il y a $weeks semaine${weeks > 1 ? 's' : ''}";
    } else if (diff.inDays >= 1) {
      return "il y a ${diff.inDays} jour${diff.inDays > 1 ? 's' : ''}";
    } else if (diff.inHours >= 1) {
      return "il y a ${diff.inHours} heure${diff.inHours > 1 ? 's' : ''}";
    } else if (diff.inMinutes >= 1) {
      return "il y a ${diff.inMinutes} min";
    } else {
      return "à l'instant";
    }
  }

  @override
  void initState() {
    super.initState();
    _loadDiscussions();
  }

  Future<void> _loadDiscussions() async {
    try {
      final token = await TokenStorage.getToken();
      if (token == null) return;

      List<Discussion> dbDiscussions;
      if (widget.book != null) {
        dbDiscussions = await _discussionService.getDiscussionsByLivre(
          widget.book!.id,
          token,
        );
      } else {
        dbDiscussions = await _discussionService.getDiscussionsByUser(token);
      }

      if (mounted) {
        setState(() {
          _discussions = dbDiscussions;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _createNewDiscussion(String title) async {
    try {
      final token = await TokenStorage.getToken();
      if (token == null) return;

      final newDisc = await _discussionService.createDiscussion(
        type: widget.book != null ? "LIVRE" : "GLOBAL",
        titre: title,
        token: token,
        livreId: widget.book?.id,
      );

      if (mounted) {
        setState(() {
          _discussions.insert(0, newDisc);
        });
        Navigator.pop(context); // close dialog
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur : $e')));
    }
  }

  void _showNewDiscussionDialog() {
    final TextEditingController _titleController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: Text(
            "Nouveau sujet",
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          content: TextField(
            controller: _titleController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: "Titre de la discussion",
              hintStyle: TextStyle(color: Colors.white54),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "Annuler",
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                if (_titleController.text.isNotEmpty) {
                  _createNewDiscussion(_titleController.text);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0EA5E9),
              ),
              child: const Text("Créer"),
            ),
          ],
        );
      },
    );
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
        title: Column(
          children: [
            Text(
              widget.title.toUpperCase(),
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            ),
            Text(
              widget.subtitle,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF0EA5E9),
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(
              Iconsax.search_normal_1,
              color: Colors.white,
              size: 20,
            ),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Promotional Header Card
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child:
                          widget.book?.imageCouverture != null &&
                              !widget.book!.imageCouverture!.contains(
                                'example.com',
                              )
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                widget.book!.imageCouverture!,
                                fit: BoxFit.cover,
                              ),
                            )
                          : const Center(
                              child: Icon(
                                Iconsax.book,
                                color: Colors.white24,
                                size: 30,
                              ),
                            ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Rejoignez la discussion",
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Partagez vos théories avec la communauté.",
                            style: GoogleFonts.poppins(
                              color: Colors.grey[400],
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              "COMMUNAUTÉ ACTIVE",
                              style: GoogleFonts.poppins(
                                color: const Color(0xFF0EA5E9),
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Categories
            SizedBox(
              height: 45,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  final bool isSelected = _selectedCategory == cat;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategory = cat),
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF0EA5E9)
                            : const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: const Color(
                                    0xFF0EA5E9,
                                  ).withOpacity(0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        cat,
                        style: GoogleFonts.poppins(
                          color: isSelected ? Colors.white : Colors.grey[400],
                          fontSize: 14,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 30),

            // Posts List
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(color: Color(0xFF0EA5E9)),
              )
            else if (_discussions.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 40,
                ),
                child: Text(
                  "Aucun sujet de discussion. Lancez le premier sujet !",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(color: Colors.grey[400]),
                ),
              )
            else
              Builder(
                builder: (context) {
                  final filtered = _selectedCategory == "Tout"
                      ? _discussions
                      : _discussions
                            .where(
                              (d) => d.titre.toLowerCase().contains(
                                _selectedCategory.toLowerCase(),
                              ),
                            )
                            .toList();

                  if (filtered.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 40,
                      ),
                      child: Text(
                        "Aucun sujet ne correspond à cette catégorie.",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(color: Colors.grey[400]),
                      ),
                    );
                  }

                  return Column(
                    children: filtered.map((d) {
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  ForumMessagesPage(discussion: d),
                            ),
                          ).then((_) {
                            // Refresh just in case messages were added
                            _loadDiscussions();
                          });
                        },
                        child: _buildPostItem(
                          username: (d.creePar?.isNotEmpty ?? false)
                              ? d.creePar!.substring(0, 6)
                              : "Anonyme",
                          time: d.creeLe != null
                              ? _timeAgo(d.creeLe!)
                              : "inconnu",
                          title: d.titre,
                          content: "Rejoindre la conversation...",
                          comments: d.messagesCount ?? d.messages.length,
                          likes: 0,
                        ),
                      );
                    }).toList(),
                  );
                },
              ),

            const SizedBox(height: 100), // Space for FAB
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'forum_discussion_fab_\${widget.book?.id ?? "global"}',
        onPressed: _showNewDiscussionDialog,
        backgroundColor: const Color(0xFF0EA5E9),
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Iconsax.add, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildPostItem({
    required String username,
    required String time,
    required String title,
    required String content,
    required int comments,
    required int likes,
    bool isAnonymous = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isAnonymous ? Colors.cyan : Colors.grey[800],
                ),
                child: isAnonymous
                    ? const Center(
                        child: Text(
                          "A",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.network(
                          "https://i.pravatar.cc/150?u=$username",
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) =>
                              const Icon(Icons.person, color: Colors.white),
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          "@$username",
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF0EA5E9),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          time,
                          style: GoogleFonts.poppins(
                            color: Colors.grey[500],
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 52, top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  content,
                  style: GoogleFonts.poppins(
                    color: Colors.grey[400],
                    fontSize: 13,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Iconsax.message, size: 18, color: Colors.grey[500]),
                    const SizedBox(width: 6),
                    Text(
                      comments.toString(),
                      style: GoogleFonts.poppins(
                        color: Colors.grey[500],
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Icon(Iconsax.heart, size: 18, color: Colors.grey[500]),
                    const SizedBox(width: 6),
                    Text(
                      likes.toString(),
                      style: GoogleFonts.poppins(
                        color: Colors.grey[500],
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.white.withOpacity(0.05)),
        ],
      ),
    );
  }
}
