import 'package:flutter/material.dart';

import 'package:space_learn_flutter/core/space_learn/pages/widgets/auteur/livres/livre_stats.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/auteur/livres/publications_liste.dart';

import 'package:space_learn_flutter/core/space_learn/pages/principales/ecrivain/ajouter_livre_page.dart';

import 'package:space_learn_flutter/core/space_learn/data/dataServices/bookService.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/authServices.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/authorStatsService.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/book_model.dart';
import 'package:space_learn_flutter/core/utils/token_storage.dart';

class LivresPage extends StatefulWidget {
  final VoidCallback? onBackPressed;

  const LivresPage({super.key, this.onBackPressed});

  @override
  State<LivresPage> createState() => _LivresPageState();
}

class _LivresPageState extends State<LivresPage> {
  final BookService _bookService = BookService();
  final AuthService _authService = AuthService();
  final AuthorStatsService _statsService = AuthorStatsService();

  List<BookModel> _books = [];
  Map<String, dynamic> _stats = {};
  String? _authorName;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBooks();
  }

  Future<void> _loadBooks() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final token = await TokenStorage.getToken();
      if (token == null) {
        setState(() {
          _error = "Session expirée. Veuillez vous reconnecter.";
          _isLoading = false;
        });
        return;
      }

      final user = await _authService.getUser(token);
      if (user == null) {
        setState(() {
          _error = "Utilisateur non trouvé.";
          _isLoading = false;
        });
        return;
      }

      final books = await _bookService.getBooksByAuthorId(user.id);
      final stats = await _statsService.getAuthorStats(user.id, 'all');

      if (mounted) {
        setState(() {
          _books = books;
          _stats = stats;
          _authorName = user.nomComplet;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading books: $e');
      if (mounted) {
        setState(() {
          _error = "Erreur lors du chargement des livres.";
          _isLoading = false;
        });
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
        title: const Text(
          'Mes livres',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (widget.onBackPressed != null) {
              widget.onBackPressed!();
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              LivreStatsSection(
                publications: _books.length,
                views: _stats['views'] ?? 0,
                revenue: _stats['revenue'] ?? 0,
              ),
              const SizedBox(height: 20),
              // Search Bar
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Rechercher un livre...",
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Color(0xFF0EA5E9),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 15,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else if (_error != null)
                Center(
                  child: Column(
                    children: [
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      ElevatedButton(
                        onPressed: _loadBooks,
                        child: const Text("Réessayer"),
                      ),
                    ],
                  ),
                )
              else if (_books.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Text(
                      "Vous n'avez pas encore publié de livres.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ),
                )
              else
                PublicationsList(books: _books, authorName: _authorName),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AjouterLivrePage()),
          );
          if (result == true) {
            _loadBooks();
          }
        },
        backgroundColor: const Color(0xFF0EA5E9),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          "Nouveau",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
