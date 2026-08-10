import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:space_learn_flutter/core/space_learn/data/dataServices/bookService.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/libraryService.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/book_model.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/details/book_detail_page.dart';
import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/themes/app_dimensions.dart';
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

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    try {
      final token = await TokenStorage.getToken();
      final BookModel livre =
          await _bookService.getBookById(widget.livreId, authToken: token);

      // Savoir si le lecteur possède déjà le livre change ce que la fiche
      // propose : lire, ou acheter.
      bool possede = false;
      if (token != null) {
        try {
          final bibliotheque = await _libraryService.getUserLibrary(token);
          possede = bibliotheque.any((item) =>
              item.livreId == livre.id ||
              (item.livre != null && item.livre!.id == livre.id));
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
      setState(() => _erreur = "Ce livre n'est plus disponible.");
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    Icon(Icons.menu_book_outlined,
                        size: 48, color: AppColors.textSecondary),
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
                  ],
                ),
              ),
      ),
    );
  }
}
