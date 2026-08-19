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

  void _onSearch(String value) async {
    if (value.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _query = "";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _query = value;
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

      if (mounted) {
        setState(() {
          _ownedBookIds = {
            ...library.map((e) => e.livreId),
            if (currentUser != null)
              ...allBooks
                  .where(
                    (b) =>
                        (b.auteurId.isNotEmpty &&
                            b.auteurId == currentUser.id) ||
                        (b.authorName.isNotEmpty &&
                            b.authorName.trim().toLowerCase() ==
                                currentUser.nomComplet.trim().toLowerCase()),
                  )
                  .map((b) => b.id),
          };
        });
      }

      // Le filtre en memoire qui se trouvait ici portait sur le titre, le nom
      // de l'auteur et l'identifiant de l'auteur. Les deux premiers sont
      // desormais appliques par le serveur ; la recherche par identifiant
      // d'auteur, elle, disparait — un lecteur ne tape pas un UUID.
      final filtered = enrichedBooks.where((book) {
        final titleMatch = book.titre.toLowerCase().contains(
          value.toLowerCase(),
        );
        final authorMatch =
            book.authorName.toLowerCase().contains(value.toLowerCase()) ||
            book.auteurId.toLowerCase().contains(value.toLowerCase());
        return titleMatch || authorMatch;
      }).toList();

      setState(() {
        _searchResults = filtered;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searchResults = [];
        _erreur = messageLisible(e, repli: "La recherche n'a pas abouti.");
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
          : _query.isEmpty
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
              onPressed: () => _onSearch(_query),
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
