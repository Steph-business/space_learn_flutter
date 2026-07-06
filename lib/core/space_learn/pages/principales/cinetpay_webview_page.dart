import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:space_learn_flutter/core/themes/app_colors.dart';
import '../../data/dataServices/paymentService.dart';
import 'package:space_learn_flutter/core/utils/token_storage.dart';

import 'cinetpay_result_page.dart';

/// Page WebView qui affiche la page de paiement CinetPay
class CinetpayWebViewPage extends StatefulWidget {
  final String paymentUrl;
  final String transactionId;
  final String livreTitle;
  final double montant;

  const CinetpayWebViewPage({
    super.key,
    required this.paymentUrl,
    required this.transactionId,
    required this.livreTitle,
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
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.scaffoldBackground)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            setState(() => _isLoading = true);
            _checkIfReturnUrl(url);
          },
          onPageFinished: (url) {
            setState(() => _isLoading = false);
          },
          onWebResourceError: (error) {
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

  bool _isCinetpayReturnUrl(String url) {
    // CinetPay redirects to the return_url after payment
    // Detect common CinetPay redirect indicators
    return url.contains('cinetpay') == false &&
        (url.contains('success') ||
            url.contains('return') ||
            url.contains('cancel') ||
            url.contains('spacelearn'));
  }

  void _checkIfReturnUrl(String url) {
    if (_isCinetpayReturnUrl(url)) {
      _verifyPaymentStatus();
    }
  }

  Future<void> _verifyPaymentStatus() async {
    if (_isCheckingStatus) return;
    setState(() => _isCheckingStatus = true);

    try {
      final token = await TokenStorage.getToken();
      if (token == null) return;

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
            livreTitle: widget.livreTitle,
            montant: widget.montant,
            paymentMethod: result.paymentMethod,
            transactionId: widget.transactionId,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCheckingStatus = false);
      // Si la vérification échoue, on reste sur la page
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
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => _showCancelDialog(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Paiement CinetPay',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              widget.livreTitle,
              style: GoogleFonts.poppins(color: Colors.white54, fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          // Bouton de vérification manuelle du statut
          TextButton.icon(
            onPressed: _isCheckingStatus ? null : _verifyPaymentStatus,
            icon: _isCheckingStatus
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  )
                : const Icon(
                    Icons.check_circle_outline,
                    size: 16,
                    color: AppColors.primary,
                  ),
            label: Text(
              'J\'ai payé',
              style: GoogleFonts.poppins(
                color: AppColors.primary,
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
                    const CircularProgressIndicator(color: AppColors.primary),
                    const SizedBox(height: 16),
                    Text(
                      'Chargement du paiement...',
                      style: GoogleFonts.poppins(
                        color: Colors.white70,
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.scaffoldBackground.withValues(alpha: 0.95),
                border: Border(
                  top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline, size: 14, color: Colors.green),
                  const SizedBox(width: 6),
                  Text(
                    'Paiement sécurisé par CinetPay',
                    style: GoogleFonts.poppins(
                      color: Colors.white38,
                      fontSize: 11,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${widget.montant.toStringAsFixed(0)} XOF',
                    style: GoogleFonts.poppins(
                      color: AppColors.primary,
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
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Annuler le paiement ?',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Êtes-vous sûr de vouloir annuler ce paiement ? Votre progression de paiement sera perdue.',
          style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Continuer',
              style: GoogleFonts.poppins(color: AppColors.primary),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: Text(
              'Annuler',
              style: GoogleFonts.poppins(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
