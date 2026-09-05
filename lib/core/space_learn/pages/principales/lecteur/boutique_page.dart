import 'dart:async';

import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/themes/app_dimensions.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../themes/layout/recherche_bar.dart';
import '../../widgets/lecteur/boutique/livre_card.dart';
import '../../widgets/lecteur/boutique/select_categorie.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/bookService.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/book_model.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/libraryService.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/library_model.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/review_service.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/review_model.dart';
import 'package:space_learn_flutter/core/themes/layout/nav_bar_all.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/categorie_service.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/categorie.dart';
import 'package:space_learn_flutter/core/utils/token_storage.dart';
import 'package:space_learn_flutter/core/utils/message_erreur.dart';

class MarketplacePage extends StatefulWidget {
  const MarketplacePage({super.key});

  @override
  State<MarketplacePage> createState() => _MarketplacePageState();
}

class _MarketplacePageState extends State<MarketplacePage> {
  final BookService _bookService = BookService();
  final LibraryService _libraryService = LibraryService();
  final ReviewService _reviewService = ReviewService();
  final CategorieService _categorieService = CategorieService();
  List<BookModel> _books = [];
  List<Categorie> _categories = [];
  Set<String> _ownedBookIds = {};

  /// La note que CE lecteur a déposée, par livre — portée à part, jamais
  /// versée dans le livre.
  ///
  /// `_enrichir` faisait `copyWith(noteMoyenne: note)` : la note personnelle
  /// ÉCRASAIT la moyenne du serveur. Un ouvrage moyenné 4,3 sur 37 avis mais
  /// noté 2 par ce lecteur affichait « 2,0 » sur sa carte, et la fiche, ouverte
  /// avec le même objet, en héritait — « 2.0 (37 avis) ». Un chiffre en
  /// remplaçait un autre sans le dire, ce qui est exactement ce que la maison
  /// ne fait pas.
  ///
  /// La moyenne affichée est désormais TOUJOURS celle du serveur ; cette
  /// note-ci descend séparément dans la carte, qui la nomme.
  ///
  /// Entier et non réel : une note d'avis vaut 1 à 5 (contrainte du serveur,
  /// `note BETWEEN 1 AND 5`). La convertir en double n'avait de sens que pour
  /// la faire passer pour une moyenne.
  Map<String, int> _notesDuLecteur = {};
  bool _isLoading = true;
  String? _error;

  // State variables for category filtering
  String _selectedCategory = "Tout";
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();
  bool _isGridView = true;

  /// La pagination du catalogue.
  ///
  /// La boutique telechargeait le catalogue entier puis filtrait en memoire.
  /// Categorie et recherche etaient exactes, mais leur cout croissait avec le
  /// catalogue au lieu de croitre avec ce qui est affiche : a dix mille
  /// livres, ouvrir la boutique les aurait tous telecharges pour en montrer
  /// vingt.
  ///
  /// Le serveur filtre et decoupe desormais ; l'ecran demande la suite quand
  /// le lecteur approche du bas.
  final ScrollController _defilement = ScrollController();

  /// Le curseur designe le dernier livre recu, non un rang.
  ///
  /// « page 2 » suppose une liste figee. Le catalogue s'allonge pendant qu'on
  /// le parcourt : un livre publie entre deux pages decale tout d'un cran, et
  /// le lecteur revoit celui qu'il venait de depasser. En defilement infini,
  /// c'est le cas courant.
  String? _curseur;
  bool _chargeLaSuite = false;
  bool _finDuCatalogue = false;

  /// Ce qui a empêché la page suivante d'arriver.
  ///
  /// L'échec était TOTALEMENT muet : le pied de liste n'affichait la roue que
  /// pendant le chargement et le message de fin qu'en fin de catalogue —
  /// après un échec, rien. Le lecteur arrivait en bas, la liste s'arrêtait,
  /// aucun message, aucun bouton, et la reprise dépendait d'un nouveau
  /// défilement qu'il n'avait aucune raison de tenter.
  String? _echecSuite;

  /// Jeton de la requête courante : le filtre affiché et la réponse reçue
  /// doivent venir de la même génération.
  ///
  /// Sans lui, la page suivante de « Tout », partie avant un tap sur
  /// « Romans », arrivait APRÈS le rechargement : ses livres hors-catégorie
  /// se concaténaient à la liste filtrée et son curseur écrasait celui du
  /// nouveau filtre — le défilement continuait l'ancien parcours.
  int _generation = 0;

  /// Frappe au clavier : on attend une pause avant d'interroger le serveur.
  ///
  /// Sans cela, « quantique » declenche neuf recherches, dont huit sont
  /// perimees avant d'arriver.
  Timer? _attenteSaisie;

  @override
  void initState() {
    super.initState();
    _defilement.addListener(_auDefilement);
    _loadBooks();
  }

  @override
  void dispose() {
    _attenteSaisie?.cancel();
    _defilement.removeListener(_auDefilement);
    _defilement.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Demande la suite avant d'avoir atteint le bas.
  ///
  /// Six cents pixels d'avance : le temps que la page arrive, le lecteur y
  /// est. Attendre le bas exact ferait apparaitre un vide a chaque palier.
  void _auDefilement() {
    if (!_defilement.hasClients) return;
    // Après un échec, le défilement ne relance plus de lui-même : ce
    // listener est notifié à chaque pixel parcouru — pendant un lancer, une
    // soixantaine de tentatives par seconde, que le limiteur du serveur
    // transformerait en 429. La reprise passe par le bouton « Réessayer » du
    // pied de liste, seul geste volontaire.
    if (_echecSuite != null) return;
    final reste =
        _defilement.position.maxScrollExtent - _defilement.position.pixels;
    if (reste < 600) _chargerLaSuite();
  }

  /// L'identifiant de la categorie choisie, ou null pour « Tout ».
  ///
  /// Le serveur filtre sur l'identifiant, l'ecran affiche un nom : la
  /// correspondance se fait ici, et une categorie inconnue vaut « Tout »
  /// plutot qu'un catalogue vide.
  String? get _categorieChoisie {
    if (_selectedCategory == "Tout") return null;
    for (final c in _categories) {
      if (c.nom == _selectedCategory) return c.id;
    }
    return null;
  }

  /// Premiere page du catalogue, selon le filtre courant.
  ///
  /// Recharge tout : c'est le point d'entree de l'ecran, du tirer-pour-
  /// rafraichir, d'un changement de categorie et d'une nouvelle recherche.
  Future<void> _loadBooks() async {
    // Toute réponse encore en vol appartient à la génération précédente :
    // elle sera jetée à l'arrivée, y compris une page suivante.
    final generation = ++_generation;
    setState(() {
      _isLoading = true;
      _error = null;
      _curseur = null;
      _finDuCatalogue = false;
      // L'échec de pagination appartient à l'ancien parcours : le nouveau
      // repart sans lui, sinon le pied de liste garderait un « Réessayer »
      // qui ne concerne plus rien.
      _echecSuite = null;
      // Une suite en vol ne doit pas bloquer la pagination du nouveau
      // filtre : sa réponse sera ignorée, c'est ici qu'on libère le verrou.
      _chargeLaSuite = false;
    });

    try {
      final token = await TokenStorage.getToken();

      final resultats = await Future.wait([
        _bookService.getCataloguePage(
          statut: 'publie',
          authToken: token,
          categorieId: _categorieChoisie,
          recherche: _searchQuery,
        ),
        _categorieService.getCategories(),
        // La bibliotheque sert ici de test d'appartenance : elle dit quelles
        // cartes portent « Deja acquis ». Elle n'est pas paginee — elle
        // grandit avec ce qu'un lecteur possede, pas avec le catalogue — mais
        // c'est une liste complete de plus, a surveiller.
        token != null
            ? _libraryService.getUserLibrary(token)
            : Future.value(<LibraryModel>[]),
        token != null
            ? _reviewService.getUserReviews(token)
            : Future.value(<ReviewModel>[]),
      ]);

      // Une réponse d'une génération dépassée ne touche plus à rien : un
      // rechargement plus récent est déjà parti, c'est lui qui fait foi.
      if (!mounted || generation != _generation) return;

      final premiere = resultats[0] as PageCatalogue;
      final categories = resultats[1] as List<Categorie>;
      final bibliotheque = resultats[2] as List<LibraryModel>;
      final avis = resultats[3] as List<ReviewModel>;

      setState(() {
        _categories = categories;
        _ownedBookIds = bibliotheque.map((e) => e.livreId).toSet();
        _notesDuLecteur = {
          for (final a in avis) a.livreId: a.note,
        };
        // Les livres arrivent tels que le serveur les a rendus : leur
        // `noteMoyenne` n'est plus retouchée par personne.
        _books = premiere.livres;
        _curseur = premiere.curseurSuivant;
        _finDuCatalogue = !premiere.aUneSuite;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(() {
          // Le message du serveur tel quel : « Trop de tentatives » ou
          // « Pas de connexion » disent quoi faire, un texte générique non.
          _error = messageLisible(
            e,
            repli: "Erreur lors du chargement des livres.",
          );
          _isLoading = false;
        });
      }
    }
  }

  /// La page suivante, ajoutee a la suite.
  ///
  /// Un echec n'efface pas ce qui est deja affiche : le lecteur garde sa
  /// liste, et le prochain defilement retentera.
  Future<void> _chargerLaSuite() async {
    if (_chargeLaSuite || _finDuCatalogue || _isLoading || _curseur == null) {
      return;
    }
    final generation = _generation;
    setState(() {
      _chargeLaSuite = true;
      _echecSuite = null;
    });

    try {
      final token = await TokenStorage.getToken();
      final suite = await _bookService.getCataloguePage(
        statut: 'publie',
        authToken: token,
        categorieId: _categorieChoisie,
        recherche: _searchQuery,
        apres: _curseur,
      );

      // Reponse d'un ancien filtre : on la jette. Concatener ici melait des
      // livres hors-categorie a la liste filtree et ecrasait le curseur du
      // nouveau parcours. `_loadBooks` a deja remis `_chargeLaSuite` a false.
      if (!mounted || generation != _generation) return;
      setState(() {
        _books = [..._books, ...suite.livres];
        _curseur = suite.curseurSuivant;
        // Le serveur dit lui-meme s'il reste quelque chose : il demande une
        // ligne de plus que necessaire pour le savoir, sans compter la table.
        _finDuCatalogue = !suite.aUneSuite;
        _chargeLaSuite = false;
      });
    } catch (e) {
      // Un echec ne pose plus « fin du catalogue » : getCataloguePage rendait
      // une page vide avec aUneSuite=false sur une coupure reseau, la ligne
      // au-dessus posait _finDuCatalogue=true et _curseur=null, et le garde
      // d'entree interdisait toute reprise — l'ecran affirmait « Vous avez vu
      // tous les livres ». Le service leve desormais, curseur et drapeau sont
      // intacts.
      //
      // Et l'echec se DIT : garder le curseur ne suffisait pas, puisque rien
      // a l'ecran n'indiquait qu'il restait quelque chose a charger.
      if (mounted && generation == _generation) {
        setState(() {
          _echecSuite = messageLisible(
            e,
            repli: "La suite du catalogue n'a pas pu être chargée.",
          );
          _chargeLaSuite = false;
        });
      }
    }
  }

  /// Nouvelle recherche, apres une pause dans la frappe.
  void _surRecherche(String valeur) {
    _attenteSaisie?.cancel();
    setState(() => _searchQuery = valeur);
    _attenteSaisie = Timer(const Duration(milliseconds: 400), () {
      if (mounted) _loadBooks();
    });
  }

  /// Recherche ou filtre sans resultat.
  ///
  /// La grille se contentait de ne rien afficher : une page vide ressemble a
  /// un chargement qui n'a pas abouti, et rien n'indiquait qu'il suffisait de
  /// changer de mot.
  Widget _aucunResultat() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 60, 40, 60),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, size: 44, color: AppColors.textHint),
          const SizedBox(height: 14),
          Text(
            _searchQuery.isNotEmpty
                ? "Aucun livre ne correspond à « $_searchQuery »."
                : "Aucun livre dans cette catégorie.",
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          if (_searchQuery.isNotEmpty || _selectedCategory != "Tout") ...[
            const SizedBox(height: 14),
            TextButton(
              onPressed: () => setState(() {
                _searchQuery = '';
                _searchController.clear();
                _selectedCategory = "Tout";
              }),
              child: Text(
                "Voir tout le catalogue",
                style: GoogleFonts.poppins(
                  color: AppColors.accentInk,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _onCategorySelected(String category) {
    if (category == _selectedCategory) return;
    setState(() => _selectedCategory = category);
    // Le filtre est applique par le serveur : changer de categorie repart de
    // la premiere page, sinon on filtrerait les seules pages deja chargees.
    _loadBooks();
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(40.0),
          child: Text(
            "Chargement de la boutique...",
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    } else if (_error != null) {
      return SizedBox(
        height: 300,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: AppColors.error,
              ),
              SizedBox(height: 16),
              Text(_error!, style: TextStyle(color: AppColors.textPrimary)),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadBooks,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryLight,
                ),
                child: Text("Réessayer"),
              ),
            ],
          ),
        ),
      );
    } else if (_books.isEmpty &&
        _searchQuery.isEmpty &&
        _selectedCategory == "Tout") {
      // Catalogue reellement vide. Le cas « aucun resultat » passe par la
      // suite : sortir ici emporterait la barre de recherche et les
      // categories, laissant le lecteur sans moyen d'effacer ce qu'il a tape.
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: Text(
          "Aucun livre disponible.",
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    } else {
      // La liste est celle rendue par le serveur : categorie et recherche y
      // ont deja ete appliquees. Le filtrage en memoire qui se trouvait ici
      // ne pouvait porter que sur les pages deja telechargees — il aurait
      // donc cache des resultats presents plus loin dans le catalogue.
      final filteredBooks = _books;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 8),
          // Search & Filter Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: CustomSearchBar(
                        controller: _searchController,
                        onChanged: _surRecherche,
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => setState(() => _isGridView = !_isGridView),
                      child: Container(
                        height: 48,
                        width: 48,
                        decoration: BoxDecoration(
                          color: AppColors.cardBackground,
                          borderRadius: BorderRadius.circular(
                            AppDimensions.radiusCard,
                          ),
                          border: Border.all(
                            color: _isGridView
                                ? AppColors.accentInk
                                : Colors.transparent,
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          _isGridView
                              ? Icons.list_rounded
                              : Icons.grid_view_rounded,
                          color: AppColors.textPrimary,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 22),
                SelectCategorie(
                  categories: ["Tout", ..._categories.map((c) => c.nom)],
                  selectedCategory: _selectedCategory,
                  onCategorySelected: _onCategorySelected,
                ),
                SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _selectedCategory == "Tout"
                          ? "Tous les livres"
                          : _selectedCategory,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      "${filteredBooks.length} livres",
                      style: GoogleFonts.poppins(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Sans resultat, on remplace la grille — et elle seule. Un retour
          // anticipe emporterait la barre de recherche et les categories avec
          // lui, laissant le lecteur sans moyen d'effacer ce qu'il a tape.
          if (filteredBooks.isEmpty)
            _aucunResultat()
          else if (_isGridView)
            // La grille se cale sur la carte, et non l'inverse.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: LayoutBuilder(
                builder: (context, contraintes) {
                  const colonnes = 2;
                  const ecart = 14.0;
                  final largeurCarte =
                      (contraintes.maxWidth - ecart * (colonnes - 1)) /
                      colonnes;
                  final hauteurCarte = LivreCard.hauteurPour(largeurCarte);

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: colonnes,
                      childAspectRatio: largeurCarte / hauteurCarte,
                      crossAxisSpacing: ecart,
                      mainAxisSpacing: ecart,
                    ),
                    itemCount: filteredBooks.length,
                    itemBuilder: (context, index) {
                      final book = filteredBooks[index];
                      return LivreCard(
                        book: book,
                        isOwned: _ownedBookIds.contains(book.id),
                        // Sa note voyage à côté du livre, plus dedans : la
                        // carte l'affiche sous son nom, l'étoile du haut
                        // restant celle de la moyenne du serveur.
                        noteDuLecteur: _notesDuLecteur[book.id],
                      );
                    },
                  );
                },
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredBooks.length,
                itemBuilder: (context, index) {
                  final book = filteredBooks[index];
                  return LivreListCard(
                    book: book,
                    isOwned: _ownedBookIds.contains(book.id),
                    // Même règle en liste qu'en grille : les deux
                    // présentations de la boutique montrent la même moyenne.
                    noteDuLecteur: _notesDuLecteur[book.id],
                  );
                },
              ),
            ),
          if (_chargeLaSuite)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: AppColors.accentInk,
                  ),
                ),
              ),
            )
          // Une PANNE n'est pas une fin de catalogue : elle se dit, avec de
          // quoi la relancer. Sans cette ligne, la liste s'arretait en bas
          // sans un mot et le lecteur croyait avoir tout vu.
          else if (_echecSuite != null)
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 24,
                horizontal: 20,
              ),
              child: Column(
                children: [
                  Text(
                    _echecSuite!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: AppColors.textSecondary,
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: _chargerLaSuite,
                    icon: Icon(
                      Icons.refresh_rounded,
                      size: 18,
                      color: AppColors.accentInk,
                    ),
                    label: Text(
                      "Réessayer",
                      style: GoogleFonts.poppins(
                        color: AppColors.accentInk,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (_finDuCatalogue && _books.length > BookService.taillePage)
            // Dire que la liste est complete evite de continuer a defiler en
            // esperant qu'il en vienne d'autres.
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  "Vous avez vu tous les livres.",
                  style: GoogleFonts.poppins(
                    color: AppColors.textHint,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ),
          SizedBox(height: 100),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    AppColors.suivreLeTheme(context);
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: Column(
        children: [
          const NavBarAll(role: 'lecteur'),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadBooks,
              color: AppColors.accentInk,
              backgroundColor: AppColors.cardBackground,
              child: SingleChildScrollView(
                controller: _defilement,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [_buildBody(context)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
