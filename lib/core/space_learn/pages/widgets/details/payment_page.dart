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

class PaymentPage extends StatefulWidget {
  final Map<String, dynamic> book;

  const PaymentPage({super.key, required this.book});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  String _selectedMethod = 'Carte Visa';
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
    final String currency = '€';

    return Scaffold(
      backgroundColor: const Color(0xFF111827), // Dark slate background
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Paiement Sécurisé',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Book Summary Card
            _buildBookSummary(price, currency),

            const SizedBox(height: 30),
            Divider(color: Colors.white.withOpacity(0.05), thickness: 1),
            const SizedBox(height: 30),

            // Method Selector
            _buildMethodSelector(),

            const SizedBox(height: 30),

            // Details Section
            if (_selectedMethod == 'Carte Visa') ...[
              Text(
                'Détails de la carte',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildInputField(
                      label: 'Nom sur la carte',
                      hint: 'Jean Dupont',
                      controller: _nameController,
                    ),
                    const SizedBox(height: 20),
                    _buildInputField(
                      label: 'Numéro de carte',
                      hint: '•••• •••• •••• 4242',
                      controller: _cardNumberController,
                      suffixIcon: Icons.credit_card,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _buildInputField(
                            label: 'Date d\'expiration',
                            hint: 'MM/AA',
                            controller: _expiryController,
                          ),
                        ),
                        const SizedBox(width: 16),
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
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
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
                    const SizedBox(height: 12),
                    Text(
                      'Vous recevrez une demande de confirmation sur votre téléphone.',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 48),

            // Pay Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _processPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF22D3EE),
                  foregroundColor: Colors.white,
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

            const SizedBox(height: 16),
            Center(
              child: Text(
                'Paiement sécurisé par Stripe',
                style: GoogleFonts.poppins(
                  color: Colors.grey[500],
                  fontSize: 12,
                ),
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
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
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
                    color: const Color(0xFF1E293B),
                    child: const Icon(Icons.book, color: Colors.white),
                  ),
          ),
        ),
        const SizedBox(width: 16),
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
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                widget.book['authorName'] ?? 'Claire Dubois',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[400],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$price $currency',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF22D3EE),
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
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildMethodButton('Carte Visa'),
          _buildMethodButton('Orange Money'),
          _buildMethodButton('Wave'),
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
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF22D3EE) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            method,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? Colors.white : Colors.grey[400],
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
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          style: GoogleFonts.poppins(fontSize: 15, color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.poppins(color: Colors.grey[600]),
            prefixText: prefixText,
            prefixStyle: GoogleFonts.poppins(color: Colors.white, fontSize: 15),
            filled: true,
            fillColor: const Color(0xFF1F2937),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: Color(0xFF22D3EE),
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
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF22D3EE)),
      ),
    );

    try {
      final token = await TokenStorage.getToken();
      if (token == null) throw Exception("Utilisateur non connecté");

      final authService = AuthService();
      final user = await authService.getUser(token);
      if (user == null) throw Exception("Impossible de récupérer les infos");

      final paymentService = PaymentService();
      final libraryService = LibraryService();

      // Check ownership
      final userLibrary = await libraryService.getUserLibrary(token);
      final bool isAlreadyOwned = userLibrary.any(
        (item) =>
            item.livreId == (widget.book['id']?.toString() ?? "") ||
            (item.livre != null &&
                item.livre!.id == (widget.book['id']?.toString() ?? "")),
      );

      if (isAlreadyOwned) {
        Navigator.of(context).pop();
        _showOwnedDialog();
        return;
      }

      final double amount =
          double.tryParse(widget.book['prix']?.toString() ?? '0') ?? 0.0;

      if (amount > 0) {
        final payment = PaymentModel(
          id: "",
          utilisateurId: user.id,
          livreId: widget.book['id']?.toString() ?? "",
          methodePaiement: _selectedMethod.toLowerCase().replaceAll(' ', '_'),
          transactionId: "TRX-${DateTime.now().millisecondsSinceEpoch}",
          referenceId: "REF-${DateTime.now().millisecondsSinceEpoch}",
          montant: amount,
          creeLe: DateTime.now(),
        );
        await paymentService.createPayment(payment, token);
      }

      await libraryService.addToLibrary(
        widget.book['id']?.toString() ?? "",
        user.id,
        amount > 0 ? "achat" : "gratuit",
        token,
      );

      // Increment downloads
      try {
        final bookService = BookService();
        final currentDownloads = widget.book['telechargements'] ?? 0;
        await bookService.updateBook(widget.book['id']?.toString() ?? "", {
          'telechargements': currentDownloads + 1,
        }, token);
      } catch (_) {}

      Navigator.of(context).pop();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => PaymentConfirmationPage(book: widget.book),
        ),
      );
    } catch (e) {
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
        backgroundColor: const Color(0xFF1F2937),
        title: const Text(
          'Livre déjà possédé',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Vous possédez déjà ce livre dans votre bibliothèque.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).popUntil((route) => route.isFirst);
              MainNavBar.mainNavBarKey.currentState?.navigateToMarketplace();
            },
            child: const Text('OK', style: TextStyle(color: Color(0xFF22D3EE))),
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
      backgroundColor: const Color(0xFF111827),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF22D3EE).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Color(0xFF22D3EE),
                  size: 64,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Paiement réussi !',
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Votre achat de "${widget.book['titre']}" a été confirmé.',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.grey[400],
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Text(
                'Redirection dans $_secondsRemaining...',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: const Color(0xFF22D3EE),
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: _navigateToLibrary,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF22D3EE),
                    foregroundColor: Colors.white,
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
