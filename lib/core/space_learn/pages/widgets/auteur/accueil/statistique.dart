import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/themes/app_dimensions.dart';
import 'package:space_learn_flutter/core/themes/app_text_styles.dart';
import 'package:space_learn_flutter/core/themes/widgets/app_card.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:space_learn_flutter/core/utils/token_storage.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/authServices.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/ecrivain/abonnes_page.dart';

import 'package:space_learn_flutter/core/space_learn/data/dataServices/relationService.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/ecrivain/accueil_auteur_page.dart';

class Statistique extends StatefulWidget {
  final Map<String, dynamic> stats;
  const Statistique({super.key, required this.stats});

  @override
  State<Statistique> createState() => _StatistiqueState();
}

class _StatistiqueState extends State<Statistique> {
  final AuthService _authService = AuthService();
  final RelationService _relationService = RelationService();
  String? _authorId;
  int _followersCount = 0;

  /// Le nombre d'abonnés n'a pas pu être obtenu.
  ///
  /// Zéro et « on ne sait pas » ne sont pas la même chose, et cet écran les
  /// codait pareil : le compteur part à zéro, et une panne le laissait à zéro.
  /// L'auteur lisait donc « 0 » — sa carrière sans public — là où il n'y avait
  /// qu'un réseau coupé. L'écran jumeau, `author_profile_page`, distingue déjà
  /// les deux avec le même drapeau.
  bool _abonnesInconnus = false;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    try {
      final token = await TokenStorage.getToken();
      if (token != null) {
        final user = await _authService.getUser(token);
        if (user != null && mounted) {
          setState(() {
            _authorId = user.id;
          });
          _loadFollowers(user.id);
        }
      }
    } catch (e) {
      // Même règle qu'en dessous : un échec se dit au moins dans les journaux.
      debugPrint("Identité de l'auteur indisponible : $e");
    }
  }

  Future<void> _loadFollowers(String userId) async {
    try {
      // Le total du serveur (`meta.total`), et non la longueur de la tranche :
      // voir PageDeRelations. Le compteur est laissé tel quel quand le serveur
      // ne rend pas le total — mieux vaut ne rien changer que d'écrire un
      // chiffre qu'on ne tient de personne.
      final abonnes = await _relationService.getFollowers(userId);
      final total = abonnes.nombreConnu;
      if (!mounted) return;
      setState(() {
        if (total != null) _followersCount = total;
        // Le serveur a répondu sans donner le total : on ne sait toujours pas.
        _abonnesInconnus = total == null;
      });
    } catch (e) {
      // LE SILENCE COMPLET EST PARTI D'ICI. `catch (e) {}` n'affichait rien et
      // ne journalisait rien : le compteur restait à zéro, et rien — ni à
      // l'écran, ni dans les journaux — ne permettait de distinguer cet écran
      // d'un auteur réellement sans audience.
      debugPrint("Nombre d'abonnés indisponible : $e");
      if (!mounted) return;
      setState(() => _abonnesInconnus = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    AppColors.suivreLeTheme(context);
    // Extract values from stats map
    // Ce que l'auteur touche, et non ce que l'acheteur a payé.
    //
    // `total_revenue` est le chiffre d'affaires brut : la plateforme en retient
    // sa part, et l'auteur ne verra jamais ce montant-là. Son portefeuille lui
    // annonce le net, et les deux écrans se contredisaient donc.
    //
    // `net_revenue` est lu dans le registre des reversements — celui qui fait
    // foi pour le portefeuille. Repli sur le brut pour un serveur d'une
    // version antérieure : mieux vaut un chiffre trop généreux qu'un zéro.
    final double brut = (widget.stats['total_revenue'] ?? 0).toDouble();
    final double net = widget.stats['net_revenue'] != null
        ? (widget.stats['net_revenue'] as num).toDouble()
        : brut;

    // « — » plutôt qu'un zéro qu'on ne tient de personne : voir
    // [_abonnesInconnus]. Le chiffre des statistiques, quand le serveur le
    // rend, reste prioritaire — il vient de la même source, mais il est déjà là.
    final int? readersCount =
        widget.stats['total_followers'] ??
        (_abonnesInconnus ? null : _followersCount);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              // « MES GAINS » : le seul chiffre qui concerne l'auteur.
              //
              // L'écran annonçait « VENTES BRUT », c'est-à-dire ce que les
              // acheteurs ont payé, commission non déduite. Le libellé était
              // exact, mais le montant n'était pas le sien : son portefeuille
              // en affichait un autre, plus petit, et rien ne disait lequel
              // comptait. Une place de marché doit répondre à « combien
              // j'ai gagné », pas à « combien on a encaissé grâce à moi ».
              child: _buildStatCard(
                "MES GAINS",
                "${net.toStringAsFixed(0)} FCFA",
                "", // Removed fake growth
                Icons.account_balance_wallet_rounded,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  if (_authorId != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AbonnesPage(authorId: _authorId!),
                      ),
                    );
                  }
                },
                child: _buildStatCard(
                  "LECTEURS",
                  // Un tiret quand on ne sait pas : « 0 » serait une
                  // affirmation. Voir [_abonnesInconnus].
                  readersCount == null ? "—" : "$readersCount",
                  "", // Removed fake growth
                  Icons.people_alt_rounded,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        AppCard(
          onTap: () {
            HomePageAuteur.navKey.currentState?.setIndex(3);
          },
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.secondaryVariant.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.campaign_rounded,
                  color: AppColors.secondaryVariant,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppDimensions.spaceLg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "COMMUNAUTÉ",
                      style: GoogleFonts.poppins(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.1,
                      ),
                    ),
                    Text(
                      "Gérer mes annonces & évènements",
                      style: GoogleFonts.poppins(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: AppColors.textHint,
                size: 14,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    String growth,
    IconData icon,
  ) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.1,
                ),
              ),
              Icon(icon, color: AppColors.accentInk, size: 18),
            ],
          ),
          SizedBox(height: 12),
          Text(value, style: AppTextStyles.pageTitle),
          if (growth.isNotEmpty) ...[
            SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.show_chart, color: AppColors.success, size: 14),
                SizedBox(width: 4),
                Text(
                  growth,
                  style: GoogleFonts.poppins(
                    color: AppColors.success,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ] else
            SizedBox(height: 18),
        ],
      ),
    );
  }
}
