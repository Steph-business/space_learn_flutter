import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/utils/app_notifications.dart';
import 'package:space_learn_flutter/core/themes/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:space_learn_flutter/core/themes/app_dimensions.dart';
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
import 'package:space_learn_flutter/core/space_learn/data/dataServices/relationService.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/discussionService.dart';
import 'package:intl/intl.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/details/evenement_detail_page.dart';

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
  final RelationService _relationService = RelationService();
  final DiscussionService _discussionService = DiscussionService();

  List<BookModel> _books = [];
  List<Evenement> _evenements = [];

  /// L'auteur et son audience, pour que la page lui parle de lui.
  /// Elle s'ouvrait sur « Vos espaces d'échange » — un intitulé qui aurait
  /// convenu à n'importe qui.
  String _prenom = '';
  int _nombreAbonnes = 0;

  /// Ce qui se passe dans le salon officiel.
  ///
  /// La carte annonçait « Avis, FAQ, et annonces globales » — une description
  /// du lieu, jamais de son activité. Rien ne disait s'il s'y passait quoi que
  /// ce soit, donc rien n'invitait à l'ouvrir.
  int _discussionsSalon = 0;
  bool _isLoading = true;
  bool _filterActiveOnly = true;
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

      // Le nombre d'abonnes ne doit pas empecher la page de s'afficher :
      // c'est un ornement, pas une donnee vitale.
      int abonnes = 0;
      try {
        abonnes = (await _relationService.getFollowers(user.id)).length;
      } catch (_) {}

      int discussionsSalon = 0;
      try {
        discussionsSalon =
            (await _discussionService.getGlobalDiscussions()).length;
      } catch (_) {}

      List<Evenement> evts = [];
      try {
        evts = await _evenementService.getEvenementsByAuthor(user.id, token);
      } catch (e) {}

      if (mounted) {
        setState(() {
          _books = books;
          _evenements = evts;
          _prenom = user.nomComplet.trim().split(' ').first;
          _nombreAbonnes = abonnes;
          _discussionsSalon = discussionsSalon;
          // L'onglet par defaut suit ce qu'il y a a montrer : avec zero
          // discussion active, « Discussions actives » s'ouvrait vide alors
          // que « Toutes mes œuvres » en contenait quatre.
          _filterActiveOnly = books.any((b) => b.nombreMessages > 0);
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

  /// Ce que l'auteur a réellement devant lui, en une phrase.
  ///
  /// Un intitulé générique ne dit rien ; un chiffre situe. Et quand il n'y a
  /// encore personne, mieux vaut le dire franchement et donner la marche à
  /// suivre que d'afficher « 0 abonné ».
  String _phraseAudience() {
    final oeuvres = _books.length;
    if (_nombreAbonnes == 0) {
      return oeuvres == 0
          ? "Publiez une première œuvre : vos lecteurs pourront alors vous suivre et échanger ici."
          : "Personne ne vous suit encore. Partagez vos œuvres pour faire venir vos premiers lecteurs.";
    }
    final abonnes = _nombreAbonnes == 1
        ? "1 lecteur vous suit"
        : "$_nombreAbonnes lecteurs vous suivent";
    final oeuvresTexte = oeuvres <= 1 ? "$oeuvres œuvre" : "$oeuvres œuvres";
    return "$abonnes · $oeuvresTexte publiée${oeuvres > 1 ? 's' : ''}";
  }

  @override
  Widget build(BuildContext context) {
    AppColors.suivreLeTheme(context);
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.scaffoldBackground,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading:
            (widget.onBackPressed != null || Navigator.of(context).canPop())
            ? IconButton(
                icon: Icon(
                  Iconsax.arrow_left_2,
                  color: AppColors.textPrimary,
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
            color: AppColors.textPrimary,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              Iconsax.notification,
              color: AppColors.textPrimary,
              size: 20,
            ),
            onPressed: () {},
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_error!, style: TextStyle(color: Colors.red)),
                  SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _loadData,
                    child: Text("Réessayer"),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // En-tête : ce que l'auteur a devant lui, pas un intitulé
                  // qui conviendrait à n'importe qui.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                    child: Text(
                      _prenom.isEmpty
                          ? "Votre communauté"
                          : "La communauté de $_prenom",
                      style: GoogleFonts.poppins(
                        color: AppColors.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: Text(
                      _phraseAudience(),
                      style: GoogleFonts.poppins(
                        color: AppColors.textSecondary,
                        fontSize: 13.5,
                        height: 1.45,
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
                            AppColors.secondaryVariant,
                            onTap: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const NouvelleAnnoncePage(),
                                ),
                              );
                              if (result == true) _loadData();
                            },
                          ),
                        ),
                        SizedBox(width: 15),
                        Expanded(
                          child: _buildQuickAction(
                            Iconsax.calendar,
                            "Événement",
                            // Le vert etait AppColors.success : l'employer en
                            // decor pour un bouton lui retire son sens de
                            // confirmation partout ailleurs. Deux actions de
                            // meme rang portent le meme accent ; leurs icones
                            // suffisent a les distinguer.
                            AppColors.secondaryVariant,
                            onTap: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const CreerEvenementPage(),
                                ),
                              );
                              if (result == true) _loadData();
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Section Événements & Annonces
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 20.0,
                      top: 30.0,
                      bottom: 15.0,
                    ),
                    child: Text(
                      "Vos publications (${_evenements.length})",
                      style: GoogleFonts.poppins(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (_evenements.isNotEmpty)
                    _buildEvenementsSection()
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Container(
                        height: 120,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColors.cardBackground,
                          borderRadius: BorderRadius.circular(
                            AppDimensions.radiusCard,
                          ),
                          border: Border.all(
                            color: AppColors.textPrimary.withOpacity(0.05),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Iconsax.notification_status,
                              color: AppColors.textHint,
                              size: 32,
                            ),
                            SizedBox(height: 10),
                            Text(
                              "Aucune annonce ou événement pour le moment.",
                              style: GoogleFonts.poppins(
                                color: AppColors.textHint,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Forums par Livre
                  Builder(
                    builder: (context) {
                      final activeBooks = _books
                          .where((b) => b.nombreMessages > 0)
                          .toList();
                      final displayBooks = _filterActiveOnly
                          ? activeBooks
                          : _books;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20.0,
                              vertical: 10.0,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Forums de vos œuvres (${displayBooks.length})",
                                  style: AppTextStyles.subtitle,
                                ),
                                const SizedBox(height: 12),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      _buildFilterChip(
                                        label:
                                            "Discussions actives (${activeBooks.length})",
                                        isSelected: _filterActiveOnly,
                                        onTap: () => setState(
                                          () => _filterActiveOnly = true,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      _buildFilterChip(
                                        label:
                                            "Toutes mes œuvres (${_books.length})",
                                        isSelected: !_filterActiveOnly,
                                        onTap: () => setState(
                                          () => _filterActiveOnly = false,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          if (displayBooks.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20.0,
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: AppColors.cardBackground,
                                  borderRadius: BorderRadius.circular(
                                    AppDimensions.radiusCard,
                                  ),
                                  border: Border.all(
                                    color: AppColors.textPrimary.withOpacity(
                                      0.05,
                                    ),
                                  ),
                                ),
                                child: Center(
                                  child: Column(
                                    children: [
                                      Icon(
                                        Iconsax.messages_1,
                                        size: 36,
                                        color: AppColors.textHint,
                                      ),
                                      const SizedBox(height: 12),
                                      // Un vide doit dire quoi faire. Le
                                      // premier message annoncait « aucune
                                      // discussion active » a un auteur qui
                                      // avait quatre œuvres, sans lui indiquer
                                      // que l'autre onglet les montrait.
                                      Text(
                                        _filterActiveOnly
                                            ? (_books.isEmpty
                                                  ? "Publiez une œuvre : chacune ouvre son propre forum."
                                                  : "Aucun lecteur n'a encore écrit sur vos œuvres.\n"
                                                        "Elles sont dans « Toutes mes œuvres ».")
                                            : "Publiez un livre pour créer un forum qui lui est dédié.",
                                        style: GoogleFonts.poppins(
                                          color: AppColors.textSecondary,
                                          fontSize: 13,
                                          height: 1.45,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      if (_filterActiveOnly &&
                                          _books.isNotEmpty) ...[
                                        const SizedBox(height: 12),
                                        GestureDetector(
                                          onTap: () => setState(
                                            () => _filterActiveOnly = false,
                                          ),
                                          child: Text(
                                            "Voir toutes mes œuvres (${_books.length})",
                                            style: GoogleFonts.poppins(
                                              color: AppColors.accentInk,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            )
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              itemCount: displayBooks.length,
                              itemBuilder: (context, index) {
                                final book = displayBooks[index];
                                return _buildBookForumCard(book);
                              },
                            ),
                        ],
                      );
                    },
                  ),

                  SizedBox(height: 100),
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
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.cardBackground, AppColors.scaffoldBackground],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          border: Border.all(
            color: AppColors.secondaryVariant.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.secondaryVariant.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Iconsax.messages_2,
                color: AppColors.secondaryVariant,
                size: 30,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Votre Salon Officiel",
                    style: GoogleFonts.poppins(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    _discussionsSalon == 0
                        ? "Aucune discussion pour l'instant — ouvrez-en une"
                        : _discussionsSalon == 1
                        ? "1 discussion en cours"
                        : "$_discussionsSalon discussions en cours",
                    style: GoogleFonts.poppins(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Iconsax.arrow_right_3, color: AppColors.textHint, size: 20),
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
        margin: EdgeInsets.only(bottom: 16),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          border: Border.all(color: AppColors.textPrimary.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            Hero(
              tag: 'forum_cover_${book.id}',
              child: Container(
                width: 50,
                height: 70,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(
                    AppDimensions.radiusSmall,
                  ),
                  color: AppColors.textPrimary.withOpacity(0.05),
                ),
                child:
                    book.imageCouverture != null &&
                        !book.imageCouverture!.contains('example.com')
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusSmall,
                        ),
                        child: Image.network(
                          book.imageCouverture!,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Icon(Iconsax.book, color: AppColors.textHint, size: 24),
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.titre,
                    style: GoogleFonts.poppins(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Iconsax.message,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      SizedBox(width: 4),
                      Text(
                        "$msgCount messages",
                        style: GoogleFonts.poppins(
                          color: AppColors.textSecondary,
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
                          borderRadius: BorderRadius.circular(
                            AppDimensions.radiusSmall,
                          ),
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
            AppNotifications.showSnackBar(
              context,
              message: "$label en cours de développement.",
            );
          },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppDimensions.radiusInner),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            SizedBox(width: 8),
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

  /// Liste des annonces et événements de l'auteur.
  ///
  /// C'était une liste horizontale de cartes larges de 280 px, hautes de 200.
  /// Avec une seule publication — le cas de tout auteur qui débute — on voyait
  /// une carte s'arrêter aux trois quarts de l'écran et un grand vide à droite,
  /// sans rien indiquant qu'il fallait faire défiler. Une annonce n'est pas non
  /// plus un carrousel : on la lit, on ne la parcourt pas du regard.
  ///
  /// Verticale et pleine largeur : le texte respire, et la hauteur suit le
  /// contenu au lieu d'être figée.
  Widget _buildEvenementsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          for (final evt in _evenements) ...[
            _cartePublication(evt),
            if (evt != _evenements.last)
              const SizedBox(height: AppDimensions.spaceMd),
          ],
        ],
      ),
    );
  }

  Widget _cartePublication(Evenement evt) {
    final isAnnonce = evt.typePublication.toLowerCase() == "annonce";
    // L'annonce et l'événement se distinguent par leur icône et leur libellé.
    // Le vert d'AppColors.success servait ici de décor, ce qui lui retirait son
    // sens de confirmation partout ailleurs dans l'application.
    final iconType = isAnnonce ? Iconsax.notification : Iconsax.calendar;

    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EvenementDetailPage(evenement: evt),
          ),
        );
        if (result == true) _loadData();
      },
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          border: Border.all(color: AppColors.border),
        ),
        padding: const EdgeInsets.all(AppDimensions.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusSmall,
                    ),
                  ),
                  child: Icon(iconType, color: AppColors.accentInk, size: 16),
                ),
                const SizedBox(width: AppDimensions.spaceMd),
                Expanded(
                  child: Text(
                    evt.typePublication.toUpperCase(),
                    style: GoogleFonts.poppins(
                      color: AppColors.accentInk,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                if (evt.dateEvenement != null)
                  Text(
                    DateFormat(
                      'd MMM yyyy',
                      'fr_FR',
                    ).format(evt.dateEvenement!),
                    style: GoogleFonts.poppins(
                      color: AppColors.textHint,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppDimensions.spaceMd),
            Text(
              evt.titre,
              style: GoogleFonts.poppins(
                color: AppColors.textPrimary,
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (evt.contenu.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                evt.contenu,
                style: GoogleFonts.poppins(
                  color: AppColors.textSecondary,
                  fontSize: 12.5,
                  height: 1.45,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.15)
              : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          border: Border.all(
            color: isSelected
                ? AppColors.accentInk
                : AppColors.textPrimary.withOpacity(0.08),
            width: 1.2,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            color: isSelected ? AppColors.accentInk : AppColors.textSecondary,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
