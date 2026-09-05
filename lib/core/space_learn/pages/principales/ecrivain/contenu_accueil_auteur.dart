import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/themes/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:space_learn_flutter/core/themes/app_dimensions.dart';

import 'package:space_learn_flutter/core/themes/layout/nav_bar_all.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/auteur/accueil/revenus.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/auteur/accueil/statistique.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/ecrivain/ajouter_livre_page.dart';

import 'package:space_learn_flutter/core/space_learn/pages/widgets/auteur/accueil/sections_dashboard.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/bookService.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/authorStatsService.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/relationService.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/book_model.dart';
import 'package:space_learn_flutter/core/utils/message_erreur.dart';
import 'package:space_learn_flutter/core/utils/token_storage.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/authServices.dart';

class HomeContentAuteur extends StatefulWidget {
  final String profileId;
  final String userName;

  const HomeContentAuteur({
    super.key,
    required this.profileId,
    required this.userName,
  });

  @override
  State<HomeContentAuteur> createState() => _HomeContentAuteurState();
}

class _HomeContentAuteurState extends State<HomeContentAuteur> {
  final BookService _bookService = BookService();
  final AuthorStatsService _authorStatsService = AuthorStatsService();
  final AuthService _authService = AuthService();
  final RelationService _relationService = RelationService();

  String? _authorId;
  List<BookModel> _books = [];
  List<dynamic> _followers = [];
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;

  /// Ce qui a empêché les statistiques d'arriver, s'il y a lieu.
  ///
  /// Sans lui, un appel refusé et un mois sans vente donnaient le même écran :
  /// des zéros. Le reste du tableau de bord — livres, abonnés — n'a pas à en
  /// souffrir, d'où un état séparé plutôt qu'une erreur pour toute la page.
  String? _echecStats;

  /// Ce qui a empêché TOUT le tableau de bord d'arriver.
  ///
  /// Le compte, les livres et les abonnés sont enchaînés : l'échec d'un seul
  /// laissait `_books` vide et `_stats` vide, et l'écran se peignait avec
  /// « MES GAINS 0 FCFA », « LECTEURS 0 », « Aucun livre publié » — des zéros
  /// présentés comme un résultat. Le bandeau _echecStats ne couvrait que
  /// l'appel des statistiques ; celui-ci couvre l'autre chemin d'échec.
  String? _echecGlobal;

  /// Vrai dès qu'un chargement complet a réussi au moins une fois.
  ///
  /// Un rafraîchissement raté ne doit pas effacer des données valides déjà à
  /// l'écran : dans ce cas on se contente du bandeau, et la page reste.
  bool _dejaCharge = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _echecGlobal = null;
    });
    try {
      final token = await TokenStorage.getToken();
      // Ces phrases sont écrites pour être LUES : « No token » passait le
      // filtre de messageLisible et s'affichait tel quel à l'auteur.
      if (token == null) {
        throw Exception("Votre session a expiré. Reconnectez-vous.");
      }
      final user = await _authService.getUser(token);
      if (user == null) {
        throw Exception("Votre compte n'a pas pu être chargé.");
      }

      final authorId = user.id;
      final books = await _bookService.getBooksByAuthorId(authorId);
      final followers = await _relationService.getFollowers(authorId);

      // Les statistiques à part : elles échouent seules, et leur échec ne doit
      // pas emporter les livres et les abonnés déjà obtenus. Enchaînées avec
      // le reste, une erreur ici vidait tout le tableau de bord.
      var stats = <String, dynamic>{};
      String? echecStats;
      try {
        stats = await _authorStatsService.getAuthorStats(authorId, "");
      } catch (e) {
        echecStats = messageLisible(
          e,
          repli: "Vos statistiques n'ont pas pu être chargées.",
        );
      }

      if (mounted) {
        setState(() {
          _authorId = authorId;
          _books = books;
          _stats = stats;
          _echecStats = echecStats;
          _followers = followers;
          _dejaCharge = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      // La panne se DIT. Elle se contentait de baisser le drapeau de
      // chargement : l'auteur voyait alors des gains à 0 FCFA et « Aucun livre
      // publié » là où il avait dix livres en vente.
      if (mounted) {
        setState(() {
          _echecGlobal = messageLisible(
            e,
            repli: "Votre tableau de bord n'a pas pu être chargé.",
          );
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    AppColors.suivreLeTheme(context);
    return Column(
      children: [
        NavBarAll(userName: widget.userName, role: 'auteur'),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadData,
            color: AppColors.secondaryVariant,
            // Rien n'a jamais pu être chargé : on montre la panne, pas des
            // zéros. Si des données valides sont déjà à l'écran, on garde la
            // page et le bandeau suffit.
            child: (_echecGlobal != null && !_dejaCharge)
                ? _etatEchecGlobal(_echecGlobal!)
                : SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 10),
                        if (_echecGlobal != null)
                          _bandeauEchecStats(_echecGlobal!),
                        if (_echecStats != null)
                          _bandeauEchecStats(_echecStats!),
                        // La même marge que tous les blocs du fil.
                        //
                        // Celui-ci était le seul à n'en recevoir aucune : ses deux
                        // cartes couraient jusqu'aux bords de l'écran, celle de
                        // droite s'y trouvait coupée, et le bloc entier paraissait
                        // décalé par rapport à tout ce qui le suivait.
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          child: Statistique(stats: _stats),
                        ),

                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          child: Revenus(stats: _stats, authorId: _authorId),
                        ),

                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          child: SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const AjouterLivrePage(),
                                  ),
                                );
                                if (result == true) _loadData();
                              },
                              icon: Icon(
                                Icons.add_circle,
                                color: AppColors.onAccent,
                                size: 24,
                              ),
                              label: Text(
                                "Publier un nouveau livre",
                                style: AppTextStyles.subtitle,
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.secondaryVariant,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppDimensions.radiusCard,
                                  ),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ),

                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          child: TopLivresSection(
                            books: _books,
                            isLoading: _isLoading,
                            onBookUpdated: _loadData,
                          ),
                        ),

                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          child: CommentairesRecentsSection(books: _books),
                        ),

                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          child: DerniersAbonnesSection(followers: _followers),
                        ),

                        SizedBox(height: 100),
                      ],
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  /// L'écran quand rien n'a pu être chargé.
  ///
  /// Défilable malgré son contenu court : c'est ce qui laisse le geste de
  /// rafraîchissement fonctionner ici comme sur le tableau de bord normal.
  Widget _etatEchecGlobal(String message) {
    return LayoutBuilder(
      builder: (context, contraintes) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: contraintes.maxHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.cloud_off_rounded,
                      size: 32,
                      color: AppColors.error,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.greyMedium14,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _loadData,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondaryVariant,
                      foregroundColor: AppColors.onAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusInner,
                        ),
                      ),
                    ),
                    child: const Text("Réessayer"),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Dit que les chiffres affichés en dessous ne sont pas les vrais.
  ///
  /// Placé au-dessus des statistiques et non à la place : les zéros restent
  /// visibles — les masquer laisserait un trou incompréhensible — mais plus
  /// personne ne peut les prendre pour un résultat.
  Widget _bandeauEchecStats(String message) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppDimensions.radiusInner),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline_rounded, size: 20, color: AppColors.error),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: AppTextStyles.greyMedium14)),
            TextButton(onPressed: _loadData, child: const Text("Réessayer")),
          ],
        ),
      ),
    );
  }
}
