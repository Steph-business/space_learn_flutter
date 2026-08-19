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
import 'package:space_learn_flutter/core/space_learn/pages/widgets/details/evenement_detail_page.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/lecteur/communaute/salon_noms.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/communaute/carte_evenement.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/communaute/evenements_page.dart';
import 'package:space_learn_flutter/core/themes/layout/nav_bar_all.dart';

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
        final rawEvts = await _evenementService.getEvenementsByAuthor(
          user.id,
          token,
        );
        evts = rawEvts
            .map(
              (e) => Evenement(
                id: e.id,
                typePublication: e.typePublication,
                categorie: e.categorie,
                titre: e.titre,
                contenu: e.contenu,
                imageUrl: e.imageUrl,
                dateEvenement: e.dateEvenement,
                auteurId: e.auteurId,
                nomAuteur:
                    (e.nomAuteur != null && e.nomAuteur!.trim().isNotEmpty)
                    ? e.nomAuteur
                    : user.nomComplet,
                creeLe: e.creeLe,
              ),
            )
            .toList();
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
      body: Column(
        children: [
          const NavBarAll(role: 'auteur'),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.error),
                        ),
                        SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: _loadData,
                          child: Text("Réessayer"),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadData,
                    color: AppColors.secondaryVariant,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
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
                                    AppColors.accentInk,
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
                                    AppColors.accentInk,
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20.0,
                              ),
                              child: Container(
                                height: 120,
                                width: double.infinity,
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                                  () =>
                                                      _filterActiveOnly = true,
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              _buildFilterChip(
                                                label:
                                                    "Toutes mes œuvres (${_books.length})",
                                                isSelected: !_filterActiveOnly,
                                                onTap: () => setState(
                                                  () =>
                                                      _filterActiveOnly = false,
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
                                            color: AppColors.textPrimary
                                                .withOpacity(0.05),
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
                                                  color:
                                                      AppColors.textSecondary,
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
                                                    () => _filterActiveOnly =
                                                        false,
                                                  ),
                                                  child: Text(
                                                    "Voir toutes mes œuvres (${_books.length})",
                                                    style: GoogleFonts.poppins(
                                                      color:
                                                          AppColors.accentInk,
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w600,
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
                                      physics:
                                          const NeverScrollableScrollPhysics(),
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
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlobalSalonCard() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ForumDiscussionPage()),
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
                color: AppColors.accentInk,
                size: 30,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Le libelle de la carte lit la meme source que l'en-tete
                  // du salon : « Votre Salon Officiel » promettait un espace
                  // prive alors qu'elle mene au forum commun a toute la
                  // plateforme.
                  Text(
                    SalonNoms.globalTitre,
                    style: GoogleFonts.poppins(
                      color: AppColors.onAccent,
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
    // On affiche ce qu'on sait, et rien d'autre.
    //
    // La carte annoncait « N messages » avec N = telechargements x 2, et un
    // verdict « Tres actif » / « Peu actif » tire du meme compteur de
    // telechargements. Aucun des deux ne parlait du salon : un auteur pouvait
    // lire « 120 messages » sur un club ou personne n'avait jamais ecrit. Le
    // nombre de lecteurs, lui, est reel.
    final lecteurs = book.telechargements;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ForumDiscussionPage(book: book),
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
                        // Repli sur l'icone quand l'URL est morte.
                        //
                        // Sans errorBuilder, une couverture supprimee du
                        // stockage laissait un rectangle vide et une exception
                        // dans la console : la carte paraissait cassee alors
                        // qu'il ne manquait qu'une image.
                        child: Image.network(
                          book.imageCouverture!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) => Icon(
                            Iconsax.book,
                            color: AppColors.textHint,
                            size: 24,
                          ),
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
                        Iconsax.book_1,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      SizedBox(width: 4),
                      Text(
                        lecteurs == 0
                            ? "Aucun lecteur pour l'instant"
                            : lecteurs == 1
                            ? "1 lecteur"
                            : "$lecteurs lecteurs",
                        style: GoogleFonts.poppins(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Iconsax.arrow_right_3,
                        size: 14,
                        color: AppColors.textHint,
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
  /// Nombre de publications montrees sur la page communaute.
  ///
  /// Elles y etaient toutes deroulees : un auteur qui publie regulierement
  /// devait faire defiler longtemps avant d'atteindre ses clubs de lecture.
  /// Trois donnent le ton, le reste tient dans sa propre page.
  static const int _apercuEvenements = 3;

  /// Ouvre une publication.
  ///
  /// L'auteur passe par la page, et non par une feuille : c'est la que se
  /// trouvent ses boutons de modification et de suppression. Le lecteur, qui
  /// n'a rien a y faire, la lit en feuille sans quitter sa liste.
  Future<void> _ouvrirPublication(BuildContext context, Evenement evt) async {
    final resultat = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EvenementDetailPage(evenement: evt),
      ),
    );
    if (resultat == true && mounted) _loadData();
  }

  void _ouvrirToutesLesPublications() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EvenementsPage(
          evenements: _evenements,
          titre: "Vos publications",
          onOuvrir: _ouvrirPublication,
        ),
      ),
    ).then((_) {
      if (mounted) _loadData();
    });
  }

  Widget _buildEvenementsSection() {
    final apercu = _evenements.take(_apercuEvenements).toList();
    final reste = _evenements.length - apercu.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          for (var i = 0; i < apercu.length; i++)
            Padding(
              padding: EdgeInsets.only(
                bottom: i == apercu.length - 1 ? 0 : AppDimensions.spaceMd,
              ),
              child: CarteEvenement(
                evenement: apercu[i],
                onTap: () => _ouvrirPublication(context, apercu[i]),
              ),
            ),
          if (reste > 0)
            Padding(
              padding: const EdgeInsets.only(top: AppDimensions.spaceMd),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _ouvrirToutesLesPublications,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accentInk,
                    side: BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusCard,
                      ),
                    ),
                  ),
                  child: Text(
                    reste == 1
                        ? "Voir 1 autre publication"
                        : "Voir vos $reste autres publications",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
        ],
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
