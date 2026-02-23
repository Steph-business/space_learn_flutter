import 'package:flutter/material.dart';
import 'dart:async' as java_timer;
import 'package:google_fonts/google_fonts.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/authServices.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/paymentService.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/libraryService.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/bookService.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/paymentModel.dart';
import 'package:space_learn_flutter/core/utils/tokenStorage.dart';
import 'package:space_learn_flutter/core/themes/layout/navBarLecteur.dart';

class PaymentPage extends StatefulWidget {
  final Map<String, dynamic> book;

  const PaymentPage({super.key, required this.book});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  String _selectedMethod = 'Orange';
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _cardController = TextEditingController();
  final _expController = TextEditingController();
  final _cvvController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _cardController.dispose();
    _expController.dispose();
    _cvvController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String price = widget.book['prix']?.toString() ?? '0';

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Paiement Sécurisé',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Book Summary
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(color: Color(0xFFF59E0B)),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Small Cover Thumbnail
                    Container(
                      height: 80,
                      width: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.grey[100],
                      ),
                      child:
                          widget.book['image_couverture'] != null &&
                              widget.book['image_couverture']
                                  .toString()
                                  .isNotEmpty &&
                              !widget.book['image_couverture']
                                  .toString()
                                  .contains('example.com')
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                widget.book['image_couverture'],
                                fit: BoxFit.cover,
                              ),
                            )
                          : const Icon(Icons.book, color: Color(0xFFF59E0B)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.book['titre'] ?? 'Sans titre',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: const Color(0xFF1E293B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Par ${widget.book['Auteur'] != null ? widget.book['Auteur']['nom_complet'] : 'Auteur inconnu'}',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: '${widget.book['prix'] ?? '0'} ',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                TextSpan(
                                  text: 'FCFA',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.normal,
                                  ),
                                ),
                              ],
                              style: const TextStyle(
                                fontSize: 18,
                                color: Color(0xFFF59E0B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Méthode de paiement',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sélectionnez votre mode de paiement préféré',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Payment Methods Grid
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 1.3,
                    children: [
                      _buildPaymentMethodCard(
                        'Carte Visa',
                        Icons.credit_card_rounded,
                        const Color(0xFF1E293B),
                        () => _selectPaymentMethod('Visa'),
                      ),
                      _buildPaymentMethodCard(
                        'PayPal',
                        Icons.paypal_rounded,
                        const Color(0xFF003087),
                        () => _selectPaymentMethod('PayPal'),
                      ),
                      _buildPaymentMethodCard(
                        'Orange Money',
                        Icons.phone_android_rounded,
                        const Color(0xFFFF6600),
                        () => _selectPaymentMethod('Orange Money'),
                      ),
                      _buildPaymentMethodCard(
                        'Wave',
                        Icons.waves_rounded,
                        const Color(0xFF1DA1F2),
                        () => _selectPaymentMethod('Wave'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodCard(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 12),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: const Color(0xFF1E293B),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _selectPaymentMethod(String method) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            PaymentDetailsPage(method: method, book: widget.book),
      ),
    );
  }
}

// Widget pour les tuiles de méthodes de paiement
class _PaymentMethodTile extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _PaymentMethodTile({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  State<_PaymentMethodTile> createState() => _PaymentMethodTileState();
}

class _PaymentMethodTileState extends State<_PaymentMethodTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _animationController.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _animationController.reverse();
  }

  void _onTapCancel() {
    _animationController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onPressed,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    widget.color.withOpacity(0.2),
                    widget.color.withOpacity(0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: widget.color.withOpacity(0.4),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: Colors.white.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: widget.color.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(widget.icon, size: 24, color: widget.color),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.label,
                    style: TextStyle(
                      color: widget.color,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// Page de détails de paiement
class PaymentDetailsPage extends StatefulWidget {
  final String method;
  final Map<String, dynamic> book;

  const PaymentDetailsPage({
    super.key,
    required this.method,
    required this.book,
  });

  @override
  State<PaymentDetailsPage> createState() => _PaymentDetailsPageState();
}

class _PaymentDetailsPageState extends State<PaymentDetailsPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _amountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _amountController.text = "${widget.book['prix']?.toString() ?? '0'} FCFA";
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF59E0B),
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Détails du paiement',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              decoration: const BoxDecoration(
                color: Color(0xFFF59E0B),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(32),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'Paiement via ${widget.method}',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Veuillez remplir les informations ci-dessous',
                    style: GoogleFonts.poppins(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Champs spécifiques selon la méthode
                    if (widget.method == 'Visa') ...[
                      _buildTextField(
                        controller: _phoneController,
                        label: 'Numéro de carte Visa',
                        hint: 'XXXX XXXX XXXX XXXX',
                        icon: Icons.credit_card_rounded,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDarkTextField(
                              controller: _expController,
                              label: "Date d'expiration",
                              hint: 'MM/AA',
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildDarkTextField(
                              controller: _cvvController,
                              label: 'CVV',
                              hint: '123',
                              icon: Icons.lock_outline,
                              obscureText: true,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      // Mobile Money (Orange, Wave)
                      _buildDarkTextField(
                        controller: _phoneController,
                        label: 'Numéro de téléphone (${_selectedMethod})',
                        hint: '+225 ...',
                        icon: Icons.phone_android,
                        keyboardType: TextInputType.phone,
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
                          backgroundColor: const Color(0xFF06B6D4), // Cyan
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          'Payer $price FCFA',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Footer text
                    Center(
                      child: Text(
                        'Paiement sécurisé par Stripe',
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF64748B),
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMethodTab(String method) {
    bool isSelected = _selectedMethod == method;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedMethod = method;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF06B6D4) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            method,
            style: GoogleFonts.poppins(
              color: isSelected ? Colors.white : Colors.grey[500],
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  Widget _buildDarkTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    IconData? icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.poppins(color: Colors.white30),
            filled: true,
            fillColor: const Color(0xFF1E293B),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF06B6D4),
                width: 1.5,
              ),
            ),
            suffixIcon: icon != null
                ? Icon(icon, color: Colors.white30, size: 20)
                : null,
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Ce champ est requis';
            }
            return null;
          },
        ),
      ],
    );
  }

  void _processPayment() async {
    if (_formKey.currentState!.validate()) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: Color(0xFF06B6D4)),
                const SizedBox(height: 24),
                Text(
                  'Traitement...',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
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

        final userLibrary = await libraryService.getUserLibrary(token);
        final bool isAlreadyOwned = userLibrary.any(
          (item) =>
              item.livreId == (widget.book['id']?.toString() ?? "") ||
              (item.livre != null &&
                  item.livre!.id == (widget.book['id']?.toString() ?? "")),
        );

        if (isAlreadyOwned) {
          if (!mounted) return;
          Navigator.of(context).pop();
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              title: Text(
                'Livre déjà possédé',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Text(
                'Vous possédez déjà ce livre dans votre bibliothèque.',
                style: GoogleFonts.poppins(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    final nav = Navigator.of(context);
                    if (nav.canPop()) nav.popUntil((route) => route.isFirst);
                    MainNavBar.mainNavBarKey.currentState
                        ?.navigateToMarketplace();
                  },
                  child: Text(
                    'OK',
                    style: GoogleFonts.poppins(color: const Color(0xFF06B6D4)),
                  ),
                ),
              ],
            ),
          );
          return;
        }

        // Générer des IDs fictifs pour la transaction et la référence
        final transactionId = "TRX-${DateTime.now().millisecondsSinceEpoch}";
        final referenceId = "REF-${DateTime.now().millisecondsSinceEpoch}";

        final double amount =
            double.tryParse(widget.book['prix']?.toString() ?? '0') ?? 0.0;

        // Skip payment creation if amount is 0 (Free book)
        if (amount > 0) {
          final payment = PaymentModel(
            id: "", // Sera généré par le backend
            utilisateurId: user.id,
            livreId: widget.book['id']?.toString() ?? "",
            methodePaiement: widget.method.toLowerCase().replaceAll(' ', '_'),
            transactionId: transactionId,
            referenceId: referenceId,
            montant: amount,
            creeLe: DateTime.now(),
          );

          print(
            "🚀 Tentative de création du paiement pour le livre: ${widget.book['id']}",
          );
          await paymentService.createPayment(payment, token);
          print("✅ Paiement créé avec succès");
        } else {
          print("🚀 Livre gratuit, étape de paiement ignorée.");
        }

        // ✅ Ajouter le livre à la bibliothèque de l'utilisateur
        print("📚 Tentative d'ajout du livre à la bibliothèque...");
        await libraryService.addToLibrary(
          widget.book['id']?.toString() ?? "",
          user.id,
          amount > 0 ? "achat" : "gratuit", // acquis_via adapté
          token,
        );
        print("✅ Livre ajouté à la bibliothèque avec succès");

        // ✅ Incrémenter le nombre de téléchargements
        print("📥 Incrémentation du nombre de téléchargements...");
        try {
          final bookService = BookService();
          final currentDownloads = widget.book['telechargements'] ?? 0;
          await bookService.updateBook(widget.book['id']?.toString() ?? "", {
            'telechargements': currentDownloads + 1,
          }, token);
          print("✅ Nombre de téléchargements incrémenté");
        } catch (e) {
          print("⚠️ Erreur lors de l'incrémentation des téléchargements: $e");
          // On ne bloque pas le processus si l'incrémentation échoue
        }

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
          SnackBar(
            content: Text("Erreur : ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
        setState(() {
          _secondsRemaining--;
        });
      } else {
        _timer.cancel();
        _navigateToLibrary();
      }
    });
  }

  void _navigateToLibrary() {
    if (!mounted) return;
    final nav = Navigator.of(context);
    if (nav.canPop()) nav.popUntil((route) => route.isFirst);
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
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF06B6D4).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Color(0xFF06B6D4),
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
                'Redirection vers votre bibliothèque dans $_secondsRemaining...',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: const Color(0xFF06B6D4),
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
                    backgroundColor: const Color(0xFF06B6D4),
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
