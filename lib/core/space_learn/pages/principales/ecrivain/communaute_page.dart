import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/bookService.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/authServices.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/book_model.dart';
import 'package:space_learn_flutter/core/utils/token_storage.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/lecteur/communaute/forum_discussion_page.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/auteur/communaute/nouvelle_annonce_page.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/auteur/communaute/creer_evenement_page.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/evenementModel.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/evenementService.dart';
import 'package:intl/intl.dart';

class TeamsPage extends StatefulWidget {
  final VoidCallback? onBackPressed;

  const TeamsPage({super.key, this.onBackPressed});

  @override
  State<TeamsPage> createState() => _TeamsPageState();
}

class _TeamsPageState extends State<TeamsPage> {
  final BookService _bookService = BookService();
  final AuthService _authService = AuthService();
  final EvenementService _evenementService = EvenementService();

  List<BookModel> _books = [];
  List<Evenement> _evenements = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
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

      List<Evenement> evts = [];
      try {
        evts = await _evenementService.getEvenementsByAuthor(user.id, token);
      } catch (e) {
        debugPrint("Erreur evenements: $e");
      }

      if (mounted) {
        setState(() {
          _books = books;
          _evenements = evts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Erreur lors du chargement des données.";
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
        title: Text(
          "COMMUNAUTÉ",
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(
              Iconsax.notification,
              color: Colors.white,
              size: 20,
            ),
            onPressed: () {},
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _loadData,
                    child: const Text("Réessayer"),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // En-tête Global
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Text(
                      "Vos espaces d'échange",
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),

                  // Salon de l'Auteur
                  _buildGlobalSalonCard(),

                  // Outils rapides
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20.0,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildQuickAction(
                            Iconsax.edit,
                            "Nouvelle annonce",
                            const Color(0xFF0EA5E9),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const NouvelleAnnoncePage(),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: _buildQuickAction(
                            Iconsax.calendar,
                            "Événement",
                            const Color(0xFF10B981),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const CreerEvenementPage(),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Section Événements & Annonces
                  if (_evenements.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 20.0,
                        top: 30.0,
                        bottom: 10.0,
                      ),
                      child: Text(
                        "Vos publications",
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    _buildEvenementsSection(),
                  ],

                  // Forums par Livre
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Text(
                      "Forums de vos œuvres (${_books.length})",
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  if (_books.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Center(
                          child: Text(
                            "Publiez un livre pour créer un forum qui lui est dédié.",
                            style: TextStyle(color: Colors.white54),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _books.length,
                      itemBuilder: (context, index) {
                        final book = _books[index];
                        return _buildBookForumCard(book);
                      },
                    ),

                  const SizedBox(height: 100),
                ],
              ),
            ),
    );
  }

  Widget _buildGlobalSalonCard() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ForumDiscussionPage(
              title: "SALON DE L'AUTEUR",
              subtitle: "Discussions générales avec votre communauté",
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF0EA5E9).withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0EA5E9).withOpacity(0.1),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0EA5E9).withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Iconsax.messages_2,
                color: Color(0xFF0EA5E9),
                size: 30,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Votre Salon Officiel",
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Avis, FAQ, et annonces globales",
                    style: GoogleFonts.poppins(
                      color: Colors.grey[400],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Iconsax.arrow_right_3, color: Colors.white54, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildBookForumCard(BookModel book) {
    // Fake stats variables for demonstration
    final activityScore = book.telechargements > 50
        ? "Très actif"
        : "Peu actif";
    final msgCount = book.telechargements * 2;
    final color = book.telechargements > 50
        ? Colors.greenAccent
        : Colors.orangeAccent;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ForumDiscussionPage(
              title: "CLUB DE LECTURE",
              subtitle: book.titre,
              book: book,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            Hero(
              tag: 'forum_cover_${book.id}',
              child: Container(
                width: 50,
                height: 70,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white.withOpacity(0.05),
                ),
                child:
                    book.imageCouverture != null &&
                        !book.imageCouverture!.contains('example.com')
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          book.imageCouverture!,
                          fit: BoxFit.cover,
                        ),
                      )
                    : const Icon(Iconsax.book, color: Colors.white24, size: 24),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.titre,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Iconsax.message, size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(
                        "$msgCount messages",
                        style: GoogleFonts.poppins(
                          color: Colors.grey[400],
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          activityScore,
                          style: GoogleFonts.poppins(
                            color: color,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAction(
    IconData icon,
    String label,
    Color color, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap:
          onTap ??
          () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("$label en cours de développement.")),
            );
          },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEvenementsSection() {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _evenements.length,
        itemBuilder: (context, index) {
          final evt = _evenements[index];
          final isAnnonce = evt.typePublication.toLowerCase() == "annonce";
          final colorType = isAnnonce
              ? const Color(0xFF0EA5E9)
              : const Color(0xFF10B981);
          final iconType = isAnnonce ? Iconsax.notification : Iconsax.calendar;

          return Container(
            width: 280,
            margin: const EdgeInsets.only(right: 16, bottom: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colorType.withOpacity(0.3)),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorType.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(iconType, color: colorType, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        evt.typePublication.toUpperCase(),
                        style: GoogleFonts.poppins(
                          color: colorType,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (evt.dateEvenement != null)
                      Text(
                        DateFormat('dd/MM/yyyy').format(evt.dateEvenement!),
                        style: GoogleFonts.poppins(
                          color: Colors.white54,
                          fontSize: 10,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  evt.titre,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: Text(
                    evt.contenu,
                    style: GoogleFonts.poppins(
                      color: Colors.grey[400],
                      fontSize: 12,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
