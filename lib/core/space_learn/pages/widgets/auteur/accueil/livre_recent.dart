import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/themes/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:space_learn_flutter/core/themes/app_dimensions.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/ecrivain/livres_page.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/bookService.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/book_model.dart';
import 'package:space_learn_flutter/core/utils/token_storage.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/authServices.dart';
import 'package:space_learn_flutter/core/utils/message_erreur.dart';
import 'package:space_learn_flutter/core/services/session_service.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/auth/login.dart';

class AuteurLivresRecents extends StatefulWidget {
  const AuteurLivresRecents({super.key});

  @override
  State<AuteurLivresRecents> createState() => _AuteurLivresRecentsState();
}

class _AuteurLivresRecentsState extends State<AuteurLivresRecents> {
  final BookService _bookService = BookService();
  final AuthService _authService = AuthService();
  List<BookModel> _books = [];
  bool _isLoading = true;

  /// Ce qui a empêché la liste d'arriver.
  ///
  /// Le catch ne posait rien : il baissait l'indicateur, et la carte affichait
  /// « Aucun livre publié récemment. » Depuis que `getBooksByAuthorId` lève au
  /// lieu de rendre `[]`, ce chemin est vivant — un 500 ou un réseau coupé
  /// annonçait donc à un auteur qui vend dix livres qu'il n'avait rien publié.
  String? _erreur;

  /// L'échec vient d'une session finie : « Réessayer » n'y peut rien, le jeton
  /// restera mort à chaque tentative. Même distinction que livres_page.dart,
  /// où mène le « Voir tout » de cette carte.
  bool _sessionExpiree = false;

  @override
  void initState() {
    super.initState();
    _loadBooks();
  }

  Future<void> _loadBooks() async {
    setState(() {
      _isLoading = true;
      _erreur = null;
      _sessionExpiree = false;
    });

    try {
      final token = await TokenStorage.getToken();
      // Sans jeton, la méthode sortait par le bout de ses `if` sans rien
      // écrire : l'indicateur tournait pour toujours, et la session finie
      // n'était dite nulle part.
      if (token == null) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _sessionExpiree = true;
          _erreur = "Votre session a expiré. Reconnectez-vous.";
        });
        return;
      }

      final user = await _authService.getUser(token);
      if (!mounted) return;
      if (user == null) {
        // Un jeton accepté mais sans profil derrière : le compte n'est plus
        // joignable, c'est la même issue qu'une session finie.
        setState(() {
          _isLoading = false;
          _sessionExpiree = true;
          _erreur = "Votre session a expiré. Reconnectez-vous.";
        });
        return;
      }

      final books = await _bookService.getBooksByAuthor(user.id);
      if (!mounted) return;
      // « Récent » veut dire récemment PARU, pas récemment ébauché : un
      // brouillon vieux de six mois publié hier doit remonter en tête.
      books.sort(
        (a, b) => (b.dateAAfficher ?? DateTime(0)).compareTo(
          a.dateAAfficher ?? DateTime(0),
        ),
      );
      setState(() {
        _books = books.take(3).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sessionExpiree = estSessionExpiree(e);
        _erreur = messageLisible(
          e,
          repli: "Vos livres n'ont pas pu être chargés.",
        );
        _isLoading = false;
      });
    }
  }

  /// Fin de session complète, puis retour à l'écran de connexion.
  ///
  /// [SessionService.terminer] est le point de nettoyage UNIQUE : effacer le
  /// seul jeton laisserait au compte suivant le cache et les préférences du
  /// précédent.
  Future<void> _seReconnecter() async {
    await SessionService.terminer();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    AppColors.suivreLeTheme(context);
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    // La panne AVANT le vide : sinon un 500 se lit « vous n'avez rien
    // publié », ce qui est faux et sans recours.
    if (_erreur != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 40,
                color: AppColors.error,
              ),
              const SizedBox(height: 12),
              Text(
                _erreur!,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              // Deux issues distinctes : relancer l'appel n'a de sens que si
              // la session tient encore.
              ElevatedButton(
                onPressed: _sessionExpiree ? _seReconnecter : _loadBooks,
                child: Text(
                  _sessionExpiree ? "Se reconnecter" : "Réessayer",
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_books.isEmpty) {
      return Center(
        child: Text(
          "Aucun livre publié récemment.",
          style: GoogleFonts.poppins(color: AppColors.textHint),
        ),
      );
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Mes livres publiés (${_books.length})",
              style: AppTextStyles.sectionTitle,
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LivresPage()),
                );
              },
              child: Text(
                "Voir tout",
                style: GoogleFonts.poppins(
                  color: AppColors.accentInk,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 10),
        ..._books.map((book) => _buildBookCard(book)),
      ],
    );
  }

  Widget _buildBookCard(BookModel book) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 60,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(
                    AppDimensions.radiusInner,
                  ),
                  image:
                      (book.imageCouverture != null &&
                          book.imageCouverture!.isNotEmpty)
                      ? DecorationImage(
                          image: NetworkImage(book.imageCouverture!),
                          fit: BoxFit.cover,
                        )
                      : null,
                  color: AppColors.border,
                ),
                child:
                    (book.imageCouverture == null ||
                        book.imageCouverture!.isEmpty)
                    ? Icon(Icons.book, color: AppColors.textHint, size: 30)
                    : null,
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.titre,
                      style: AppTextStyles.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    // Deux mensonges tenaient sur cette ligne.
                    //
                    // `categorieId` est un identifiant : la carte affichait
                    // donc un UUID à la place du nom de la catégorie, ou
                    // « Fiction » par défaut pour un livre qui n'en était pas.
                    // Et « N lectures » venait de `telechargements`, que le
                    // modèle remplissait avec le nombre d'avis. On nomme la
                    // catégorie quand le serveur l'a jointe, et on compte des
                    // avis quand ce sont des avis.
                    Text(
                      [
                        if (book.categorie?.nom.isNotEmpty == true)
                          book.categorie!.nom,
                        book.nombreAvis == 1
                            ? "1 avis"
                            : "${book.nombreAvis} avis",
                      ].join(" • "),
                      style: AppTextStyles.bodyFaded12,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildButton(
                  "MODIFIER",
                  AppColors.border.withOpacity(0.5),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildButton("STATS", AppColors.border.withOpacity(0.5)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildButton(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
      ),
      child: Center(
        child: Text(
          label,
          style: GoogleFonts.poppins(
            color: AppColors.accentInk.withOpacity(0.8),
            fontWeight: FontWeight.bold,
            fontSize: 12,
            letterSpacing: 1.1,
          ),
        ),
      ),
    );
  }
}
