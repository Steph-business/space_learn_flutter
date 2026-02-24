import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';

class TeamsPage extends StatefulWidget {
  final VoidCallback? onBackPressed;

  const TeamsPage({super.key, this.onBackPressed});

  @override
  State<TeamsPage> createState() => _TeamsPageState();
}

class _TeamsPageState extends State<TeamsPage> {
  String _selectedCategory = "Tout";

  final List<String> _categories = [
    "Tout",
    "Théories",
    "Personnages",
    "Animations",
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        automaticallyImplyLeading: false,
        leading:
            (widget.onBackPressed != null || Navigator.of(context).canPop())
            ? IconButton(
                icon: const Icon(
                  Iconsax.arrow_left_2,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed:
                    widget.onBackPressed ?? () => Navigator.of(context).pop(),
              )
            : null,
        title: Column(
          children: [
            Text(
              "FORUM",
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            ),
            Text(
              "Les Chroniques d'Éléa - Tome II",
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
                      child: const Center(
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
                            "Partagez vos théories avec 2.4k autres lecteurs.",
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
            _buildPostItem(
              username: "JeanDupont",
              time: "2h",
              title: "Théories sur la fin du Tome 2 : Est-...",
              content:
                  "J'ai remarqué un detail dans le chapitre 24 qui pourrait tout changer pour la suite de...",
              comments: 42,
              likes: 128,
            ),
            _buildPostItem(
              username: "MarieL",
              time: "5h",
              title: "Votre personnage préféré du Tom...",
              content:
                  "Je vote pour Elara, son évolution est juste incroyable ! Et vous ?",
              comments: 128,
              likes: 350,
            ),
            _buildPostItem(
              username: "AnonymeReader",
              time: "8h",
              title: "Petit bug dans le chapitre 12 sur la...",
              content:
                  "Le texte se superpose au niveau de la page 45, est-ce que quelqu'un d'autre a ce sou...",
              comments: 3,
              likes: 1,
              isAnonymous: true,
            ),

            const SizedBox(height: 100), // Space for FAB
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
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
                          "il y a $time",
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
