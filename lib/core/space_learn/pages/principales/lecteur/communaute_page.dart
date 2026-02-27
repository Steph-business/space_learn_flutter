import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/libraryService.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/library_model.dart';
import 'package:space_learn_flutter/core/utils/token_storage.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/lecteur/communaute/forum_discussion_page.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/evenementModel.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/evenementService.dart';
import 'package:intl/intl.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/discussionService.dart';
import 'recherche_page.dart';

class TeamsPageLecteur extends StatefulWidget {
  final VoidCallback? onBackPressed;
  const TeamsPageLecteur({super.key, this.onBackPressed});

  @override
  State<TeamsPageLecteur> createState() => _TeamsPageLecteurState();
}

class _TeamsPageLecteurState extends State<TeamsPageLecteur> {
  final LibraryService _libraryService = LibraryService();
  final EvenementService _evenementService = EvenementService();
  final DiscussionService _discussionService = DiscussionService();

  List<LibraryModel> _library = [];
  List<Evenement> _evenements = [];
  int _cafeMsgCount = 0;
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

      final libraryItems = await _libraryService.getUserLibrary(token);

      List<Evenement> evts = [];
      try {
        evts = await _evenementService.getGlobalEvenements(token);
      } catch (e) {
        debugPrint("Erreur evenements: $e");
      }

      int totalCafeMsgs = 0;
      try {
        final globalDiscussions = await _discussionService
            .getGlobalDiscussions();
        for (var d in globalDiscussions) {
          final count = (d.messagesCount ?? 0) > 0
              ? d.messagesCount!
              : d.messages.length;
          totalCafeMsgs += count;
        }
      } catch (e) {
        debugPrint("Erreur global discussions: $e");
      }

      // Filtrer les entrées sans livre valide
      final validItems = libraryItems
          .where((item) => item.livre != null)
          .toList();

      if (mounted) {
        setState(() {
          _library = validItems;
          _evenements = evts;
          _cafeMsgCount = totalCafeMsgs;
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
      backgroundColor: const Color(0xFF111827),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
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
              Iconsax.search_normal_1,
              color: Colors.white,
              size: 20,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const RecherchePage()),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Text(
                "Chargement...",
                style: TextStyle(color: Colors.white70),
              ),
            )
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _loadData,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF22D3EE),
                    ),
                    child: const Text(
                      "Réessayer",
                      style: TextStyle(color: Colors.white),
                    ),
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

                  // Salon Principal (Espace global)
                  _buildGlobalSalonCard(),

                  // Section Événements & Annonces
                  if (_evenements.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 20.0,
                        top: 30.0,
                        bottom: 10.0,
                      ),
                      child: Text(
                        "Annonces & Événements",
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
                      "Clubs de lecture de votre bibliothèque (${_library.length})",
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  if (_library.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1F2937),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Center(
                          child: Text(
                            "Ajoutez des livres à votre bibliothèque pour rejoindre leurs forums de discussion.",
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
                      itemCount: _library.length,
                      itemBuilder: (context, index) {
                        final libraryItem = _library[index];
                        return _buildBookForumCard(libraryItem);
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
              title: "LE CAFE DES LECTEURS",
              subtitle: "Espace global d'échange Space Learn",
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1F2937), Color(0xFF111827)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF22D3EE).withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF22D3EE).withOpacity(0.1),
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
                color: const Color(0xFF22D3EE).withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Iconsax.coffee,
                color: Color(0xFF22D3EE),
                size: 30,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Le Café des Lecteurs",
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Recommandations, coup de cœurs et discussions générales",
                    style: GoogleFonts.poppins(
                      color: Colors.grey[400],
                      fontSize: 12,
                    ),
                  ),
                  if (_cafeMsgCount > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Iconsax.message,
                          size: 10,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "$_cafeMsgCount messages",
                          style: GoogleFonts.poppins(
                            color: Colors.grey[500],
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Iconsax.arrow_right_3, color: Colors.white54, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildBookForumCard(LibraryModel libraryItem) {
    final book = libraryItem.livre!;
    final activityScore = book.nombreMessages > 20
        ? "Très actif"
        : book.nombreMessages > 0
        ? "Actif"
        : "Nouveau";
    final msgCount = book.nombreMessages;
    final color = book.nombreMessages > 20
        ? Colors.greenAccent
        : book.nombreMessages > 0
        ? Colors.cyanAccent
        : Colors.grey;

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
          color: const Color(0xFF1F2937),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            Hero(
              tag: 'lecteur_forum_cover_${book.id}',
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
              color: const Color(0xFF1F2937),
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
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.person, size: 12, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      "Événement Communauté",
                      style: GoogleFonts.poppins(
                        color: Colors.grey,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
