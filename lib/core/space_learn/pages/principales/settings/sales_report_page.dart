import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:space_learn_flutter/core/utils/app_notifications.dart';
import 'package:space_learn_flutter/core/utils/token_storage.dart';

/// Portefeuille de l'auteur : gains cumulés, retrait à la demande, historique.
///
/// Les montants viennent du registre du serveur, donc des paiements réellement
/// encaissés. La version précédente estimait un solde côté client à partir du
/// nombre de téléchargements, et son bouton « Retirer » n'appelait aucune API :
/// l'auteur voyait une confirmation de virement alors que rien ne partait.
class SalesReportPage extends StatefulWidget {
  const SalesReportPage({super.key});

  @override
  State<SalesReportPage> createState() => _SalesReportPageState();
}

class _SalesReportPageState extends State<SalesReportPage> {
  final ReversementService _service = ReversementService();
  final BookService _bookService = BookService();

  Portefeuille _portefeuille = Portefeuille.vide;
  Map<String, String> _titresParLivre = {};

  bool _isLoading = true;
  bool _retraitEnCours = false;
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

      final portefeuille = await _service.getPortefeuille(token);
      final infos = await _service.getInfosPaiement(token);
      final titres = await _chargerTitres(token);

      if (!mounted) return;
      setState(() {
        _portefeuille = portefeuille;
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

  /// Les crédits ne portent que l'identifiant du livre : on résout les titres
  /// pour que l'historique soit lisible.
  Future<Map<String, String>> _chargerTitres(String token) async {
    try {
      final livres = await _bookService.getAllBooks(authToken: token);
      return {for (final BookModel l in livres) l.id: l.titre};
    } catch (_) {
      return {};
    }
  }

  String _montant(double valeur, [String? devise]) {
    final f = NumberFormat.decimalPattern('fr_FR');
    return '${f.format(valeur.round())} ${devise ?? _portefeuille.solde.devise}';
  }

  // ──────────────────────────── Actions ────────────────────────────

  Future<void> _ouvrirCompteVersement() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const PayoutInfoPage()));
    if (mounted) _charger();
  }

  Future<void> _demanderRetrait() async {
    final montant = await _saisirMontant();
    if (montant == null) return;

    setState(() => _retraitEnCours = true);
    try {
      final token = await TokenStorage.getToken();
      if (token == null) throw Exception('Session expirée');

      await _service.demanderRetrait(authToken: token, montant: montant);

      if (!mounted) return;
      AppNotifications.showSnackBar(
        context,
        message:
            'Demande enregistrée. Le virement part vers votre Mobile Money.',
        isSuccess: true,
      );
      await _charger();
    } on ReversementException catch (e) {
      if (!mounted) return;
      setState(() => _retraitEnCours = false);

      // Le numéro manquant est la seule erreur qui appelle une action
      // immédiate : on emmène l'auteur là où il peut la corriger.
      if (e.numeroManquant) {
        await _ouvrirCompteVersement();
        return;
      }
      AppNotifications.showSnackBar(
        context,
        message: e.message,
        isSuccess: false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _retraitEnCours = false);
      AppNotifications.showSnackBar(
        context,
        message: e.toString().replaceFirst('Exception: ', ''),
        isSuccess: false,
      );
    } finally {
      if (mounted) setState(() => _retraitEnCours = false);
    }
  }

  /// Demande le montant à retirer, prérempli avec la totalité du disponible.
  Future<double?> _saisirMontant() async {
    final solde = _portefeuille.solde;
    final controleur = TextEditingController(
      text: solde.disponible.round().toString(),
    );
    final cleFormulaire = GlobalKey<FormState>();

    return showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        ),
        title: Text(
          'Montant à retirer',
          style: GoogleFonts.poppins(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        content: Form(
          key: cleFormulaire,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Disponible : ${_montant(solde.disponible)}\n'
                'Minimum : ${_montant(_portefeuille.minimumRetrait)}',
                style: GoogleFonts.poppins(
                  color: AppColors.textSecondary,
                  fontSize: 12.5,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: AppDimensions.spaceLg),
              TextFormField(
                controller: controleur,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                autofocus: true,
                style: GoogleFonts.poppins(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  suffixText: solde.devise,
                  suffixStyle: GoogleFonts.poppins(
                    color: AppColors.textSecondary,
                  ),
                  filled: true,
                  fillColor: AppColors.scaffoldBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusInner,
                    ),
                  ),
                ),
                validator: (v) {
                  final montant = double.tryParse(v ?? '');
                  if (montant == null || montant <= 0) {
                    return 'Montant invalide';
                  }
                  if (montant < _portefeuille.minimumRetrait) {
                    return 'Minimum ${_montant(_portefeuille.minimumRetrait)}';
                  }
                  if (montant > solde.disponible) {
                    return 'Supérieur au solde disponible';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Annuler',
              style: GoogleFonts.poppins(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (!cleFormulaire.currentState!.validate()) return;
              Navigator.of(context).pop(double.parse(controleur.text));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onAccent,
              elevation: 0,
            ),
            child: Text(
              'Confirmer',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _annulerRetrait(RetraitModel retrait) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: Text(
          'Annuler ce retrait ?',
          style: GoogleFonts.poppins(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        content: Text(
          'Les ${_montant(retrait.montant, retrait.devise)} retourneront à votre solde disponible.',
          style: GoogleFonts.poppins(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Non',
              style: GoogleFonts.poppins(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Oui, annuler',
              style: GoogleFonts.poppins(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirme != true) return;

    try {
      final token = await TokenStorage.getToken();
      if (token == null) throw Exception('Session expirée');
      await _service.annulerRetrait(authToken: token, retraitId: retrait.id);
      if (!mounted) return;
      AppNotifications.showSnackBar(
        context,
        message: 'Retrait annulé, le montant est de nouveau disponible.',
        isSuccess: true,
      );
      await _charger();
    } catch (e) {
      if (!mounted) return;
      AppNotifications.showSnackBar(
        context,
        message: e.toString().replaceFirst('Exception: ', ''),
        isSuccess: false,
      );
    }
  }

  // ──────────────────────────── Rendu ────────────────────────────

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
          'Mes gains',
          style: GoogleFonts.poppins(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Compte de versement',
            icon: Icon(
              Icons.account_balance_wallet_outlined,
              color: AppColors.textPrimary,
            ),
            onPressed: _ouvrirCompteVersement,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.accentInk))
          : RefreshIndicator(
              onRefresh: _charger,
              color: AppColors.accentInk,
              child: ListView(
                padding: const EdgeInsets.all(AppDimensions.screenPadding),
                children: [
                  if (_erreur != null) ...[
                    _bandeau(Icons.error_outline, AppColors.error, _erreur!),
                    const SizedBox(height: AppDimensions.sectionGap),
                  ],
                  if (_numeroManquant) ...[
                    _bandeau(
                      Icons.warning_amber_rounded,
                      AppColors.warning,
                      "Renseignez votre numéro Mobile Money pour pouvoir retirer vos gains.",
                      onTap: _ouvrirCompteVersement,
                    ),
                    const SizedBox(height: AppDimensions.sectionGap),
                  ],
                  _carteSolde(),
                  const SizedBox(height: AppDimensions.sectionGap),
                  if (_portefeuille.retraits.isNotEmpty) ...[
                    _titre('Mes retraits'),
                    const SizedBox(height: AppDimensions.spaceMd),
                    ..._portefeuille.retraits.map(_ligneRetrait),
                    const SizedBox(height: AppDimensions.sectionGap),
                  ],
                  _titre('Mes ventes'),
                  const SizedBox(height: AppDimensions.spaceMd),
                  if (_portefeuille.ventes.isEmpty)
                    _etatVide()
                  else
                    ..._portefeuille.ventes.map(_ligneVente),
                ],
              ),
            ),
    );
  }

  Widget _titre(String texte) => Text(
    texte,
    style: GoogleFonts.poppins(
      fontSize: 16,
      fontWeight: FontWeight.bold,
      color: AppColors.textPrimary,
    ),
  );

  Widget _carteSolde() {
    final solde = _portefeuille.solde;
    final pourcentage = (_portefeuille.tauxCommission * 100).round();
    final peutRetirer = _portefeuille.retraitPossible && !_retraitEnCours;

    return AppCard(
      padding: const EdgeInsets.all(AppDimensions.spaceXl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Solde disponible',
            style: GoogleFonts.poppins(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppDimensions.spaceXs),
          Text(
            _montant(solde.disponible),
            style: GoogleFonts.poppins(
              color: AppColors.accentInk,
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
                child: _statistique('Total gagné', _montant(solde.totalGagne)),
              ),
              Expanded(
                child: _statistique('Déjà retiré', _montant(solde.totalRetire)),
              ),
            ],
          ),
          if (solde.enCours > 0) ...[
            const SizedBox(height: AppDimensions.spaceMd),
            _statistique('Retrait en cours', _montant(solde.enCours)),
          ],
          const SizedBox(height: AppDimensions.spaceXl),
          SizedBox(
            height: 48,
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: peutRetirer ? _demanderRetrait : null,
              icon: _retraitEnCours
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.onAccent,
                      ),
                    )
                  : const Icon(Icons.south_west_rounded, size: 18),
              label: Text(
                'Retirer',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onAccent,
                disabledBackgroundColor: AppColors.primary.withValues(
                  alpha: 0.35,
                ),
                disabledForegroundColor: AppColors.onAccent.withValues(
                  alpha: 0.5,
                ),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppDimensions.radiusInner,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.spaceMd),
          Text(
            _portefeuille.retraitPossible
                ? 'Commission de la plateforme : $pourcentage % sur chaque vente.'
                : 'Retrait possible à partir de ${_montant(_portefeuille.minimumRetrait)}. '
                      'Commission de la plateforme : $pourcentage % sur chaque vente.',
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

  Widget _statistique(String libelle, String valeur) => Column(
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

  Widget _bandeau(
    IconData icone,
    Color couleur,
    String texte, {
    VoidCallback? onTap,
  }) {
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icone, color: couleur, size: 22),
          const SizedBox(width: AppDimensions.spaceMd),
          Expanded(
            child: Text(
              texte,
              style: GoogleFonts.poppins(
                color: AppColors.textPrimary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
          if (onTap != null)
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: AppColors.textHint,
              size: 14,
            ),
        ],
      ),
    );
  }

  Widget _etatVide() => AppCard(
    padding: const EdgeInsets.all(AppDimensions.spaceXl),
    child: Column(
      children: [
        Icon(
          Icons.receipt_long_outlined,
          size: 44,
          color: AppColors.textSecondary,
        ),
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

  Widget _ligneRetrait(RetraitModel retrait) {
    final (couleur, icone) = switch (retrait.statut) {
      'payee' => (AppColors.success, Icons.check_rounded),
      'en_cours' => (AppColors.primary, Icons.sync_rounded),
      'echouee' => (AppColors.error, Icons.refresh_rounded),
      'annulee' => (AppColors.textHint, Icons.close_rounded),
      _ => (AppColors.warning, Icons.schedule_rounded),
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
                    _montant(retrait.montant, retrait.devise),
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _sousTitre(retrait),
                    style: GoogleFonts.poppins(
                      color: AppColors.textSecondary,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            if (retrait.estAnnulable)
              TextButton(
                onPressed: () => _annulerRetrait(retrait),
                child: Text(
                  'Annuler',
                  style: GoogleFonts.poppins(
                    color: AppColors.error,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _sousTitre(RetraitModel retrait) {
    final date = retrait.traiteLe ?? retrait.demandeLe;
    final quand = date == null
        ? ''
        : ' • ${DateFormat('d MMM y', 'fr_FR').format(date.toLocal())}';
    return '${retrait.libelleStatut}$quand';
  }

  Widget _ligneVente(ReversementModel vente) {
    final titre = _titresParLivre[vente.livreId] ?? 'Livre';
    final date = vente.creeLe;
    final quand = date == null
        ? ''
        : DateFormat('d MMM y', 'fr_FR').format(date.toLocal());

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spaceMd),
      child: AppCard(
        child: Row(
          children: [
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
                  if (quand.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      quand,
                      style: GoogleFonts.poppins(
                        color: AppColors.textSecondary,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppDimensions.spaceSm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '+ ${_montant(vente.montantNet, vente.devise)}',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    color: AppColors.success,
                    fontSize: 14,
                  ),
                ),
                // Le prix de vente est rappelé pour que l'auteur puisse
                // rapprocher ce qu'il touche de ce que l'acheteur a payé.
                Text(
                  'sur ${_montant(vente.montantBrut, vente.devise)}',
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
