import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/themes/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:space_learn_flutter/core/themes/app_dimensions.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/authorStatsService.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/authorRevenueModel.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/book_model.dart';
import 'package:space_learn_flutter/core/utils/message_erreur.dart';

/// Les chiffres d'un livre — ceux que le serveur donne, et rien d'autre.
///
/// Cette page affichait deux inventions présentées comme des mesures :
///
///  * « Revenus (Estimés) » valait `telechargements × prix`. Ce n'était pas une
///    approximation : les téléchargements ne sont pas des ventes confirmées —
///    la règle du serveur est `statut = confirmé`, précisément instaurée parce
///    que ce calcul mentait —, un livre passé gratuit un temps gonflait le
///    chiffre sans limite, et la commission n'était jamais déduite. L'auteur
///    comparait ce montant à son portefeuille, alimenté par le vrai registre,
///    et en concluait qu'on lui devait de l'argent.
///  * « Évolution (30 derniers jours) » traçait quatre points ÉCRITS EN DUR —
///    20, 40, 25, 80 — identiques pour tous les livres, tous les auteurs, à
///    tout moment.
///
/// Le montant vient désormais de `GET /api/authors/:authorId/revenue`, dont la
/// ventilation `revenue_by_book` porte le total encaissé livre par livre. La
/// courbe par livre, elle, n'existe dans aucun contrat : le serveur ne découpe
/// les revenus par jour que pour l'ENSEMBLE des ouvrages d'un auteur. On le dit
/// au lieu d'en dessiner une.
class StatistiquesLivrePage extends StatefulWidget {
  final BookModel book;

  const StatistiquesLivrePage({super.key, required this.book});

  @override
  State<StatistiquesLivrePage> createState() => _StatistiquesLivrePageState();
}

class _StatistiquesLivrePageState extends State<StatistiquesLivrePage> {
  final AuthorStatsService _statsService = AuthorStatsService();

  bool _chargement = true;

  /// Ce qui a empêché le montant d'arriver, s'il y a lieu.
  String? _echec;

  /// Le montant encaissé pour CE livre, en francs. Nul tant qu'on ne l'a pas.
  double? _encaisse;

  BookModel get book => widget.book;

  @override
  void initState() {
    super.initState();
    _chargerRevenus();
  }

  Future<void> _chargerRevenus() async {
    if (!mounted) return;
    setState(() {
      _chargement = true;
      _echec = null;
    });

    try {
      if (book.auteurId.isEmpty) {
        throw Exception("L'auteur de ce livre n'a pas pu être identifié.");
      }

      final donnees = await _statsService.getAuthorRevenue(book.auteurId, "");
      final revenus = AuthorRevenueModel.fromJson(donnees);

      // Un livre absent de la ventilation n'a AUCUNE vente confirmée : le
      // serveur ne groupe que les paiements confirmés. Zéro est donc ici une
      // réponse, pas un trou — à la différence d'un appel qui échoue.
      double montant = 0;
      for (final ligne in revenus.revenueByBook) {
        if (ligne.livreId == book.id) {
          montant = ligne.montant;
          break;
        }
      }

      if (!mounted) return;
      setState(() {
        _encaisse = montant;
        _chargement = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _echec = messageLisible(
          e,
          repli: "Les revenus de ce livre n'ont pas pu être chargés.",
        );
        _chargement = false;
      });
    }
  }

  /// Un montant avec ses milliers séparés : 89876 se lit mal, 89 876 se lit.
  static String _enFrancs(num montant) {
    final entier = montant.round().toString();
    final tampon = StringBuffer();
    for (var i = 0; i < entier.length; i++) {
      if (i > 0 && (entier.length - i) % 3 == 0) tampon.write(' ');
      tampon.write(entier[i]);
    }
    return tampon.toString();
  }

  @override
  Widget build(BuildContext context) {
    AppColors.suivreLeTheme(context);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "Statistiques : ${book.titre}",
          style: AppTextStyles.subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            color: AppColors.textPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _chargerRevenus,
        color: AppColors.secondaryVariant,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Couverture et Info de base
              Row(
                children: [
                  Container(
                    width: 80,
                    height: 120,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusInner,
                      ),
                    ),
                    child:
                        book.imageCouverture != null &&
                            book.imageCouverture!.isNotEmpty &&
                            !book.imageCouverture!.contains('example.com')
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(
                              AppDimensions.radiusInner,
                            ),
                            child: Image.network(
                              book.imageCouverture!,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Container(
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(
                                AppDimensions.radiusInner,
                              ),
                            ),
                            child: Icon(
                              Icons.book,
                              color: AppColors.textHint,
                              size: 40,
                            ),
                          ),
                  ),
                  SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          book.titre,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: book.statut == 'publie'
                                ? Colors.green.withValues(alpha: 0.2)
                                : Colors.orange.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(
                              AppDimensions.radiusCard,
                            ),
                          ),
                          child: Text(
                            book.statut == 'publie' ? "En ligne" : book.statut,
                            style: TextStyle(
                              color: book.statut == 'publie'
                                  ? Colors.greenAccent
                                  : Colors.orangeAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          "Prix : ${_enFrancs(book.prix)} FCFA",
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 30),

              // KPIs
              //
              // « Téléchargements » affichait `book.telechargements`, que le
              // modèle remplissait avec le nombre d'AVIS : le compteur ne
              // parlait pas de ce que son étiquette annonçait. Le serveur
              // n'envoie aucun compteur de lectures pour un livre ; on montre
              // donc les avis sous leur nom, et la note qui va avec.
              Row(
                children: [
                  Expanded(
                    child: _buildKpiCard(
                      title: "Avis",
                      value: "${book.nombreAvis}",
                      icon: Icons.rate_review_outlined,
                      color: AppColors.secondaryVariant,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: _buildKpiCard(
                      title: "Note",
                      value: book.nombreAvis > 0
                          ? "${book.noteMoyenne.toStringAsFixed(1)}/5"
                          : "—",
                      precision: book.nombreAvis > 0
                          ? null
                          : "Aucun avis pour l'instant",
                      icon: Icons.star_rounded,
                      color: AppColors.warning,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              _carteEncaisse(),
              SizedBox(height: 30),

              Text("Évolution", style: AppTextStyles.subtitle),
              SizedBox(height: 16),
              _absenceDeCourbe(),
            ],
          ),
        ),
      ),
    );
  }

  /// Le montant réellement encaissé pour ce livre — ou la panne, dite.
  Widget _carteEncaisse() {
    if (_chargement) {
      return _carteInfo(
        icone: Icons.account_balance_wallet_rounded,
        couleur: AppColors.success,
        titre: "Ventes encaissées",
        contenu: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text("Lecture en cours…", style: AppTextStyles.greyMedium14),
          ],
        ),
      );
    }

    if (_echec != null) {
      // Une panne n'est pas un revenu nul : afficher « 0 FCFA » ici ferait
      // croire à l'auteur qu'il n'a rien vendu.
      return _carteInfo(
        icone: Icons.error_outline_rounded,
        couleur: AppColors.error,
        titre: "Ventes encaissées",
        contenu: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_echec!, style: AppTextStyles.greyMedium14),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _chargerRevenus,
                child: const Text("Réessayer"),
              ),
            ),
          ],
        ),
      );
    }

    return _carteInfo(
      icone: Icons.account_balance_wallet_rounded,
      couleur: AppColors.success,
      titre: "Ventes encaissées",
      contenu: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "${_enFrancs(_encaisse ?? 0)} FCFA",
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          // La distinction se dit, sinon l'auteur compare ce montant à son
          // portefeuille — qui affiche le NET — et croit à un manque.
          Text(
            "Total payé par vos lecteurs pour ce livre, ventes confirmées "
            "uniquement. Votre part, commission déduite, figure dans votre "
            "portefeuille.",
            style: AppTextStyles.greyMedium12,
          ),
        ],
      ),
    );
  }

  /// Dire qu'une donnée n'existe pas vaut mieux que d'en dessiner une fausse.
  Widget _absenceDeCourbe() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(
          color: AppColors.textPrimary.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.show_chart_rounded, size: 20, color: AppColors.textHint),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "Le détail jour par jour n'est pas encore suivi livre par "
              "livre. L'évolution de vos revenus, tous ouvrages confondus, "
              "vous attend sur votre accueil d'auteur.",
              style: AppTextStyles.greyMedium14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    String? precision,
  }) {
    return _carteInfo(
      icone: icon,
      couleur: color,
      titre: title,
      contenu: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (precision != null) ...[
            const SizedBox(height: 4),
            Text(precision, style: AppTextStyles.greyMedium12),
          ],
        ],
      ),
    );
  }

  /// La carte commune à tous les indicateurs : un titre, une icône, un contenu.
  Widget _carteInfo({
    required IconData icone,
    required Color couleur,
    required String titre,
    required Widget contenu,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(
          color: AppColors.textPrimary.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  titre,
                  style: TextStyle(
                    color: AppColors.textPrimary.withValues(alpha: 0.5),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(icone, color: couleur, size: 18),
            ],
          ),
          SizedBox(height: 12),
          contenu,
        ],
      ),
    );
  }
}
