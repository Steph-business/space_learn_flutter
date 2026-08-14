import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/themes/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:space_learn_flutter/core/themes/app_dimensions.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/libraryService.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/library_model.dart';
import 'package:space_learn_flutter/core/utils/token_storage.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/lecteur/communaute/forum_discussion_page.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/evenementModel.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/evenementService.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/discussionService.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/authServices.dart';
import 'recherche_page.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/lecteur/communaute/salon_noms.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/communaute/carte_evenement.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/communaute/evenement_apercu.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/communaute/evenements_page.dart';

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

  /// Le prénom du lecteur, pour que la page s'adresse à lui.
  /// Elle s'ouvrait sur « Vos espaces d'échange » — un intitulé qui aurait
  /// convenu à n'importe qui, sur n'importe quelle application.
  String _prenom = '';
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

      // Le prénom n'est qu'un ornement : son absence ne doit pas priver le
      // lecteur de sa page.
      String prenom = '';
      try {
        final user = await AuthService().getUser(token);
        if (user != null) prenom = user.nomComplet.trim().split(' ').first;
      } catch (_) {}

      List<Evenement> evts = [];
      try {
        evts = await _evenementService.getGlobalEvenements(token);
      } catch (e) {}

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
      } catch (e) {}

      // Filtrer les entrées sans livre valide
      final validItems = libraryItems
          .where((item) => item.livre != null)
          .toList();

      if (mounted) {
        setState(() {
          _library = validItems;
          _evenements = evts;
          _prenom = prenom;
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

  /// Une ligne qui dit au lecteur ou il en est.
  ///
  /// Un ecran vide sans explication se lit comme une panne. Quand la
  /// bibliotheque est vide, la phrase indique quoi faire ; sinon elle compte
  /// ce qui est deja la.
  String _phraseBibliotheque() {
    final livres = _library.length;
    if (livres == 0) {
      return "Votre bibliothèque est vide : chaque livre acheté ouvre son "
          "club de lecture, où vous retrouvez les autres lecteurs.";
    }
    final texteLivres = livres == 1
        ? "1 club de lecture"
        : "$livres clubs de lecture";
    if (_evenements.isEmpty) {
      return "$texteLivres · le café des lecteurs vous attend";
    }
    final texteActu = _evenements.length == 1
        ? "1 actualité de vos auteurs"
        : "${_evenements.length} actualités de vos auteurs";
    return "$texteLivres · $texteActu";
  }

  @override
  Widget build(BuildContext context) {
    AppColors.suivreLeTheme(context);
    return Scaffold(
      backgroundColor: AppColors.darkSurface,
      appBar: AppBar(
        backgroundColor: AppColors.darkSurface,
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
              Iconsax.search_normal_1,
              color: AppColors.textPrimary,
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
          ? Center(
              child: Text(
                "Chargement...",
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
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
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryLight,
                    ),
                    child: Text(
                      "Réessayer",
                      style: TextStyle(color: AppColors.onAccent),
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // En-tete : ce que le lecteur a devant lui, pas un intitule
                  // qui conviendrait a n'importe qui.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                    child: Text(
                      _prenom.isEmpty
                          ? "Vos espaces d'échange"
                          : "Vos lectures, $_prenom",
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
                      _phraseBibliotheque(),
                      style: GoogleFonts.poppins(
                        color: AppColors.textSecondary,
                        fontSize: 13.5,
                        height: 1.45,
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
                          color: AppColors.textPrimary,
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
                      style: AppTextStyles.subtitle,
                    ),
                  ),

                  if (_library.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Container(
                        padding: EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(
                            AppDimensions.radiusCard,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            "Ajoutez des livres à votre bibliothèque pour rejoindre leurs forums de discussion.",
                            style: TextStyle(color: AppColors.textHint),
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
          MaterialPageRoute(builder: (context) => const ForumDiscussionPage()),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.surfaceVariant, AppColors.darkSurface],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          border: Border.all(
            color: AppColors.accentInk.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(Iconsax.coffee, color: AppColors.accentInk, size: 30),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    SalonNoms.globalTitre,
                    style: GoogleFonts.poppins(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "Recommandations, coup de cœurs et discussions générales",
                    style: AppTextStyles.grey12,
                  ),
                  if (_cafeMsgCount > 0) ...[
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Iconsax.message,
                          size: 10,
                          color: AppColors.textSecondary,
                        ),
                        SizedBox(width: 4),
                        Text(
                          "$_cafeMsgCount messages",
                          style: GoogleFonts.poppins(
                            color: AppColors.textSecondary,
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
            Icon(Iconsax.arrow_right_3, color: AppColors.textHint, size: 20),
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
    // greenAccent et grey n'appartiennent a aucune palette de l'application :
    // le premier jurait avec l'orange de la marque, le second ne suivait pas
    // le theme et restait clair en mode sombre.
    final color = book.nombreMessages > 20
        ? AppColors.success
        : book.nombreMessages > 0
        ? AppColors.accentInk
        : AppColors.textHint;

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
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          border: Border.all(color: AppColors.textPrimary.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            Hero(
              tag: 'lecteur_forum_cover_${book.id}',
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
                    style: AppTextStyles.button15,
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
                      Text("$msgCount messages", style: AppTextStyles.grey12),
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

  /// Annonces et evenements des auteurs suivis.
  ///
  /// C'etait une liste horizontale de cartes de 280 px sur 200 : avec une ou
  /// deux publications, on voyait une carte s'arreter aux trois quarts de
  /// l'ecran et un grand vide a droite, sans rien indiquant qu'il fallait
  /// faire defiler. Une annonce se lit, elle ne se parcourt pas du regard.
  /// Nombre de publications montrees sur la page communaute.
  ///
  /// Elles y etaient toutes deroulees : avec une dizaine d'annonces il fallait
  /// faire defiler longtemps avant d'atteindre les clubs de lecture, qui sont
  /// pourtant l'essentiel de cette page. Trois donnent le ton, le reste tient
  /// dans sa propre page.
  static const int _apercuEvenements = 3;

  void _ouvrirTousLesEvenements() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EvenementsPage(
          evenements: _evenements,
          titre: "Actualites de vos auteurs",
          // Cote lecteur, il n'y a rien a faire d'une publication qu'on ne
          // peut ni modifier ni supprimer : on la lit, on revient.
          onOuvrir: afficherEvenement,
        ),
      ),
    );
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
              padding: EdgeInsets.only(bottom: i == apercu.length - 1 ? 0 : 12),
              child: CarteEvenement(
                evenement: apercu[i],
                onTap: () => afficherEvenement(context, apercu[i]),
              ),
            ),
          if (reste > 0)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _ouvrirTousLesEvenements,
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
                        : "Voir les $reste autres publications",
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
}
