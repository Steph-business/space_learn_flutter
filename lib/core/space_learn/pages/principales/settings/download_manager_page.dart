import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:space_learn_flutter/core/services/book_cache_service.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/libraryService.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/library_model.dart';
import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/themes/app_dimensions.dart';
import 'package:space_learn_flutter/core/utils/app_notifications.dart';
import 'package:space_learn_flutter/core/utils/token_storage.dart';

/// Les livres réellement présents sur l'appareil.
///
/// Cet écran affichait trois titres écrits en dur — « L'Énigme du Cosmos »,
/// « Physique Quantique 101 », et un ouvrage signé « Albert E. » — que personne
/// n'avait jamais téléchargés. Le bouton de suppression retirait la ligne d'une
/// liste en mémoire et annonçait « Livre supprimé de l'appareil » : rien n'était
/// effacé, et l'espace annoncé comme libéré ne l'était pas.
///
/// La liste vient maintenant du cache lui-même, et les titres de la
/// bibliothèque du lecteur — le nom du fichier ne porte que l'identifiant.
class DownloadManagerPage extends StatefulWidget {
  const DownloadManagerPage({super.key});

  @override
  State<DownloadManagerPage> createState() => _DownloadManagerPageState();
}

class _DownloadManagerPageState extends State<DownloadManagerPage> {
  final BookCacheService _cache = BookCacheService();
  final LibraryService _bibliotheque = LibraryService();

  List<LivreEnCache> _fichiers = const [];
  Map<String, LibraryModel> _parLivreId = const {};
  bool _chargement = true;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });

    // Le cache d'abord : il est local, il répond toujours, et c'est lui qui
    // fait foi sur ce qui occupe l'appareil.
    final fichiers = await _cache.listerCache();

    // Les titres ensuite. Sans réseau, on affiche quand même les fichiers —
    // gérer son espace de stockage ne doit pas exiger une connexion.
    var index = <String, LibraryModel>{};
    try {
      final token = await TokenStorage.getToken();
      if (token != null && token.isNotEmpty) {
        final livres = await _bibliotheque.getUserLibrary(token);
        index = {for (final l in livres) l.livreId: l};
      }
    } catch (e) {
      _erreur = "Titres indisponibles hors connexion.";
    }

    if (!mounted) return;
    setState(() {
      _fichiers = fichiers;
      _parLivreId = index;
      _chargement = false;
    });
  }

  Future<void> _supprimer(LivreEnCache entree) async {
    final titre = _titreDe(entree);
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        AppColors.suivreLeTheme(ctx);
        return AlertDialog(
          backgroundColor: AppColors.cardBackground,
          title: Text(
            "Supprimer de l'appareil ?",
            style: GoogleFonts.poppins(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            "« $titre » sera retiré de cet appareil et libérera "
            "${entree.taille}. Il reste dans votre bibliothèque et pourra être "
            "téléchargé à nouveau.",
            style: GoogleFonts.poppins(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                "Annuler",
                style: GoogleFonts.poppins(color: AppColors.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                "Supprimer",
                style: GoogleFonts.poppins(
                  color: AppColors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirme != true) return;

    final efface = await _cache.supprimerParChemin(entree.chemin);
    if (!mounted) return;

    // Le message dit ce qui s'est passé, pas ce qu'on espérait.
    AppNotifications.showSnackBar(
      context,
      message: efface
          ? "« $titre » supprimé de l'appareil."
          : "Suppression impossible : le fichier est introuvable.",
      isSuccess: efface,
      isError: !efface,
    );
    await _charger();
  }

  String _titreDe(LivreEnCache entree) {
    final connu = _parLivreId[entree.livreId];
    final titre = connu?.livre?.titre;
    if (titre != null && titre.trim().isNotEmpty) return titre;
    // Un fichier sans titre connu reste affiché : il occupe de la place, et
    // c'est justement ce qu'on vient gérer ici.
    return "Livre téléchargé";
  }

  String? _auteurDe(LivreEnCache entree) {
    final connu = _parLivreId[entree.livreId];
    final nom = connu?.auteurNom ?? connu?.livre?.auteur?.nomComplet;
    return (nom != null && nom.trim().isNotEmpty) ? nom : null;
  }

  int get _totalOctets =>
      _fichiers.fold(0, (somme, f) => somme + f.octets);

  String get _totalLisible {
    final o = _totalOctets;
    if (o >= 1024 * 1024) return '${(o / (1024 * 1024)).toStringAsFixed(1)} Mo';
    if (o >= 1024) return '${(o / 1024).toStringAsFixed(0)} Ko';
    return '$o octets';
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
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          "Téléchargements",
          style: GoogleFonts.poppins(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _charger,
        color: AppColors.accentInk,
        backgroundColor: AppColors.cardBackground,
        child: _chargement
            ? Center(
                child: CircularProgressIndicator(color: AppColors.accentInk),
              )
            : _fichiers.isEmpty
            ? _vide()
            : _liste(),
      ),
    );
  }

  Widget _vide() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.22),
        Icon(
          Icons.cloud_download_outlined,
          size: 56,
          color: AppColors.textHint,
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            "Aucun livre sur cet appareil",
            style: GoogleFonts.poppins(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Text(
            "Un livre ouvert depuis votre bibliothèque est conservé ici, "
            "et reste lisible sans connexion.",
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _liste() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _fichiers.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) return _entete();

        final entree = _fichiers[index - 1];
        final auteur = _auteurDe(entree);
        final estEpub = entree.chemin.toLowerCase().endsWith('.epub');

        return Card(
          color: AppColors.cardBackground,
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusInner),
            side: BorderSide(
              color: AppColors.textHint.withValues(alpha: 0.2),
            ),
          ),
          child: ListTile(
            leading: Icon(
              estEpub ? Icons.menu_book_rounded : Icons.picture_as_pdf,
              color: AppColors.accentInk,
              size: 32,
            ),
            title: Text(
              _titreDe(entree),
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              auteur != null ? "$auteur • ${entree.taille}" : entree.taille,
              style: GoogleFonts.poppins(
                color: AppColors.textSecondary,
                fontSize: 12.5,
              ),
            ),
            trailing: IconButton(
              tooltip: "Supprimer de l'appareil",
              icon: Icon(Icons.delete_outline, color: AppColors.error),
              onPressed: () => _supprimer(entree),
            ),
          ),
        );
      },
    );
  }

  Widget _entete() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "${_fichiers.length} livre${_fichiers.length > 1 ? 's' : ''} "
            "· $_totalLisible",
            style: GoogleFonts.poppins(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Ces livres restent lisibles sans connexion. Les supprimer ne les "
            "retire pas de votre bibliothèque.",
            style: GoogleFonts.poppins(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          if (_erreur != null) ...[
            const SizedBox(height: 8),
            Text(
              _erreur!,
              style: GoogleFonts.poppins(
                color: AppColors.textHint,
                fontSize: 11.5,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
