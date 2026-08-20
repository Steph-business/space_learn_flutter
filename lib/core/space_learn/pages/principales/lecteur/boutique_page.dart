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
  Map<String, double> _notesDuLecteur = {};
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
    setState(() {
      _isLoading = true;
      _error = null;
      _curseur = null;
      _finDuCatalogue = false;
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

      if (!mounted) return;

      final premiere = resultats[0] as PageCatalogue;
      final categories = resultats[1] as List<Categorie>;
      final bibliotheque = resultats[2] as List<LibraryModel>;
      final avis = resultats[3] as List<ReviewModel>;

      setState(() {
        _categories = categories;
        _ownedBookIds = bibliotheque.map((e) => e.livreId).toSet();
        _notesDuLecteur = {
          for (final a in avis) a.livreId: a.note.toDouble(),
        };
        _books = _enrichir(premiere.livres);
        _curseur = premiere.curseurSuivant;
        _finDuCatalogue = !premiere.aUneSuite;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Erreur lors du chargement des livres.";
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
    setState(() => _chargeLaSuite = true);

    try {
      final token = await TokenStorage.getToken();
      final suite = await _bookService.getCataloguePage(
        statut: 'publie',
        authToken: token,
        categorieId: _categorieChoisie,
        recherche: _searchQuery,
        apres: _curseur,
      );

      if (!mounted) return;
      setState(() {
        _books = [..._books, ..._enrichir(suite.livres)];
        _curseur = suite.curseurSuivant;
        // Le serveur dit lui-meme s'il reste quelque chose : il demande une
        // ligne de plus que necessaire pour le savoir, sans compter la table.
        _finDuCatalogue = !suite.aUneSuite;
        _chargeLaSuite = false;
      });
    } catch (_) {
      if (mounted) setState(() => _chargeLaSuite = false);
    }
  }

  /// Applique au livre ce que le lecteur en sait deja : sa propre note.
  List<BookModel> _enrichir(List<BookModel> livres) {
    return livres.map((b) {
      final note = _notesDuLecteur[b.id];
      return note == null ? b : b.copyWith(noteMoyenne: note);
    }).toList();
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
