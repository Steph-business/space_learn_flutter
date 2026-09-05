import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/themes/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:space_learn_flutter/core/themes/app_dimensions.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/libraryService.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/library_model.dart';
import 'package:space_learn_flutter/core/services/session_service.dart';
import 'package:space_learn_flutter/core/utils/message_erreur.dart';
import 'package:space_learn_flutter/core/utils/token_storage.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/auth/login.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/lecteur/communaute/forum_discussion_page.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/evenementModel.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/evenementService.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/discussionService.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/authServices.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/bookService.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/user_model.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/lecteur/communaute/salon_noms.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/communaute/carte_evenement.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/communaute/evenement_apercu.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/communaute/evenements_page.dart';
import 'package:space_learn_flutter/core/themes/layout/nav_bar_all.dart';

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
  final BookService _bookService = BookService();

  /// Le prénom du lecteur, pour que la page s'adresse à lui.
  /// Elle s'ouvrait sur « Vos espaces d'échange » — un intitulé qui aurait
  /// convenu à n'importe qui, sur n'importe quelle application.
  String _prenom = '';
  List<LibraryModel> _library = [];
  List<Evenement> _evenements = [];
  int _cafeMsgCount = 0;
  bool _isLoading = true;
  String? _error;

  /// Le chargement des publications a-t-il échoué ?
  ///
  /// Sur panne, `_evenements` restait simplement vide : les sections
  /// « Rendez-vous » et « Actualités » ne se dessinaient pas, sans un mot ni
  /// bouton réessayer — un lecteur pouvait manquer une dédicace ou un live
  /// annoncés, la page affichant « rien à signaler » alors qu'elle n'avait
  /// pas pu interroger le serveur. Une panne n'est pas un vide.
  bool _evenementsEnPanne = false;

  /// L'activité du salon a-t-elle pu être comptée ?
  ///
  /// L'échec de `getGlobalDiscussions` était avalé sans un mot : `_cafeMsgCount`
  /// restait à zéro et la ligne « N messages » de la carte disparaissait
  /// simplement. Moins bruyant que le zéro affirmé des publications, mais de
  /// la même famille — la carte se lisait comme un salon désert alors que le
  /// serveur n'avait pas pu être interrogé. Quand on ne sait pas, on le dit.
  bool _salonEnPanne = false;

  /// La panne vient-elle d'une session finie plutôt que d'un incident passager ?
  ///
  /// Les deux n'appellent pas le même geste : l'une se répare en réessayant,
  /// l'autre jamais. Même distinction que l'accueil du lecteur.
  bool _sessionExpiree = false;

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
        _sessionExpiree = false;
      });

      final token = await TokenStorage.getToken();
      // Le coffre à jetons est lu de façon asynchrone : sans cette garde, le
      // setState qui suit pouvait tomber sur un écran déjà quitté.
      if (!mounted) return;
      if (token == null) {
        setState(() {
          _sessionExpiree = true;
          _error = "Session expirée. Veuillez vous reconnecter.";
          _isLoading = false;
        });
        return;
      }

      final libraryItems = await _libraryService.getUserLibrary(token);

      // Le prénom et l'utilisateur connecté
      String prenom = '';
      UserModel? currentUser;
      try {
        currentUser = await AuthService().getUser(token);
        if (currentUser != null) {
          prenom = currentUser.nomComplet.trim().split(' ').first;
        }
      } catch (_) {}

      // Si l'utilisateur a écrit des livres, ses propres œuvres sont automatiquement
      // intégrées dans ses clubs de lecture pour qu'il puisse échanger avec ses lecteurs
      // sans avoir besoin d'acheter ses propres livres.
      List<LibraryModel> authorItems = [];
      if (currentUser != null && currentUser.id.isNotEmpty) {
        try {
          final authorBooks = await _bookService.getBooksByAuthorId(
            currentUser.id,
          );
          for (final book in authorBooks) {
            final alreadyInLib = libraryItems.any(
              (item) => item.livre?.id == book.id,
            );
            if (!alreadyInLib) {
              authorItems.add(
                LibraryModel(
                  id: 'author_${book.id}',
                  utilisateurId: currentUser.id,
                  livreId: book.id,
                  acquisVia: 'AUTEUR',
                  auteurNom: currentUser.nomComplet,
                  livre: book,
                  creeLe: book.creeLe,
                ),
              );
            }
          }
        } catch (_) {}
      }

      final allLibraryItems = [...libraryItems, ...authorItems];

      List<Evenement> evts = [];
      bool evenementsEnPanne = false;
      try {
        evts = await _evenementService.getGlobalEvenements(token);
        evts = await _enrichirEvenementsAvecAuteurs(evts, allLibraryItems);
      } catch (e) {
        // On retient la panne au lieu de la taire : l'écran doit la montrer
        // là où les sections auraient dû être, pas afficher un faux calme.
        evenementsEnPanne = true;
      }

      int totalCafeMsgs = 0;
      bool salonEnPanne = false;
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
        // On retient la panne au lieu de la taire : la carte doit dire qu'elle
        // ne sait pas, plutôt que d'escamoter sa ligne d'activité comme si le
        // salon était vide.
        salonEnPanne = true;
      }

      // Filtrer les entrées sans livre valide
      final validItems = allLibraryItems
          .where((item) => item.livre != null)
          .toList();

      if (mounted) {
        setState(() {
          _library = validItems;
          _evenements = evts;
          _evenementsEnPanne = evenementsEnPanne;
          _prenom = prenom;
          _cafeMsgCount = totalCafeMsgs;
          _salonEnPanne = salonEnPanne;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          // La cause, telle que le serveur l'a dite. « Erreur lors du
          // chargement des données. » cachait aussi bien une session finie
          // qu'un réseau coupé, et le lecteur ne pouvait qu'appuyer à nouveau.
          _sessionExpiree = estSessionExpiree(e);
          _error = messageLisible(
            e,
            repli: "Vos espaces d'échange n'ont pas pu être chargés.",
          );
          _isLoading = false;
        });
      }
    }
  }

  /// Termine la session et ramène à l'écran de connexion.
  ///
  /// Le nettoyage passe par [SessionService] : effacer le seul jeton laisserait
  /// sur l'appareil la bibliothèque téléchargée et le profil choisi.
  Future<void> _seReconnecter() async {
    await SessionService.terminer();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
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
    // Publications indisponibles : on ne compte que ce qu'on sait. La phrase
    // annonçait sereinement « le café des lecteurs vous attend » comme si le
    // serveur avait répondu qu'il n'y avait rien, alors qu'on n'avait pas pu
    // l'interroger.
    if (_evenementsEnPanne) return texteLivres;
    if (_evenements.isEmpty) {
      return "$texteLivres · le café des lecteurs vous attend";
    }
    // Le compteur annonçait « 7 actualités » en comptant aussi les rendez-vous,
    // passés compris. On ne compte plus que ce qui est réellement offert au
    // regard : les rendez-vous devant nous, et les actualités vivantes.
    final agenda = _rendezVousAVenir.length;
    final actus = _actualites.length;

    final morceaux = <String>[];
    if (agenda > 0) {
      morceaux.add(agenda == 1 ? "1 rendez-vous" : "$agenda rendez-vous");
    }
    if (actus > 0) {
      morceaux.add(actus == 1 ? "1 actualité" : "$actus actualités");
    }
    if (morceaux.isEmpty) return texteLivres;
    return "$texteLivres · ${morceaux.join(" · ")}";
  }

  @override
  Widget build(BuildContext context) {
    AppColors.suivreLeTheme(context);
    return Scaffold(
      backgroundColor: AppColors.darkSurface,
      body: Column(
        children: [
          const NavBarAll(role: 'lecteur'),
          Expanded(
            child: _isLoading
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
                        // Un bouton qui peut aboutir, ou pas celui-là.
                        //
                        // « Réessayer » s'affichait sous toutes les erreurs,
                        // session finie comprise. Or un jeton mort le reste :
                        // appuyer relançait les mêmes requêtes, qui
                        // échouaient de la même façon. Le seul geste utile
                        // est alors de se reconnecter.
                        ElevatedButton(
                          onPressed: _sessionExpiree
                              ? _seReconnecter
                              : _loadData,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryLight,
                          ),
                          child: Text(
                            _sessionExpiree ? "Se reconnecter" : "Réessayer",
                            style: TextStyle(color: AppColors.onAccent),
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadData,
                    color: AppColors.accentInk,
                    backgroundColor: AppColors.cardBackground,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
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

                          // Deux sections, et non plus une.
                          //
                          // « Annonces & Événements » empilait deux objets qui
                          // ne demandent pas la même chose. Un rendez-vous
                          // porte un engagement — une date, parfois un lien à
                          // rejoindre — et peut se MANQUER ; une actualité se
                          // lit, ou pas. Mêlés, l'urgence du premier se diluait
                          // dans le flux du second : une dédicace et une
                          // nouvelle parution se ressemblaient trait pour trait.
                          //
                          // Le produit avait d'ailleurs déjà tranché — la page
                          // complète propose un filtre « Tout · Annonces ·
                          // Événements » depuis toujours. Seul l'aperçu de
                          // l'accueil l'ignorait.
                          if (_evenementsEnPanne)
                            _panneEvenements()
                          else ...[
                            ..._sectionAgenda(),
                            ..._sectionActualites(),
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20.0,
                              ),
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
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
                  ),
          ),
        ],
      ),
    );
  }

  /// La portion « publications » en panne : on le dit, et on peut réessayer.
  ///
  /// À la place exacte des sections qui n'ont pas pu se remplir — pas un
  /// simple vide qui se lirait comme « vos auteurs n'ont rien annoncé ».
  Widget _panneEvenements() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 30, 20, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Icon(Iconsax.warning_2, color: AppColors.textSecondary, size: 28),
            const SizedBox(height: 10),
            Text(
              "Les annonces et rendez-vous de vos auteurs n'ont pas pu "
              "être chargés. Vérifiez votre connexion.",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _loadData,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accentInk,
                side: BorderSide(color: AppColors.border),
              ),
              child: Text(
                "Réessayer",
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
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
                      color: AppColors.onAccent,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "Recommandations, coup de cœurs et discussions générales",
                    style: AppTextStyles.grey12,
                  ),
                  // L'activité du salon : ce qu'on sait, et sinon qu'on ne
                  // sait pas. La ligne disparaissait purement et simplement
                  // quand le comptage échouait — la carte se lisait alors
                  // comme un salon sans un seul message.
                  if (_salonEnPanne) ...[
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Iconsax.warning_2,
                          size: 10,
                          color: AppColors.textSecondary,
                        ),
                        SizedBox(width: 4),
                        Text(
                          "Activité indisponible",
                          style: GoogleFonts.poppins(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ] else if (_cafeMsgCount > 0) ...[
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

    // On n'affiche un compte que si le serveur en a envoyé un.
    //
    // La carte annonçait « N messages » et un verdict « Nouveau / Actif / Très
    // actif » tirés tous deux de `nombreMessages`. Or la bibliothèque est
    // servie par un simple `Preload("Livre")` (bibliotheque/repository.go),
    // tandis que `nombre_messages` porte `gorm:"-"` et n'est calculé que par
    // la jointure de `ListWithStats`. Le champ est donc ABSENT de cette
    // réponse — pas à zéro — et le modèle le lit 0. Chaque club acheté
    // affichait ainsi « 0 messages · Nouveau », y compris ceux où des
    // dizaines de lecteurs échangent depuis des mois.
    //
    // Une donnée absente n'est pas une donnée nulle. La ligne d'activité ne
    // s'écrit donc que lorsqu'un compte existe vraiment — c'est le cas des
    // œuvres de l'auteur lui-même, chargées par `getBooksByAuthorId` qui
    // passe par `ListWithStats` — et à défaut on montre ce que la réponse
    // porte réellement : le nom de l'auteur. Même raisonnement que la carte
    // jumelle de la page auteur, qui a renoncé pour la même raison à son
    // compteur emprunté.
    final msgCount = book.nombreMessages;
    final auteur = _nomAuteur(libraryItem);

    // Les deux verdicts restants ne se prononcent que sur un compte connu et
    // non nul : « Nouveau » n'y a plus sa place, il ne disait rien d'autre
    // que « le serveur ne nous a rien dit ».
    final activityScore = msgCount > 20 ? "Très actif" : "Actif";
    // greenAccent et grey n'appartiennent a aucune palette de l'application :
    // le premier jurait avec l'orange de la marque, le second ne suivait pas
    // le theme et restait clair en mode sombre.
    final color = msgCount > 20 ? AppColors.success : AppColors.accentInk;

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
                  if (msgCount > 0) ...[
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
                          // « 1 messages » se lisait sur tout club à message
                          // unique.
                          msgCount == 1 ? "1 message" : "$msgCount messages",
                          style: AppTextStyles.grey12,
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
                  ] else if (auteur != null) ...[
                    SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Iconsax.user,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            "par $auteur",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.grey12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Le nom de l'auteur, quand le serveur le connaît vraiment.
  ///
  /// Deux sources, dans cet ordre : le champ de jointure de la bibliothèque
  /// (`nom_auteur`, posé par `remplirNomsAuteurs`), puis celui du livre.
  /// `authorName` répond « Auteur inconnu » quand il ne sait pas : ce n'est
  /// pas un nom, c'est un aveu — on le traite comme une absence plutôt que de
  /// l'écrire sous la couverture.
  String? _nomAuteur(LibraryModel item) {
    final deLaJointure = item.auteurNom?.trim() ?? '';
    final nom = deLaJointure.isNotEmpty
        ? deLaJointure
        : (item.livre?.authorName ?? '');
    if (nom.isEmpty || nom == 'Auteur inconnu') return null;
    return nom;
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

  /// Les rendez-vous encore devant nous, le plus proche d'abord.
  List<Evenement> get _rendezVousAVenir =>
      _evenements.where((e) => e.dateEvenement != null && !e.passe).toList();

  /// Les actualites : tout ce qui n'a pas de date de rendez-vous.
  List<Evenement> get _actualites =>
      _evenements.where((e) => e.dateEvenement == null).toList();

  /// « Prochains rendez-vous » : ce qu'on peut manquer.
  ///
  /// Absente s'il n'y en a aucun. Un titre au-dessus du vide donne
  /// l'impression d'un chargement qui n'aboutit pas.
  List<Widget> _sectionAgenda() =>
      _sectionPublications("Rendez-vous", _rendezVousAVenir);

  /// « Actualités de vos auteurs » : ce qui se lit.
  List<Widget> _sectionActualites() =>
      _sectionPublications("Actualités", _actualites);

  List<Widget> _sectionPublications(String titre, List<Evenement> membres) {
    if (membres.isEmpty) return const [];

    final apercu = membres.take(_apercuEvenements).toList();

    return [
      Padding(
        padding: const EdgeInsets.only(left: 20, top: 30, bottom: 10),
        child: Text(
          titre,
          style: GoogleFonts.poppins(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            for (var i = 0; i < apercu.length; i++)
              Padding(
                padding: EdgeInsets.only(
                  bottom: i == apercu.length - 1 ? 0 : 12,
                ),
                child: CarteEvenement(
                  // La Key suit l'ÉVÉNEMENT, pas son rang dans la liste.
                  //
                  // Sans elle, Flutter apparie les cartes par position : au
                  // rafraîchissement, quand un rendez-vous bascule de
                  // « Rendez-vous » vers « Actualités » ou change d'ordre, le
                  // State du bouton « Me le rappeler » restait en place et se
                  // retrouvait rattaché à un AUTRE rendez-vous — il affichait
                  // « Rappel posé » là où aucun rappel n'existait, et le
                  // lecteur croyait qu'on le préviendrait la veille. Le
                  // didUpdateWidget du bouton n'est qu'un filet ; la
                  // réparation est ici.
                  key: ValueKey(apercu[i].id),
                  evenement: apercu[i],
                  onTap: () => afficherEvenement(context, apercu[i]),
                ),
              ),
          ],
        ),
      ),
      // Un seul renvoi vers la liste complete, pose sous la derniere section :
      // deux boutons « Voir tout » menant au meme ecran feraient croire a deux
      // destinations.
      if (identical(membres, _actualites) || _actualites.isEmpty)
        _lienVersToutesLesPublications(),
    ];
  }

  /// Le renvoi vers la liste complete, ou vit aussi le passe.
  Widget _lienVersToutesLesPublications() {
    final reste = _evenements.length;
    if (reste == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: _ouvrirTousLesEvenements,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.accentInk,
            side: BorderSide(color: AppColors.border),
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
            ),
          ),
          child: Text(
            "Voir toutes les publications ($reste)",
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Future<List<Evenement>> _enrichirEvenementsAvecAuteurs(
    List<Evenement> evts,
    List<LibraryModel> libraryItems,
  ) async {
    final Map<String, String> cacheAuteurs = {};

    for (var item in libraryItems) {
      final livre = item.livre;
      final nom = (item.auteurNom != null && item.auteurNom!.trim().isNotEmpty)
          ? item.auteurNom!.trim()
          : (livre != null ? livre.authorName : '');
      if (livre != null &&
          livre.auteurId.isNotEmpty &&
          nom.isNotEmpty &&
          nom != 'Auteur inconnu') {
        cacheAuteurs[livre.auteurId] = nom;
      }
    }

    final enriched = <Evenement>[];
    for (var evt in evts) {
      if (evt.nomAuteur != null && evt.nomAuteur!.trim().isNotEmpty) {
        enriched.add(evt);
        continue;
      }

      String? nom = cacheAuteurs[evt.auteurId];

      if (nom == null && evt.auteurId.isNotEmpty) {
        try {
          final books = await _bookService.getBooksByAuthorId(evt.auteurId);
          if (books.isNotEmpty &&
              books.first.authorName.isNotEmpty &&
              books.first.authorName != 'Auteur inconnu') {
            nom = books.first.authorName;
            cacheAuteurs[evt.auteurId] = nom;
          }
        } catch (_) {}
      }

      if (nom != null && nom.isNotEmpty && nom != 'Auteur inconnu') {
        enriched.add(
          Evenement(
            id: evt.id,
            typePublication: evt.typePublication,
            categorie: evt.categorie,
            titre: evt.titre,
            contenu: evt.contenu,
            imageUrl: evt.imageUrl,
            dateEvenement: evt.dateEvenement,
            auteurId: evt.auteurId,
            nomAuteur: nom,
            creeLe: evt.creeLe,
            // Cette recopie n'existe que pour poser le nom de l'auteur, mais
            // elle rebâtit l'objet champ par champ : les deux champs oubliés
            // retombaient sur leur défaut. « passe: false » remontait un
            // rendez-vous terminé dans la section « À venir » et lui retirait
            // sa mention « Terminé » ; « lienVisio: null » effaçait le badge
            // « Visio » et le bouton « Rejoindre ». La page de l'auteur avait
            // déjà reçu ce correctif — c'était la même panne, restée d'un
            // seul côté.
            passe: evt.passe,
            lienVisio: evt.lienVisio,
          ),
        );
      } else {
        enriched.add(evt);
      }
    }
    return enriched;
  }
}
