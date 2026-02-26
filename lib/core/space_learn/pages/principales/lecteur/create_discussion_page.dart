import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/bookService.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/discussionService.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/book_model.dart';
import 'package:space_learn_flutter/core/utils/token_storage.dart';

class CreateDiscussionPage extends StatefulWidget {
  final String? initialBookId;
  const CreateDiscussionPage({super.key, this.initialBookId});

  @override
  State<CreateDiscussionPage> createState() => _CreateDiscussionPageState();
}

class _CreateDiscussionPageState extends State<CreateDiscussionPage> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _discussionService = DiscussionService();
  final _bookService = BookService();

  List<BookModel> _books = [];
  BookModel? _selectedBook;
  String _selectedCategory = "Général";
  bool _isLoading = false;
  bool _isAnonymous = false;

  final List<String> _categories = [
    "Général",
    "Théories",
    "Personnages",
    "Animations",
    "Aide",
  ];

  @override
  void initState() {
    super.initState();
    _loadBooks();
  }

  Future<void> _loadBooks() async {
    setState(() => _isLoading = true);
    try {
      final books = await _bookService.getAllBooks();
      setState(() {
        _books = books;
        if (widget.initialBookId != null) {
          _selectedBook = _books.firstWhere(
            (b) => b.id == widget.initialBookId,
            orElse: () => _books.first,
          );
        } else if (_books.isNotEmpty) {
          _selectedBook = _books.first;
        }
      });
    } catch (e) {
      debugPrint("Error loading books: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submit() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Veuillez entrer un titre")));
      return;
    }

    if (_selectedBook == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez sélectionner un livre")),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final token = await TokenStorage.getToken();
      if (token == null) throw Exception("Non authentifié");

      // Combine title and content if needed, or just send title as the main thread description
      final fullTitle = _titleController.text.trim();

      await _discussionService.createDiscussion(
        type: _selectedBook != null ? "LIVRE" : "GLOBAL",
        titre: fullTitle,
        token: token,
        livreId: _selectedBook?.id,
        description: _contentController.text.trim().isNotEmpty
            ? _contentController.text.trim()
            : null,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Discussion créée avec succès !"),
            backgroundColor: Color(0xFF06B6D4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Erreur : $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
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
          "NOUVEAU POST",
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 1.0,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading && _books.isEmpty
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF06B6D4)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Book Selection
                  Text(
                    "SÉLECTIONNER UN LIVRE",
                    style: GoogleFonts.poppins(
                      color: Colors.grey[500],
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<BookModel>(
                        value: _selectedBook,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF1E293B),
                        items: _books.map((book) {
                          return DropdownMenuItem(
                            value: book,
                            child: Text(
                              book.titre,
                              style: const TextStyle(color: Colors.white),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedBook = val),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Title Input
                  Text(
                    "TITRE DU POST",
                    style: GoogleFonts.poppins(
                      color: Colors.grey[500],
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _titleController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "De quoi souhaitez-vous discuter ?",
                      hintStyle: TextStyle(color: Colors.grey[600]),
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Content Input
                  Text(
                    "CONTENU (OPTIONNEL)",
                    style: GoogleFonts.poppins(
                      color: Colors.grey[500],
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _contentController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    maxLines: 6,
                    decoration: InputDecoration(
                      hintText: "Détails de votre pensée...",
                      hintStyle: TextStyle(color: Colors.grey[600]),
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Category selection
                  Text(
                    "CATÉGORIE",
                    style: GoogleFonts.poppins(
                      color: Colors.grey[500],
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _categories.map((cat) {
                      final isSelected = _selectedCategory == cat;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedCategory = cat),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF06B6D4)
                                : const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.transparent
                                  : Colors.white.withOpacity(0.1),
                            ),
                          ),
                          child: Text(
                            cat,
                            style: GoogleFonts.poppins(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.grey[400],
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 32),

                  // Anonymous toggle
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "PUBLIER EN ANONYME",
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            "Votre profil ne sera pas visible",
                            style: GoogleFonts.poppins(
                              color: Colors.grey[500],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Switch(
                        value: _isAnonymous,
                        onChanged: (val) => setState(() => _isAnonymous = val),
                        activeColor: const Color(0xFF06B6D4),
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF06B6D4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              "PUBLIER DANS LE FORUM",
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.0,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
