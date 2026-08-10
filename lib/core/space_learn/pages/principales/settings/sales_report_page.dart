import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:space_learn_flutter/core/space_learn/data/dataServices/bookService.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/reversementService.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/book_model.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/reversement_model.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/settings/payout_info_page.dart';
import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/themes/app_dimensions.dart';
import 'package:space_learn_flutter/core/themes/widgets/app_card.dart';
import 'package:space_learn_flutter/core/utils/token_storage.dart';

/// Rapport de ventes de l'auteur.
///
/// Les montants viennent du registre de reversements du backend, c'est-à-dire
/// des paiements réellement encaissés. La version précédente estimait un
/// « solde disponible » côté client à partir du nombre de téléchargements, et
/// proposait un bouton « Retirer » qui n'appelait aucune API : l'auteur voyait
/// une confirmation de virement alors que rien ne partait.
class SalesReportPage extends StatefulWidget {
  const SalesReportPage({super.key});

  @override
  State<SalesReportPage> createState() => _SalesReportPageState();
}

class _SalesReportPageState extends State<SalesReportPage> {
  final ReversementService _reversementService = ReversementService();
  final BookService _bookService = BookService();

  ResumeReversements _resume = ResumeReversements.vide;
  List<ReversementModel> _reversements = [];
  Map<String, String> _titresParLivre = {};

  bool _isLoading = true;
  String? _erreur;
  bool _numeroManquant = false;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    if (mounted) setState(() => _erreur = null);

    try {
      final token = await TokenStorage.getToken();
      if (token == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _erreur = 'Session expirée. Reconnectez-vous.';
          });
        }
        return;
      }

      final (resume, reversements) =
          await _reversementService.getMesReversements(token);

      // Les reversements ne portent que l'identifiant du livre : on résout les
      // titres pour que l'historique soit lisible.
      final infos = await _reversementService.getInfosPaiement(token);
      final titres = await _chargerTitres(token);

      if (!mounted) return;
      setState(() {
        _resume = resume;
        _reversements = reversements;
        _titresParLivre = titres;
        _numeroManquant = infos == null || !infos.estRenseigne;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _erreur = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<Map<String, String>> _chargerTitres(String token) async {
    try {
      final livres = await _bookService.getAllBooks(authToken: token);
      return {
        for (final BookModel l in livres) l.id: l.titre,
      };
    } catch (_) {
      return {};
    }
  }

  String _formaterMontant(double montant, String devise) {
    final f = NumberFormat.decimalPattern('fr_FR');
    return '${f.format(montant.round())} $devise';
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
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Rapports de ventes',
          style: GoogleFonts.poppins(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Compte de versement',
            icon: Icon(Icons.account_balance_wallet_outlined,
                color: AppColors.textPrimary),
            onPressed: _ouvrirCompteVersement,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _charger,
              color: AppColors.primary,
              child: ListView(
                padding: const EdgeInsets.all(AppDimensions.screenPadding),
                children: [
                  if (_erreur != null) ...[
                    _bandeauErreur(_erreur!),
                    const SizedBox(height: AppDimensions.sectionGap),
                  ],
                  if (_numeroManquant) ...[
                    _bandeauNumeroManquant(),
                    const SizedBox(height: AppDimensions.sectionGap),
                  ],
                  _carteGains(),
                  const SizedBox(height: AppDimensions.sectionGap),
                  Text(
                    'Historique des versements',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spaceMd),
                  if (_reversements.isEmpty)
                    _etatVide()
                  else
                    ..._reversements.map(_ligneReversement),
                ],
              ),
            ),
    );
  }

  Future<void> _ouvrirCompteVersement() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PayoutInfoPage()),
    );
    if (mounted) _charger();
  }

  Widget _carteGains() {
    final devise = _resume.devise;
    final pourcentage = (_resume.tauxCommission * 100).round();

    return AppCard(
      padding: const EdgeInsets.all(AppDimensions.spaceXl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total versé',
            style: GoogleFonts.poppins(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppDimensions.spaceXs),
          Text(
            _formaterMontant(_resume.totalVerse, devise),
            style: GoogleFonts.poppins(
              color: AppColors.primary,
              fontSize: 30,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppDimensions.spaceLg),
          Divider(color: AppColors.borderLight, height: 1),
          const SizedBox(height: AppDimensions.spaceLg),
          Row(
            children: [
              Expanded(
                child: _statistique(
                  'En attente de virement',
                  _formaterMontant(_resume.totalEnAttente, devise),
                ),
              ),
              Expanded(
                child: _statistique(
                  'Commission plateforme',
                  '$pourcentage %',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spaceMd),
          Text(
            'Les montants sont virés automatiquement sur votre compte Mobile Money à chaque vente, commission déduite.',
            style: GoogleFonts.poppins(
              color: AppColors.textHint,
              fontSize: 11.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statistique(String libelle, String valeur) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          libelle,
          style: GoogleFonts.poppins(
            color: AppColors.textSecondary,
            fontSize: 11.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          valeur,
          style: GoogleFonts.poppins(
            color: AppColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _bandeauNumeroManquant() {
    return AppCard(
      onTap: _ouvrirCompteVersement,
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 22),
          const SizedBox(width: AppDimensions.spaceMd),
          Expanded(
            child: Text(
              "Renseignez votre numéro Mobile Money pour recevoir vos ventes. Vos gains sont enregistrés en attendant.",
              style: GoogleFonts.poppins(
                color: AppColors.textPrimary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
          Icon(Icons.arrow_forward_ios_rounded,
              color: AppColors.textHint, size: 14),
        ],
      ),
    );
  }

  Widget _bandeauErreur(String message) {
    return AppCard(
      child: Row(
        children: [
          Icon(Icons.error_outline, color: AppColors.error, size: 22),
          const SizedBox(width: AppDimensions.spaceMd),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.poppins(
                color: AppColors.textPrimary,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _etatVide() {
    return AppCard(
      padding: const EdgeInsets.all(AppDimensions.spaceXl),
      child: Column(
        children: [
          Icon(Icons.receipt_long_outlined,
              size: 44, color: AppColors.textSecondary),
          const SizedBox(height: AppDimensions.spaceMd),
          Text(
            'Aucune vente pour le moment',
            style: GoogleFonts.poppins(
              color: AppColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _ligneReversement(ReversementModel rev) {
    final titre = _titresParLivre[rev.livreId] ?? 'Livre';
    final date = rev.envoyeLe ?? rev.creeLe;
    final dateStr =
        date == null ? '' : DateFormat('d MMM y', 'fr_FR').format(date.toLocal());

    final (couleur, icone) = switch (rev.statut) {
      'paye' || 'envoye' => (AppColors.success, Icons.check_rounded),
      'sans_infos' => (AppColors.warning, Icons.phone_disabled_rounded),
      'echoue' => (AppColors.error, Icons.refresh_rounded),
      _ => (AppColors.textHint, Icons.schedule_rounded),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spaceMd),
      child: AppCard(
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: couleur.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icone, color: couleur, size: 18),
            ),
            const SizedBox(width: AppDimensions.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dateStr.isEmpty
                        ? rev.libelleStatut
                        : '${rev.libelleStatut} • $dateStr',
                    style: GoogleFonts.poppins(
                      color: AppColors.textSecondary,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppDimensions.spaceSm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '+ ${_formaterMontant(rev.montantNet, rev.devise)}',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    color: rev.estVerse
                        ? AppColors.success
                        : AppColors.textPrimary,
                    fontSize: 14,
                  ),
                ),
                // La commission est affichée explicitement : l'auteur doit
                // pouvoir rapprocher ce qu'il reçoit du prix de vente.
                Text(
                  'sur ${_formaterMontant(rev.montantBrut, rev.devise)}',
                  style: GoogleFonts.poppins(
                    color: AppColors.textHint,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
