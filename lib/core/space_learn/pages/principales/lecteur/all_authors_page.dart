import 'dart:async';

import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import 'package:space_learn_flutter/core/space_learn/data/dataServices/auteurService.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/relationService.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/user_model.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/details/author_profile_page.dart';
import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/themes/app_dimensions.dart';
import 'package:space_learn_flutter/core/themes/app_text_styles.dart';
import 'package:space_learn_flutter/core/utils/app_notifications.dart';
import 'package:space_learn_flutter/core/utils/message_erreur.dart';
import 'package:space_learn_flutter/core/utils/profile_image_helper.dart';
import 'package:space_learn_flutter/core/utils/token_storage.dart';

/// L'annuaire des auteurs.
///
/// Cet écran déduisait les auteurs des livres qu'il chargeait — deux cents au
/// plus. Trois défauts en découlaient, tous visibles :
///
///   - le décompte sous chaque nom ne comptait que les livres reçus. Un auteur
///     prolifique en affichait moins qu'il n'en a, et un auteur dont aucun
///     livre n'était dans la page portait « 0 livre publié » ;
///   - la liste ne pouvait pas être paginée : on ne pagine pas une liste
///     dérivée d'une autre. Voir l'auteur suivant demandait de charger les
///     livres suivants ;
///   - il fallait rapatrier tous les abonnements du lecteur pour savoir
///     lesquels étaient suivis.
///
/// Le serveur répond maintenant à ces trois questions (`GET /api/authors`).
class AllAuthorsPage extends StatefulWidget {
  const AllAuthorsPage({super.key});

  @override
  State<AllAuthorsPage> createState() => _AllAuthorsPageState();
}

class _AllAuthorsPageState extends State<AllAuthorsPage> {
  final AuteurService _auteurService = AuteurService();
  final RelationService _relationService = RelationService();

  final List<AuteurResume> _auteurs = [];
  bool _chargement = true;
  bool _chargeLaSuite = false;
  bool _finDeListe = false;
  String? _erreur;
  int _page = 1;

  final ScrollController _defilement = ScrollController();
  final TextEditingController _recherche = TextEditingController();
  Timer? _attenteSaisie;
  String _terme = '';

  @override
  void initState() {
    super.initState();
    _defilement.addListener(_auDefilement);
    _charger();
  }

  @override
  void dispose() {
    _attenteSaisie?.cancel();
    _defilement.removeListener(_auDefilement);
    _defilement.dispose();
    _recherche.dispose();
    super.dispose();
  }

  /// Demande la suite avant d'atteindre le bas : le temps que la page arrive,
  /// le lecteur y est.
  void _auDefilement() {
    if (!_defilement.hasClients) return;
    final reste =
        _defilement.position.maxScrollExtent - _defilement.position.pixels;
    if (reste < 500) _chargerLaSuite();
  }

  Future<void> _charger() async {
    setState(() {
      _chargement = true;
      _erreur = null;
      _page = 1;
      _finDeListe = false;
    });

    try {
      final token = await TokenStorage.getToken();
      final premiers = await _auteurService.getAuteurs(
        page: 1,
        recherche: _terme,
        authToken: token,
      );

      if (!mounted) return;
      setState(() {
        _auteurs
          ..clear()
          ..addAll(premiers);
        _finDeListe = premiers.length < AuteurService.taillePage;
        _chargement = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erreur = messageLisible(
          e,
          repli: "Les auteurs n'ont pas pu être chargés.",
        );
        _chargement = false;
      });
    }
  }

  /// La page suivante, ajoutée à la suite.
  ///
  /// Un échec n'efface pas ce qui est déjà affiché : le lecteur garde sa
  /// liste, et le prochain défilement retentera.
  Future<void> _chargerLaSuite() async {
    if (_chargeLaSuite || _finDeListe || _chargement) return;
    setState(() => _chargeLaSuite = true);

    try {
      final token = await TokenStorage.getToken();
      final suite = await _auteurService.getAuteurs(
        page: _page + 1,
        recherche: _terme,
        authToken: token,
      );

      if (!mounted) return;
      setState(() {
        _page += 1;
        _auteurs.addAll(suite);
        // Page incomplète : il n'y a plus rien derrière. La réponse ne porte
        // pas de compteur total, c'est le seul signal de fin disponible.
        _finDeListe = suite.length < AuteurService.taillePage;
        _chargeLaSuite = false;
      });
    } catch (_) {
      if (mounted) setState(() => _chargeLaSuite = false);
    }
  }

  void _surRecherche(String valeur) {
    _attenteSaisie?.cancel();
    _terme = valeur.trim();
    // Une pause avant d'interroger le serveur : sans elle, « traoré »
    // déclenche six recherches, dont cinq sont périmées avant d'arriver.
    _attenteSaisie = Timer(const Duration(milliseconds: 400), () {
      if (mounted) _charger();
    });
  }

  void _ouvrir(AuteurResume auteur) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AuthorProfilePage(
          author: UserModel(
            id: auteur.id,
            profilId: auteur.id,
            email: '',
            nomComplet: auteur.nomComplet,
            profilePhoto: auteur.photo,
            biography: auteur.biographie,
            isProfileComplete: false,
          ),
          initialIsFollowing: auteur.estSuivi,
        ),
      ),
    );
  }

  Future<void> _basculerAbonnement(int index) async {
    final token = await TokenStorage.getToken();
    if (token == null) return;

    final auteur = _auteurs[index];
    final suivait = auteur.estSuivi;

    setState(() => _auteurs[index] = auteur.copyWith(estSuivi: !suivait));

    try {
      if (suivait) {
        await _relationService.unfollowUser(auteur.id, token);
      } else {
        await _relationService.followUser(auteur.id, token);
      }
    } catch (e) {
      if (!mounted) return;
      // L'état revient à ce qu'il était : afficher « Suivi » alors que le
      // serveur n'en sait rien ferait croire à un abonnement qui n'existe pas.
      setState(() => _auteurs[index] = auteur.copyWith(estSuivi: suivait));
      AppNotifications.showSnackBar(
        context,
        message: messageLisible(e, repli: "Action impossible pour le moment."),
        isError: true,
      );
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
        title: Text("Tous les auteurs", style: AppTextStyles.sectionTitle),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _charger,
        color: AppColors.accentInk,
        backgroundColor: AppColors.cardBackground,
        child: _corps(),
      ),
    );
  }

  Widget _corps() {
    if (_chargement) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.accentInk),
      );
    }

    if (_erreur != null) {
      return _etatVide(
        icone: Iconsax.warning_2,
        titre: "Chargement impossible",
        detail: _erreur!,
        action: "Réessayer",
        surAction: _charger,
      );
    }

    // Aucun auteur ET aucune recherche en cours : l'annuaire est vide.
    if (_auteurs.isEmpty && _terme.isEmpty) {
      return _etatVide(
        icone: Iconsax.user_search,
        titre: "Aucun auteur pour l'instant",
        detail: "Les auteurs apparaissent ici dès qu'un livre est publié.",
      );
    }

    return ListView.builder(
      controller: _defilement,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.screenPadding,
        AppDimensions.spaceSm,
        AppDimensions.screenPadding,
        AppDimensions.spaceXl,
      ),
      // En-tête, puis les auteurs, puis le pied (chargement, fin de liste, ou
      // absence de résultat).
      itemCount: _auteurs.length + 2,
      itemBuilder: (context, index) {
        if (index == 0) return _entete();
        if (index <= _auteurs.length) return _carte(index - 1);
        return _pied();
      },
    );
  }

  Widget _entete() {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Suivez un auteur pour être prévenu de ses nouveautés.",
            style: AppTextStyles.grey12,
          ),
          const SizedBox(height: AppDimensions.spaceMd),
          TextField(
            controller: _recherche,
            onChanged: _surRecherche,
            style: AppTextStyles.body13,
            decoration: InputDecoration(
              hintText: "Rechercher un auteur",
              hintStyle: AppTextStyles.grey12,
              prefixIcon: Icon(
                Iconsax.search_normal_1,
                size: 18,
                color: AppColors.textHint,
              ),
              suffixIcon: _terme.isEmpty
                  ? null
                  : IconButton(
                      icon: Icon(
                        Iconsax.close_circle,
                        size: 18,
                        color: AppColors.textHint,
                      ),
                      onPressed: () {
                        _recherche.clear();
                        _terme = '';
                        _charger();
                      },
                    ),
              filled: true,
              fillColor: AppColors.cardBackground,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: _contour(AppColors.textHint.withValues(alpha: 0.2)),
              enabledBorder: _contour(
                AppColors.textHint.withValues(alpha: 0.2),
              ),
              focusedBorder: _contour(AppColors.accentInk),
            ),
          ),
        ],
      ),
    );
  }

  OutlineInputBorder _contour(Color couleur) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppDimensions.radiusInner),
    borderSide: BorderSide(color: couleur),
  );

  Widget _pied() {
    if (_chargeLaSuite) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: SizedBox(
            height: 22,
            width: 22,
            child: CircularProgressIndicator(strokeWidth: 2.2),
          ),
        ),
      );
    }

    if (_auteurs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            Icon(Iconsax.search_normal_1, size: 36, color: AppColors.textHint),
            const SizedBox(height: AppDimensions.spaceMd),
            Text(
              "Aucun auteur ne correspond à « $_terme ».",
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySecondary,
            ),
          ],
        ),
      );
    }

    // Le dire évite de continuer à défiler en espérant qu'il en vienne
    // d'autres. Inutile quand tout tient sur une page.
    if (_finDeListe && _auteurs.length > AuteurService.taillePage) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            "Vous avez vu tous les auteurs.",
            style: AppTextStyles.grey12,
          ),
        ),
      );
    }

    return const SizedBox(height: 8);
  }

  Widget _carte(int index) {
    final auteur = _auteurs[index];

    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.spaceMd),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(color: AppColors.textHint.withValues(alpha: 0.18)),
      ),
      // La carte entière ouvre le profil. Deux zones tactiles séparées
      // laissaient un couloir mort entre l'avatar et le nom : on appuyait sur
      // la carte et il ne se passait rien.
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _ouvrir(auteur),
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.spaceMd),
            child: Row(
              children: [
                _avatar(auteur),
                const SizedBox(width: AppDimensions.spaceMd),
                Expanded(child: _identite(auteur)),
                const SizedBox(width: AppDimensions.spaceSm),
                _boutonSuivre(index, auteur.estSuivi),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _avatar(AuteurResume auteur) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surfaceVariant,
      ),
      clipBehavior: Clip.antiAlias,
      child: ProfileImageHelper.buildProfileImage(
        auteur.photo,
        fallbackInitial: auteur.initiale,
        textStyle: AppTextStyles.subtitleBold.copyWith(
          color: AppColors.accentInk,
        ),
        width: 52,
        height: 52,
      ),
    );
  }

  Widget _identite(AuteurResume auteur) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          auteur.nomComplet.isEmpty ? "Auteur" : auteur.nomComplet,
          style: AppTextStyles.subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(Iconsax.book_1, size: 13, color: AppColors.textHint),
            const SizedBox(width: 4),
            Text(
              "${auteur.nombreLivres} livre${auteur.nombreLivres > 1 ? 's' : ''}",
              style: AppTextStyles.grey12,
            ),
            if (auteur.specialite != null) ...[
              const SizedBox(width: AppDimensions.spaceSm),
              // Une étiquette, et non la suite de la phrase : elle se rétrécit
              // toute seule quand le nom est long, au lieu de couper la ligne
              // entière par des points de suspension.
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accentInk.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusPill,
                    ),
                  ),
                  child: Text(
                    auteur.specialite!,
                    style: AppTextStyles.body11.copyWith(
                      color: AppColors.accentInk,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _boutonSuivre(int index, bool suivi) {
    return SizedBox(
      height: 36,
      child: suivi
          ? OutlinedButton.icon(
              onPressed: () => _basculerAbonnement(index),
              icon: const Icon(Iconsax.tick_circle, size: 15),
              label: const Text("Suivi"),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                textStyle: AppTextStyles.cardTitle12SemiBold,
                side: BorderSide(
                  color: AppColors.textHint.withValues(alpha: 0.35),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                ),
              ),
            )
          : ElevatedButton(
              onPressed: () => _basculerAbonnement(index),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                // Le libellé prenait `textPrimary`, qui passe au blanc en thème
                // sombre : du blanc sur l'orange de la marque. `onAccent` est
                // la couleur prévue pour écrire sur cet aplat.
                foregroundColor: AppColors.onAccent,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                textStyle: AppTextStyles.cardTitle12SemiBold,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                ),
              ),
              child: const Text("Suivre"),
            ),
    );
  }

  Widget _etatVide({
    required IconData icone,
    required String titre,
    required String detail,
    String? action,
    VoidCallback? surAction,
  }) {
    // Une liste défilante, et non une colonne centrée : sans elle, le geste de
    // tirer pour rafraîchir ne prend pas sur un écran qui ne défile pas — donc
    // précisément dans le cas où l'on veut réessayer.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(40, 120, 40, 40),
      children: [
        Icon(icone, size: 44, color: AppColors.textHint),
        const SizedBox(height: AppDimensions.spaceLg),
        Text(titre, textAlign: TextAlign.center, style: AppTextStyles.subtitle),
        const SizedBox(height: AppDimensions.spaceSm),
        Text(
          detail,
          textAlign: TextAlign.center,
          style: AppTextStyles.bodySecondary,
        ),
        if (action != null && surAction != null) ...[
          const SizedBox(height: AppDimensions.spaceXl),
          Center(
            child: ElevatedButton(
              onPressed: surAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onAccent,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                ),
              ),
              child: Text(action),
            ),
          ),
        ],
      ],
    );
  }
}
