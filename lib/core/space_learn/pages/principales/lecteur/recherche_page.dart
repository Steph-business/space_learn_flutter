import 'dart:async';

import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/themes/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:space_learn_flutter/core/themes/layout/recherche_bar.dart';
import 'package:space_learn_flutter/core/themes/app_dimensions.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/bookService.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/book_model.dart';
import '../../widgets/details/book_detail_page.dart';
import '../../widgets/lecteur/boutique/livre_card.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/libraryService.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/authServices.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/library_model.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/user_model.dart';
import 'package:space_learn_flutter/core/utils/message_erreur.dart';
import 'package:space_learn_flutter/core/utils/token_storage.dart';

class RecherchePage extends StatefulWidget {
  const RecherchePage({super.key});

  @override
  State<RecherchePage> createState() => _RecherchePageState();
}

class _RecherchePageState extends State<RecherchePage> {
  final _searchController = TextEditingController();
  final _bookService = BookService();
  final _libraryService = LibraryService();
  List<BookModel> _searchResults = [];
  Set<String> _ownedBookIds = {};
  bool _isLoading = false;
  String _query = "";

  /// Ce qui a empêché la dernière recherche d'aboutir.
  ///
  /// La méthode enchaînait `try` et `finally` sans `catch` : l'indicateur se
  /// remettait bien à zéro, donc pas d'écran figé, mais l'exception partait
  /// dans le vide et la liste restait vide. Une recherche en échec se
  /// présentait exactement comme une recherche sans résultat — « Aucun
  /// résultat trouvé pour "X" » alors que le serveur n'avait rien dit.
  String? _erreur;

  /// Frappe au clavier : on attend une pause avant d'interroger le serveur.
  ///
  /// Sans cela, « harry » déclenchait cinq requêtes, dont quatre périmées
  /// avant d'arriver — même règle que la boutique et l'annuaire des auteurs.
  Timer? _attenteSaisie;

  /// Jeton de la requête courante : la réponse de « har » peut arriver APRÈS
  /// celle de « harry » et s'affichait alors sous le titre « résultats pour
  /// harry ». Une réponse dont le jeton est dépassé se jette.
  int _jetonRecherche = 0;

  @override
  void dispose() {
    _attenteSaisie?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch(String value) {
    _attenteSaisie?.cancel();

    // Le serveur ignore une recherche de moins de deux caractères (le `q`
    // n'est même pas envoyé) : interroger avec une lettre rendrait la
    // première page ENTIÈRE du catalogue en la faisant passer pour des
    // résultats. On attend donc d'avoir de quoi chercher.
    if (value.trim().length < 2) {
      _jetonRecherche++; // invalide toute réponse encore en vol
      setState(() {
        _searchResults = [];
        _query = value.trim();
        _erreur = null;
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _query = value;
      // Dès la frappe, et non au départ de la requête : sinon, pendant
      // l'anti-rebond, l'écran affirmerait « Aucun résultat » pour un terme
      // qui n'a pas encore été cherché.
      _isLoading = true;
      _erreur = null;
    });
    _attenteSaisie = Timer(const Duration(milliseconds: 350), () {
      if (mounted) _rechercher(value);
    });
  }

  Future<void> _rechercher(String value) async {
    final jeton = ++_jetonRecherche;
    setState(() {
      _isLoading = true;
      _erreur = null;
    });

    try {
      final token = await TokenStorage.getToken();
      final futures = [
        // La recherche est faite par le serveur. L'ecran chargeait le
        // catalogue entier puis filtrait en memoire : exact, mais le cout
        // suivait la taille du catalogue au lieu de suivre le nombre de
        // resultats. Le serveur cherche dans le titre ET le nom de l'auteur,
        // comme le faisait le filtre remplace.
        _bookService.getBooksPage(recherche: value),
        if (token != null)
          _libraryService.getUserLibrary(token)
        else
          Future.value(<LibraryModel>[]),
        if (token != null) AuthService().getUser(token) else Future.value(null),
      ];

      final results = await Future.wait(futures);

      // Une réponse dépassée n'écrit plus rien : une requête plus récente est
      // partie, c'est elle qui pilote _isLoading et les résultats.
      if (!mounted || jeton != _jetonRecherche) return;

      final allBooks = results[0] as List<BookModel>;
      final library = results[1] as List<LibraryModel>;
      final currentUser = results[2] as UserModel?;

      // Enrich author names using library data
      final Map<String, String> authorNames = {};
      for (var item in library) {
        if (item.auteurNom != null && item.auteurNom!.isNotEmpty) {
          authorNames[item.livreId] = item.auteurNom!;
        } else if (item.livre?.auteur != null) {
          authorNames[item.livreId] = item.livre!.auteur!.nomComplet;
        }
      }

      final enrichedBooks = allBooks.map((book) {
        if (authorNames.containsKey(book.id) &&
            (book.auteur == null ||
                book.auteur!.nomComplet == 'Auteur inconnu')) {
          return book.copyWith(
            auteur: UserModel(
              id: book.auteurId,
              profilId: book.auteurId,
              email: '',
              nomComplet: authorNames[book.id]!,
              isProfileComplete: false,
            ),
          );
        }
        return book;
      }).toList();

      setState(() {
        _ownedBookIds = {
          ...library.map((e) => e.livreId),
          if (currentUser != null)
            // Sur l'identifiant SEULEMENT : comparer les noms marquait
            // « possédé » tous les livres d'un homonyme du lecteur.
            //
            // L'auteur imbriqué compte aussi : `BookModel.fromJson` laisse
            // `auteurId` vide quand la charge du serveur porte l'objet
            // « auteur » sans champ `auteur_id`. Sur ces résultats-là, un
            // auteur voyait son PROPRE livre proposé à l'achat — le même test
            // qu'`_estAcquis` de l'accueil et que `_checkOwnershipStatus` de
            // la fiche évite cette contradiction d'un écran à l'autre.
            ...allBooks
                .where(
                  (b) =>
                      (b.auteurId.isNotEmpty && b.auteurId == currentUser.id) ||
                      (b.auteur != null && b.auteur!.id == currentUser.id),
                )
                .map((b) => b.id),
        };
        // Les résultats du serveur, tels quels. Le re-filtre local qui se
        // trouvait ici comparait avec la valeur BRUTE : « dupont » suivi de
        // l'espace qu'ajoutent les claviers mobiles donnait
        // `"jean dupont".contains("dupont ")` = false — tous les résultats
        // que le serveur avait trouvés étaient jetés. Le serveur filtre déjà
        // titre OU nom d'auteur avec le terme trimé ; re-filtrer ne pouvait
        // que retrancher.
        _searchResults = enrichedBooks;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || jeton != _jetonRecherche) return;
      setState(() {
        _searchResults = [];
        _erreur = messageLisible(e, repli: "La recherche n'a pas abouti.");
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    AppColors.suivreLeTheme(context);
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.scaffoldBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Iconsax.arrow_left_2,
            color: AppColors.textPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: CustomSearchBar(
          controller: _searchController,
          autofocus: true,
          onChanged: _onSearch,
          hintText: "Rechercher...",
        ),
      ),
      body: _isLoading
          ? Center(
              child: Text(
                "Recherche en cours...",
                style: GoogleFonts.poppins(color: AppColors.textSecondary),
              ),
            )
          // Moins de deux caractères : la recherche n'est pas encore partie
          // (contrat serveur) — on invite à continuer, on n'affirme pas
          // « aucun résultat ».
          : _query.trim().length < 2
          ? _buildEmptyState(
              "Saisissez quelque chose pour commencer la recherche",
            )
          : _erreur != null
          ? _buildErrorState(_erreur!)
          : _searchResults.isEmpty
          ? _buildEmptyState("Aucun résultat trouvé pour \"$_query\"")
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final book = _searchResults[index];
                return _buildSearchResultTile(book);
              },
            ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Iconsax.search_status,
            size: 64,
            color: AppColors.textPrimary.withOpacity(0.1),
          ),
          SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.greyMedium14,
          ),
        ],
      ),
    );
  }

  /// Un échec se dit, et se rejoue.
  ///
  /// L'icône et le bouton distinguent ce cas du « aucun résultat » : la
  /// personne sait qu'il ne s'agit pas de son mot-clé, et qu'insister a un
  /// sens ici, contrairement à une recherche qui n'a rien trouvé.
  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              // Directement, sans repasser par l'anti-rebond : la personne
              // vient d'appuyer, il n'y a pas de frappe à attendre.
              onPressed: () => _rechercher(_query),
              child: const Text("Réessayer"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResultTile(BookModel book) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BookDetailPage(
              book: book,
              isOwned: _ownedBookIds.contains(book.id),
            ),
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 16),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          border: Border.all(color: AppColors.textPrimary.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 90,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
                image:
                    (book.imageCouverture != null &&
                        book.imageCouverture!.isNotEmpty)
                    ? DecorationImage(
                        image: NetworkImage(book.imageCouverture!),
                        fit: BoxFit.cover,
                      )
                    : null,
                color: AppColors.textHint,
              ),
              child:
                  (book.imageCouverture == null ||
                      book.imageCouverture!.isEmpty)
                  ? Icon(Icons.book, color: AppColors.textHint)
                  : null,
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
                  SizedBox(height: 2),
                  Text(
                    "Par ${book.authorName}",
                    style: GoogleFonts.poppins(
                      color: AppColors.accentInk,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    book.description,
                    style: AppTextStyles.grey11,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 8),
                  Text(
                    LivreCard.formatPrix(book.prix),
                    style: AppTextStyles.withColor(
                      AppTextStyles.cardTitle,
                      AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Iconsax.arrow_right_3, color: AppColors.textHint, size: 18),
          ],
        ),
      ),
    );
  }
}
