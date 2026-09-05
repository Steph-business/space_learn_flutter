import 'dart:async';
import 'package:flutter/material.dart';
import 'package:space_learn_flutter/core/themes/app_dimensions.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:space_learn_flutter/core/themes/app_colors.dart';
import '../../data/dataServices/paymentService.dart';
import 'package:space_learn_flutter/core/utils/app_notifications.dart';
import 'package:space_learn_flutter/core/utils/message_erreur.dart';
import 'package:space_learn_flutter/core/utils/token_storage.dart';

import 'cinetpay_result_page.dart';

/// Page WebView qui affiche la page de paiement CinetPay
class CinetpayWebViewPage extends StatefulWidget {
  final String paymentUrl;
  final String transactionId;
  final Map<String, dynamic> book;
  final double montant;

  const CinetpayWebViewPage({
    super.key,
    required this.paymentUrl,
    required this.transactionId,
    required this.book,
    required this.montant,
  });

  @override
  State<CinetpayWebViewPage> createState() => _CinetpayWebViewPageState();
}

class _CinetpayWebViewPageState extends State<CinetpayWebViewPage> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _isCheckingStatus = false;

  @override
  void initState() {
    super.initState();
    _setupWebView();
  }

  void _setupWebView() {
    // Le contrôleur est affecté AVANT d'être configuré. Dans la forme
    // précédente (`_controller = WebViewController()..setJavaScriptMode(...)`),
    // l'affectation n'avait lieu qu'au bout de la cascade : une URL de paiement
    // malformée renvoyée par le serveur fait lever `Uri.parse` en fin de
    // cascade, le champ `late` restait alors non initialisé et le dispose
    // ajouté plus bas aurait levé une LateInitializationError qui aurait
    // masqué la vraie cause.
    _controller = WebViewController();
    _controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.scaffoldBackground)
      ..setNavigationDelegate(
        NavigationDelegate(
          // Ces trois callbacks peuvent arriver APRÈS la mort de l'écran, et
          // ils le faisaient sans garde. `WebViewWidget` est un
          // StatelessWidget : il ne possède pas le contrôleur et ne le libère
          // pas, et rien ne détachait la délégation. Un chargement encore en
          // cours quand on quitte la page — « Annuler le paiement ? » pendant
          // « Chargement du paiement... » sur réseau mobile lent, ou le
          // pushReplacement vers l'écran de résultat — se terminait ensuite et
          // rappelait onPageFinished sur un State défunt.
          //
          // Rien n'était visible : le pont pigeon avale l'exception et la
          // renvoie à la plateforme, en debug comme en release. C'est
          // justement ce qui rend le défaut sournois — dans onPageStarted,
          // setState levait AVANT `_checkIfReturnUrl(url)` et coupait le reste
          // du callback en silence. La garde passe donc devant le setState,
          // pas après, sur le chemin où circule l'argent.
          onPageStarted: (url) {
            if (!mounted) return;
            setState(() => _isLoading = true);
            _checkIfReturnUrl(url);
          },
          onPageFinished: (url) {
            if (!mounted) return;
            setState(() => _isLoading = false);
          },
          onWebResourceError: (error) {
            if (!mounted) return;
            setState(() => _isLoading = false);
          },
          onNavigationRequest: (request) {
            // Intercept return/notify URLs from CinetPay
            if (_isCinetpayReturnUrl(request.url)) {
              _verifyPaymentStatus();
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  /// Coupe la WebView en quittant l'écran, au lieu de la laisser vivre.
  ///
  /// Cet écran n'avait AUCUN dispose. Comme `WebViewWidget` est un
  /// StatelessWidget qui ne possède ni ne libère le contrôleur, la WebView
  /// native survivait à la route : elle continuait de charger la page de
  /// checkout abandonnée jusqu'au passage du ramasse-miettes — du réseau et de
  /// la mémoire dépensés dans le vide sur les téléphones d'entrée de gamme
  /// visés par l'application — et ses callbacks continuaient de remonter sur
  /// un State défunt. Les gardes `mounted` ci-dessus traitent le symptôme ;
  /// ceci traite la cause.
  ///
  /// L'ordre compte : on remplace d'abord la délégation par une délégation
  /// vide, pour que plus aucun callback ne remonte, PUIS on charge
  /// `about:blank` pour interrompre le chargement en cours — le paquet
  /// n'expose pas de `stopLoading`, naviguer ailleurs est le seul moyen.
  /// L'enchaînement par `then` garantit cet ordre (les deux appels ne passent
  /// pas par le même canal de plateforme), et `ignore()` neutralise l'erreur
  /// attendue si la vue native est déjà détruite : personne n'attend plus
  /// cette réponse.
  @override
  void dispose() {
    _controller
        .setNavigationDelegate(NavigationDelegate())
        .then((_) => _controller.loadRequest(Uri.parse('about:blank')))
        .ignore();
    super.dispose();
  }

  /// Reconnaît la page de retour, celle où CinetPay renvoie après paiement.
  ///
  /// La version précédente cherchait `success` — en anglais. Or les URL de
  /// retour configurées sur le serveur sont `/paiement/succes` et
  /// `/paiement/echec`, en français : « succes » ne contient pas « success ».
  /// Aucune des quatre conditions ne se vérifiait, la webview restait donc sur
  /// la page de retour sans jamais demander le statut, et l'achat n'aboutissait
  /// pas côté application — alors que le paiement, lui, était bien passé.
  ///
  /// On teste maintenant le CHEMIN plutôt que des mots-clés dispersés :
  /// `/paiement/` couvre les deux issues et suit le serveur si l'hôte change.
  /// Les termes anglais restent acceptés, au cas où l'URL de retour serait un
  /// jour reconfigurée dans cette langue.
  bool _isCinetpayReturnUrl(String url) {
    if (url.contains('cinetpay')) return false;

    final minuscules = url.toLowerCase();
    return minuscules.contains('/paiement/') ||
        minuscules.contains('succes') ||
        minuscules.contains('echec') ||
        minuscules.contains('success') ||
        minuscules.contains('failed') ||
        minuscules.contains('return') ||
        minuscules.contains('cancel') ||
        minuscules.contains('spacelearn');
  }

  void _checkIfReturnUrl(String url) {
    if (_isCinetpayReturnUrl(url)) {
      _verifyPaymentStatus();
    }
  }

  Future<void> _verifyPaymentStatus() async {
    if (_isCheckingStatus) return;
    // Atteignable après dispose : onPageStarted et onNavigationRequest peuvent
    // encore la déclencher tant que la WebView native n'est pas arrêtée. Ce
    // premier setState était le seul de la méthode à ne pas être gardé — les
    // suivants le sont déjà, plus bas.
    if (!mounted) return;
    setState(() => _isCheckingStatus = true);

    try {
      final token = await TokenStorage.getToken();
      if (token == null) {
        // L'ancien `return` sec laissait _isCheckingStatus à true : le bouton
        // « J'ai payé » restait grisé pour toujours, sans un mot.
        if (!mounted) return;
        setState(() => _isCheckingStatus = false);
        AppNotifications.showSnackBar(
          context,
          message: 'Votre session a expiré. Reconnectez-vous.',
          isError: true,
        );
        return;
      }

      final paymentService = PaymentService();
      final result = await paymentService.getCinetpayStatus(
        widget.transactionId,
        token,
      );

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => CinetpayResultPage(
            status: result.status,
            book: widget.book,
            // Le montant OFFICIEL relu en base par le serveur, quand la
            // réponse le porte. Le montant local de la fiche peut être périmé
            // si l'auteur a changé son prix : c'est CinetPay qui encaisse le
            // prix en base, l'écran de résultat doit annoncer le même.
            montant: result.montantServeur ?? widget.montant,
            // L'issue « refusé » se déduit de ce que le serveur dit vraiment
            // (paiement.statut, statut CinetPay du message) — le statut
            // "REFUSED" nu n'est jamais rendu par la route.
            estDefinitivementEchoue: result.definitivementEchoue,
            transactionId: widget.transactionId,
          ),
        ),
      );
    } catch (e) {
      // Le TypeError sur `"paiement": null` et les pannes réseau tombaient ici
      // en silence : le lecteur qui venait de payer tapait « J'ai payé » et ne
      // voyait STRICTEMENT rien se passer. L'échec de vérification s'affiche —
      // il ne dit rien du paiement lui-même, seulement que la vérification n'a
      // pas abouti.
      if (!mounted) return;
      setState(() => _isCheckingStatus = false);
      AppNotifications.showSnackBar(
        context,
        message: messageLisible(
          e,
          repli:
              "La vérification du paiement n'a pas abouti. Réessayez « J'ai payé » dans un instant.",
        ),
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
          icon: Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () => _showCancelDialog(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Paiement',
              style: GoogleFonts.poppins(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              widget.book['titre']?.toString() ?? 'Livre inconnu',
              style: GoogleFonts.poppins(
                color: AppColors.textHint,
                fontSize: 11,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          // Bouton de vérification manuelle du statut
          TextButton.icon(
            onPressed: _isCheckingStatus ? null : _verifyPaymentStatus,
            icon: _isCheckingStatus
                ? SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.accentInk,
                    ),
                  )
                : Icon(
                    Icons.check_circle_outline,
                    size: 16,
                    color: AppColors.accentInk,
                  ),
            label: Text(
              'J\'ai payé',
              style: GoogleFonts.poppins(
                color: AppColors.accentInk,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            Container(
              color: AppColors.scaffoldBackground,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppColors.accentInk),
                    SizedBox(height: 16),
                    Text(
                      'Chargement du paiement...',
                      style: GoogleFonts.poppins(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Barre de progression sécurisée
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.scaffoldBackground.withValues(alpha: 0.95),
                border: Border(
                  top: BorderSide(
                    color: AppColors.textPrimary.withValues(alpha: 0.08),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.lock_outline, size: 14, color: AppColors.success),
                  SizedBox(width: 6),
                  Text(
                    'Paiement 100% sécurisé ',
                    style: GoogleFonts.poppins(
                      color: AppColors.textHint,
                      fontSize: 11,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${widget.montant.toStringAsFixed(0)} FCFA',
                    style: GoogleFonts.poppins(
                      color: AppColors.accentInk,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCancelDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        // Ce fond était écrit en dur (#1E1E2E), hérité de l'époque où
        // l'application n'existait qu'en sombre. Le titre, lui, suit le thème :
        // en mode clair c'était du noir sur un pavé noir, au moment précis où
        // le lecteur décide d'abandonner un paiement.
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        ),
        title: Text(
          'Annuler le paiement ?',
          style: GoogleFonts.poppins(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Êtes-vous sûr de vouloir annuler ce paiement ? Votre progression de paiement sera perdue.',
          style: GoogleFonts.poppins(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Continuer',
              style: GoogleFonts.poppins(color: AppColors.accentInk),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: Text(
              'Annuler',
              style: GoogleFonts.poppins(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}
