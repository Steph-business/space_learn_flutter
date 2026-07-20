import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/themes/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'dart:async' as java_timer;
import 'package:google_fonts/google_fonts.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/authServices.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/paymentService.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/libraryService.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/bookService.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/paymentModel.dart';
import 'package:space_learn_flutter/core/utils/token_storage.dart';
import 'package:space_learn_flutter/core/themes/layout/nav_bar_lecteur.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/cinetpay_webview_page.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/cinetpay_result_page.dart';

class PaymentPage extends StatefulWidget {
  final Map<String, dynamic> book;

  const PaymentPage({super.key, required this.book});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  String _selectedMethod = 'MTN MoMo';
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String price = widget.book['prix']?.toString() ?? '9,99';
    final String currency = 'FCFA';

    return Scaffold(
      backgroundColor: AppColors.darkSurface, // Dark slate background
      appBar: AppBar(
        backgroundColor: AppColors.darkSurface,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Paiement Sécurisé',
          style: AppTextStyles.subtitle,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Book Summary Card
            _buildBookSummary(price, currency),

            SizedBox(height: 30),
            Divider(color: AppColors.textPrimary.withOpacity(0.05), thickness: 1),
            SizedBox(height: 30),

            // Method Selector
            _buildMethodSelector(),

            SizedBox(height: 30),

            // Details Section
            if (_selectedMethod == 'Carte Visa') ...[
              Text(
                'Détails de la carte',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 20),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildInputField(
                      label: 'Nom sur la carte',
                      hint: 'Jean Dupont',
                      controller: _nameController,
                    ),
                    SizedBox(height: 20),
                    _buildInputField(
                      label: 'Numéro de carte',
                      hint: '•••• •••• •••• 4242',
                      controller: _cardNumberController,
                      suffixIcon: Icons.credit_card,
                      keyboardType: TextInputType.number,
                    ),
                    SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _buildInputField(
                            label: 'Date d\'expiration',
                            hint: 'MM/AA',
                            controller: _expiryController,
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: _buildInputField(
                            label: 'CVV',
                            hint: '123',
                            controller: _cvvController,
                            suffixIcon: Icons.lock,
                            keyboardType: TextInputType.number,
                            obscureText: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Mobile Money UI (Orange / Wave)
              Text(
                'Paiement via $_selectedMethod',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 20),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildInputField(
                      label: 'Numéro de téléphone',
                      hint: '07 •• •• •• ••',
                      controller: _cardNumberController,
                      prefixText: '+225 ',
                      suffixIcon: Icons.phone_android,
                      keyboardType: TextInputType.phone,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Vous recevrez une demande de confirmation sur votre téléphone.',
                      style: AppTextStyles.greyMedium12,
                    ),
                  ],
                ),
              ),
            ],

            SizedBox(height: 48),

            // Pay Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _processPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryLight,
                  foregroundColor: AppColors.textPrimary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Payer $price $currency',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),

            SizedBox(height: 16),
            Center(
              child: Text(
                _selectedMethod == 'MTN MoMo'
                    ? 'Paiement sécurisé par MTN MoMo'
                    : _selectedMethod == 'Orange Money'
                        ? 'Paiement sécurisé par Orange Money'
                        : 'Paiement sécurisé par Stripe',
                style: AppTextStyles.greyMedium12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookSummary(String price, String currency) {
    return Row(
      children: [
        // Book Cover
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child:
                widget.book['image_couverture'] != null &&
                    widget.book['image_couverture'].toString().isNotEmpty &&
                    !widget.book['image_couverture'].toString().contains(
                      'example.com',
                    )
                ? Image.network(
                    widget.book['image_couverture'],
                    fit: BoxFit.cover,
                  )
                : Container(
                    color: AppColors.cardBackground,
                    child: Icon(Icons.book, color: AppColors.textPrimary),
                  ),
          ),
        ),
        SizedBox(width: 16),
        // Info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.book['titre'] ?? 'Les Rivières du Temps',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                widget.book['authorName'] ?? 'Claire Dubois',
                style: AppTextStyles.grey14,
              ),
              SizedBox(height: 4),
              Text(
                '$price $currency',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryLight,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMethodSelector() {
    return Container(
      padding: EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildMethodButton('MTN MoMo'),
          _buildMethodButton('Carte Visa'),
          _buildMethodButton('Orange Money'),
        ],
      ),
    );
  }

  Widget _buildMethodButton(String method) {
    final bool isSelected = _selectedMethod == method;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedMethod = method),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryLight : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            method,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required String hint,
    required TextEditingController controller,
    String? prefixText,
    IconData? suffixIcon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.button14,
        ),
        SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          style: AppTextStyles.body15,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.poppins(color: Colors.grey[600]),
            prefixText: prefixText,
            prefixStyle: AppTextStyles.body15,
            filled: true,
            fillColor: AppColors.surfaceVariant,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppColors.textPrimary.withOpacity(0.05)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppColors.textPrimary.withOpacity(0.05)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: AppColors.primaryLight,
                width: 1.5,
              ),
            ),
            suffixIcon: suffixIcon != null
                ? Icon(suffixIcon, color: Colors.grey[600], size: 20)
                : null,
          ),
          validator: (value) {
            if (value == null || value.isEmpty) return 'Requis';
            return null;
          },
        ),
      ],
    );
  }

  void _processPayment() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: CircularProgressIndicator(color: AppColors.primaryLight),
      ),
    );

    try {
      final token = await TokenStorage.getToken();
      if (token == null) throw Exception("Utilisateur non connecté");

      final authService = AuthService();
      final user = await authService.getUser(token);
      if (user == null) throw Exception("Impossible de récupérer les infos");

      final libraryService = LibraryService();

      // Vérifier si le livre est déjà possédé
      final userLibrary = await libraryService.getUserLibrary(token);
      final bool isAlreadyOwned = userLibrary.any(
        (item) =>
            item.livreId == (widget.book['id']?.toString() ?? "") ||
            (item.livre != null &&
                item.livre!.id == (widget.book['id']?.toString() ?? "")),
      );

      if (!mounted) return;

      if (isAlreadyOwned) {
        Navigator.of(context).pop();
        _showOwnedDialog();
        return;
      }

      final double amount =
          double.tryParse(widget.book['prix']?.toString() ?? '0') ?? 0.0;

      // ── MTN MoMo : processus asynchrone avec validation USSD ──
      if (_selectedMethod == 'MTN MoMo') {
        final paymentService = PaymentService();
        final phone = _cardNumberController.text.trim();
        final fullPhone = phone.startsWith('+') ? phone : '+225$phone';

        final payment = PaymentModel(
          id: "",
          utilisateurId: user.id,
          livreId: widget.book['id']?.toString() ?? "",
          methodePaiement: "mtn_money",
          transactionId: fullPhone,
          phoneNumber: fullPhone,
          referenceId: "",
          montant: amount,
          creeLe: DateTime.now(),
        );

        final createdPayment = await paymentService.createPayment(payment, token);
        final refId = createdPayment.referenceId;

        if (!mounted) return;
        Navigator.of(context).pop(); // Fermer le chargement initial

        bool paymentSuccessful = false;
        bool isPolling = true;

        // Afficher l'alerte d'attente de validation USSD
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogCtx) => WillPopScope(
            onWillPop: () async => false,
            child: AlertDialog(
              backgroundColor: AppColors.surfaceVariant,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppColors.primaryLight),
                  SizedBox(height: 24),
                  Text(
                    "Attente de validation...",
                    style: GoogleFonts.poppins(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Veuillez valider la transaction de ${amount.toStringAsFixed(0)} FCFA sur votre téléphone ($fullPhone).",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        // Boucle de polling du statut MoMo
        int attempts = 0;
        const maxAttempts = 20; // 60 secondes max (20 * 3s)
        while (isPolling && attempts < maxAttempts && !paymentSuccessful) {
          await Future.delayed(const Duration(seconds: 3));
          attempts++;
          try {
            final statusMap = await paymentService.getMomoStatus(refId, token);
            final status = statusMap['status']?.toString().toUpperCase() ?? '';
            if (status == 'SUCCESSFUL') {
              paymentSuccessful = true;
              isPolling = false;
            } else if (status == 'FAILED' || status == 'REJECTED') {
              isPolling = false;
            }
          } catch (e) {
            debugPrint("Erreur lors de la vérification du statut MoMo: $e");
          }
        }

        // Fermer la boîte de dialogue d'attente
        if (!mounted) return;
        Navigator.of(context).pop();

        // Naviguer vers la page de résultat de paiement
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => CinetpayResultPage(
              status: paymentSuccessful ? 'ACCEPTED' : 'REFUSED',
              book: widget.book,
              montant: amount,
              paymentMethod: 'MTN MoMo',
              transactionId: refId,
            ),
          ),
        );
        return;
      }

      // ── Autres méthodes (Carte Visa, Orange Money…) : traitement via CinetPay ──
      final paymentService = PaymentService();
      if (amount > 0) {
        final methode = _selectedMethod == 'Orange Money' ? 'orange_money' : 'carte_visa';
        // On initie le paiement CinetPay
        final result = await paymentService.initiateCinetpayPayment(
          livreId: widget.book['id']?.toString() ?? "",
          montant: amount,
          authToken: token,
          customerName: _nameController.text.trim(),
        );

        if (!mounted) return;
        Navigator.of(context).pop(); // Fermer le dialog de chargement

        // Lancer la WebView CinetPay
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => CinetpayWebViewPage(
              paymentUrl: result.paymentUrl,
              transactionId: result.paiement.transactionId,
              book: widget.book,
              montant: amount,
            ),
          ),
        );
        return;
      }

      // Si gratuit
      await libraryService.addToLibrary(
        widget.book['id']?.toString() ?? "",
        user.id,
        "gratuit",
        token,
      );

      // Incrémenter les téléchargements
      try {
        final bookService = BookService();
        final currentDownloads = widget.book['telechargements'] ?? 0;
        await bookService.updateBook(widget.book['id']?.toString() ?? "", {
          'telechargements': currentDownloads + 1,
        }, token);
      } catch (_) {}

      if (!mounted) return;
      Navigator.of(context).pop();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => PaymentConfirmationPage(book: widget.book),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur : $e"), backgroundColor: Colors.red),
      );
    }
  }

  void _showOwnedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceVariant,
        title: Text(
          'Livre déjà possédé',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'Vous possédez déjà ce livre dans votre bibliothèque.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).popUntil((route) => route.isFirst);
              MainNavBar.mainNavBarKey.currentState?.navigateToMarketplace();
            },
            child: Text('OK', style: TextStyle(color: AppColors.primaryLight)),
          ),
        ],
      ),
    );
  }
}

class PaymentConfirmationPage extends StatefulWidget {
  final Map<String, dynamic> book;
  const PaymentConfirmationPage({super.key, required this.book});
  @override
  State<PaymentConfirmationPage> createState() =>
      _PaymentConfirmationPageState();
}

class _PaymentConfirmationPageState extends State<PaymentConfirmationPage> {
  int _secondsRemaining = 3;
  late java_timer.Timer _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = java_timer.Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        _timer.cancel();
        _navigateToLibrary();
      }
    });
  }

  void _navigateToLibrary() {
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    MainNavBar.mainNavBarKey.currentState?.navigateToBibliotheque();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkSurface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_rounded,
                  color: AppColors.primaryLight,
                  size: 64,
                ),
              ),
              SizedBox(height: 32),
              Text(
                'Paiement réussi !',
                style: AppTextStyles.heroTitle,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              Text(
                'Votre achat de "${widget.book['titre']}" a été confirmé.',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24),
              Text(
                'Redirection dans $_secondsRemaining...',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppColors.primaryLight,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: _navigateToLibrary,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryLight,
                    foregroundColor: AppColors.textPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Aller dans ma bibliothèque',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}