import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:space_learn_flutter/core/space_learn/data/dataServices/bookService.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/libraryService.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/book_model.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/details/book_detail_page.dart';
import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/themes/app_dimensions.dart';
import 'package:space_learn_flutter/core/utils/message_erreur.dart';
import 'package:space_learn_flutter/core/utils/token_storage.dart';

/// Écran d'attente entre un lien de recommandation et la fiche du livre.
///
/// Un lien partagé ne transporte qu'un identifiant : le livre doit être chargé
/// avant de pouvoir afficher sa fiche. Cette page rend l'attente visible et,
/// surtout, rend l'échec explicable — un lien vers un livre retiré du catalogue
/// doit dire pourquoi, pas rester sur un écran vide.
class BookLoaderPage extends StatefulWidget {
  final String livreId;

  const BookLoaderPage({super.key, required this.livreId});

  @override
  State<BookLoaderPage> createState() => _BookLoaderPageState();
}

class _BookLoaderPageState extends State<BookLoaderPage> {
  final BookService _bookService = BookService();
  final LibraryService _libraryService = LibraryService();

  String? _erreur;

  /// L'échec est une PANNE (réseau, serveur muet), pas un livre disparu.
  ///
  /// La distinction commande l'écran : une panne se réessaie, un 404 non.
  bool _estUnePanne = false;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  void _reessayer() {
    setState(() {
      _erreur = null;
      _estUnePanne = false;
    });
    _charger();
  }

  Future<void> _charger() async {
    try {
      final token = await TokenStorage.getToken();
      final BookModel livre = await _bookService.getBookById(
        widget.livreId,
        authToken: token,
      );

      // Savoir si le lecteur possède déjà le livre change ce que la fiche
      // propose : lire, ou acheter.
      bool possede = false;
      if (token != null) {
        try {
          final bibliotheque = await _libraryService.getUserLibrary(token);
          possede = bibliotheque.any(
            (item) =>
                item.livreId == livre.id ||
                (item.livre != null && item.livre!.id == livre.id),
          );
        } catch (_) {
          // Bibliothèque indisponible : on affiche la fiche en mode non possédé
          // plutôt que de bloquer l'ouverture du lien.
        }
      }

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => BookDetailPage(book: livre, isOwned: possede),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      // Toute panne était annoncée « Ce livre n'est plus disponible » — une
      // affirmation fausse sur le canal qui amène les nouveaux lecteurs. Seul
      // le 404 du serveur (« Livre not found », ou repli « introuvable ») dit
      // que l'ouvrage a disparu ; le reste — réseau coupé, serveur muet — est
      // une panne qui ne dit rien du livre, et qui se réessaie.
      final texte = e.toString().toLowerCase();
      final introuvable =
          texte.contains('not found') || texte.contains('introuvable');
      setState(() {
        if (introuvable) {
          _erreur = "Ce livre n'est plus disponible.";
          _estUnePanne = false;
        } else {
          _erreur = messageLisible(
            e,
            repli: "Le livre n'a pas pu être chargé.",
          );
          _estUnePanne = true;
        }
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
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: Center(
        child: _erreur == null
            ? CircularProgressIndicator(color: AppColors.accentInk)
            : Padding(
                padding: const EdgeInsets.all(AppDimensions.screenPadding),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      // Deux échecs, deux icônes : une panne se dit avec le
                      // réseau, un retrait du catalogue avec le livre.
                      _estUnePanne
                          ? Icons.wifi_off_rounded
                          : Icons.menu_book_outlined,
                      size: 48,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(height: AppDimensions.spaceLg),
                    Text(
                      _erreur!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    // Une panne n'est pas définitive : on offre la relance,
                    // ce qu'un « livre disparu » n'aurait pas de sens à faire.
                    if (_estUnePanne) ...[
                      const SizedBox(height: AppDimensions.spaceLg),
                      OutlinedButton.icon(
                        onPressed: _reessayer,
                        icon: Icon(
                          Icons.refresh,
                          size: 18,
                          color: AppColors.textPrimary,
                        ),
                        label: Text(
                          "Réessayer",
                          style: GoogleFonts.poppins(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: AppColors.textPrimary.withValues(
                              alpha: 0.2,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}
