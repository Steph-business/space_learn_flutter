import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';

import 'package:space_learn_flutter/core/space_learn/data/model/evenementModel.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/communaute/carte_evenement.dart';
import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/themes/app_dimensions.dart';

/// La liste complète des annonces et des événements.
///
/// La page communauté les déroulait toutes, les unes sous les autres : avec
/// une dizaine de publications, il fallait faire défiler longtemps avant
/// d'atteindre les clubs de lecture, qui sont pourtant l'essentiel de la page.
/// Elle n'en montre plus que quelques-unes et renvoie ici pour le reste.
///
/// Le tri est ici et non dans l'appelant : deux pages qui trient différemment
/// la même liste donnent deux ordres pour un même contenu.
class EvenementsPage extends StatefulWidget {
  const EvenementsPage({
    super.key,
    required this.evenements,
    required this.onOuvrir,
    this.titre = "Annonces & Événements",
    this.signature,
  });

  final List<Evenement> evenements;

  /// Ce qui se passe à l'ouverture d'une publication.
  ///
  /// Le lecteur la voit en feuille, l'auteur ouvre la page où se trouvent ses
  /// boutons de modification : la page ne décide pas, elle relaie.
  final void Function(BuildContext context, Evenement evenement) onOuvrir;

  final String titre;
  final String? signature;

  @override
  State<EvenementsPage> createState() => _EvenementsPageState();
}

class _EvenementsPageState extends State<EvenementsPage> {
  /// Filtre courant : tout, les annonces, ou les événements.
  String _filtre = _tout;

  static const String _tout = 'Tout';
  static const String _annonces = 'Annonces';
  static const String _evenements = 'Événements';

  bool _estAnnonce(Evenement e) =>
      e.typePublication.toLowerCase().trim() == 'annonce';

  List<Evenement> get _liste {
    final retenues = switch (_filtre) {
      _annonces => widget.evenements.where(_estAnnonce),
      _evenements => widget.evenements.where((e) => !_estAnnonce(e)),
      _ => widget.evenements,
    }.toList();

    // Les plus récentes d'abord. Une publication sans date passe après celles
    // qui en portent une, plutôt que de remonter en tête par accident.
    retenues.sort((a, b) {
      final da = a.dateEvenement;
      final db = b.dateEvenement;
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return db.compareTo(da);
    });
    return retenues;
  }

  @override
  Widget build(BuildContext context) {
    AppColors.suivreLeTheme(context);
    final liste = _liste;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.scaffoldBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Iconsax.arrow_left_2, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.titre,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _filtres(),
          Expanded(child: liste.isEmpty ? _vide() : _listeGroupee(liste)),
        ],
      ),
    );
  }

  /// La liste, rangee par familles et annoncee comme telle.
  ///
  /// L'ordre venait du serveur — a venir, puis actualites, puis passe — mais
  /// rien ne le disait : on voyait defiler une annonce de juillet, une dedicace
  /// d'aout, une dedicace de juillet, sans comprendre ce qui les rangeait
  /// ainsi. Un ordre qu'on ne peut pas nommer ressemble a un desordre.
  ///
  /// Les titres ne trient rien : ils NOMMENT le tri que le serveur a deja fait.
  /// Regrouper ici sans toucher a l'ordre garantit que les deux ne peuvent pas
  /// diverger.
  Widget _listeGroupee(List<Evenement> liste) {
    final aVenir = liste
        .where((e) => e.dateEvenement != null && !e.passe)
        .toList();
    final annonces = liste.where((e) => e.dateEvenement == null).toList();
    final passes = liste
        .where((e) => e.dateEvenement != null && e.passe)
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        ..._section("À venir", aVenir),
        ..._section("Actualités", annonces),
        ..._section("Déjà passés", passes),
      ],
    );
  }

  /// Un titre et ses cartes. Une famille vide ne laisse aucune trace : un titre
  /// seul au-dessus du vide fait croire a un chargement qui n'aboutit pas.
  List<Widget> _section(String titre, List<Evenement> membres) {
    if (membres.isEmpty) return const [];

    return [
      Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 10),
        child: Text(
          "$titre (${membres.length})",
          style: GoogleFonts.poppins(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
      ),
      for (var i = 0; i < membres.length; i++)
        Padding(
          padding: EdgeInsets.only(bottom: i == membres.length - 1 ? 8 : 12),
          child: CarteEvenement(
            evenement: membres[i],
            signature: widget.signature,
            onTap: () => widget.onOuvrir(context, membres[i]),
          ),
        ),
    ];
  }

  Widget _filtres() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Row(
        children: [_tout, _annonces, _evenements].map((f) {
          final choisi = f == _filtre;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _filtre = f),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: choisi ? AppColors.primary : AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                  border: Border.all(
                    color: choisi ? AppColors.primary : AppColors.border,
                  ),
                ),
                child: Text(
                  f,
                  style: GoogleFonts.poppins(
                    color: choisi
                        ? AppColors.onAccent
                        : AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _vide() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Text(
          _filtre == _annonces
              ? "Aucune annonce pour l'instant."
              : _filtre == _evenements
              ? "Aucun événement pour l'instant."
              : "Rien à afficher pour l'instant.",
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}
