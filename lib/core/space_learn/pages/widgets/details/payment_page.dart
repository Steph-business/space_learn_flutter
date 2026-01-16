import 'package:flutter/material.dart';

import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/themes/app_text_styles.dart';

class PaymentPage extends StatefulWidget {
  final Map<String, dynamic> book;

  const PaymentPage({super.key, required this.book});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: const Text(
          'Paiement',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Résumé détaillé de la commande
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.book,
                        size: 40,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.book['title'] ?? '',
                              style: AppTextStyles.subheading,
                            ),
                            Text(
                              'Par ${widget.book['author'] ?? ''}',
                              style: AppTextStyles.bodyText2,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Informations supplémentaires sur le livre
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Genre: ${widget.book['genre'] ?? 'Non spécifié'}',
                              style: AppTextStyles.bodyText2,
                            ),
                            Text(
                              'Pages: ${widget.book['pages'] ?? 'N/A'}',
                              style: AppTextStyles.bodyText2,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${widget.book['price'] ?? 'Prix non disponible'}',
                        style: AppTextStyles.heading.copyWith(
                          color: AppColors.primary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  if (widget.book['description'] != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      widget.book['description'],
                      style: AppTextStyles.bodyText2.copyWith(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 30),

            // Toutes les méthodes de paiement
            Text(
              'Choisissez votre méthode de paiement',
              style: AppTextStyles.subheading,
            ),
            const SizedBox(height: 16),

            // 4 méthodes de paiement alignées horizontalement
            SizedBox(
              height: 70,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  SizedBox(
                    width: 70,
                    child: _PaymentMethodTile(
                      label: 'Carte Visa',
                      icon: Icons.credit_card,
                      color: AppColors.primary,
                      onPressed: () => _selectPaymentMethod('Visa'),
                    ),
                  ),
                  SizedBox(
                    width: 70,
                    child: _PaymentMethodTile(
                      label: 'PayPal',
                      icon: Icons.paypal,
                      color: Colors.blue,
                      onPressed: () => _selectPaymentMethod('PayPal'),
                    ),
                  ),
                  SizedBox(
                    width: 70,
                    child: _PaymentMethodTile(
                      label: 'Orange Money',
                      icon: Icons.phone_android,
                      color: Colors.orange,
                      onPressed: () => _selectPaymentMethod('Orange Money'),
                    ),
                  ),
                  SizedBox(
                    width: 70,
                    child: _PaymentMethodTile(
                      label: 'Wave',
                      icon: Icons.waves,
                      color: Colors.blue,
                      onPressed: () => _selectPaymentMethod('Wave'),
                    ),
                  ),
                ],
              ),
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
    _amountController.text = widget.book['price']?.toString() ?? '';
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
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text(
          'Paiement via ${widget.method}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Résumé de la commande
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.book, size: 40, color: AppColors.primary),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.book['title'] ?? '',
                            style: AppTextStyles.subheading,
                          ),
                          Text(
                            'Par ${widget.book['author'] ?? ''}',
                            style: AppTextStyles.bodyText2,
                          ),
                          Text(
                            '${widget.book['price'] ?? 'Prix non disponible'}',
                            style: AppTextStyles.heading.copyWith(
                              color: AppColors.primary,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // Informations de paiement selon la méthode
              Text(
                'Informations de paiement - ${widget.method}',
                style: AppTextStyles.subheading,
              ),
              const SizedBox(height: 16),

              // Champs spécifiques selon la méthode
              if (widget.method == 'Visa') ...[
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Numéro de carte Visa',
                    hintText: 'XXXX XXXX XXXX XXXX',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.credit_card),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Veuillez entrer le numéro de votre carte';
                    }
                    if (value.length < 16) {
                      return 'Numéro de carte invalide';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Date d\'expiration',
                    hintText: 'MM/YY',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  keyboardType: TextInputType.datetime,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Veuillez entrer la date d\'expiration';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'CVV',
                    hintText: 'XXX',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Veuillez entrer le CVV';
                    }
                    if (value.length < 3) {
                      return 'CVV invalide';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Adresse email',
                    hintText: 'votre.email@example.com',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Veuillez entrer votre adresse email';
                    }
                    if (!RegExp(
                      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                    ).hasMatch(value)) {
                      return 'Adresse email invalide';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ] else if (widget.method == 'PayPal' ||
                  widget.method == 'Apple Pay' ||
                  widget.method == 'Google Pay') ...[
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Adresse email',
                    hintText: 'votre.email@example.com',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Veuillez entrer votre adresse email';
                    }
                    if (!RegExp(
                      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                    ).hasMatch(value)) {
                      return 'Adresse email invalide';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ] else ...[
                // Méthodes mobiles africaines
                TextFormField(
                  controller: _phoneController,
                  decoration: InputDecoration(
                    labelText: 'Numéro de téléphone ${widget.method}',
                    hintText: _getPhoneHint(widget.method),
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Veuillez entrer votre numéro de téléphone';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],

              // Montant
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Montant',
                  hintText: '0.00',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.attach_money),
                ),
                keyboardType: TextInputType.number,
                readOnly: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Montant requis';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 30),

              // Bouton de paiement
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _processPayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    'Payer avec ${widget.method}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Note
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _getPaymentNote(widget.method),
                  style: AppTextStyles.bodyText2,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getPhoneHint(String method) {
    switch (method) {
      case 'Orange Money':
        return '+225 XX XX XX XX XX';
      case 'Moov Money':
        return '+225 XX XX XX XX XX';
      case 'Wave':
        return '+225 XX XX XX XX XX';
      case 'MTN Money':
        return '+225 XX XX XX XX XX';
      default:
        return '+225 XX XX XX XX XX';
    }
  }

  String _getPaymentNote(String method) {
    switch (method) {
      case 'Visa':
        return 'Paiement sécurisé par carte Visa. Vos informations sont cryptées et protégées.';
      case 'PayPal':
        return 'Vous serez redirigé vers PayPal pour finaliser le paiement.';
      case 'Apple Pay':
        return 'Paiement rapide et sécurisé avec Apple Pay.';
      case 'Google Pay':
        return 'Paiement rapide et sécurisé avec Google Pay.';
      case 'Orange Money':
        return 'Confirmez le paiement sur votre application Orange Money.';
      case 'Moov Money':
        return 'Confirmez le paiement sur votre application Moov Money.';
      case 'Wave':
        return 'Confirmez le paiement sur votre application Wave.';
      case 'MTN Money':
        return 'Confirmez le paiement sur votre application MTN Money.';
      default:
        return 'Paiement sécurisé.';
    }
  }

  void _processPayment() {
    if (_formKey.currentState!.validate()) {
      // Simulation du traitement du paiement
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Traitement du paiement...'),
            ],
          ),
        ),
      );

      // Simuler un délai de traitement
      Future.delayed(const Duration(seconds: 2), () {
        Navigator.of(context).pop(); // Fermer le dialog

        // Naviguer vers la page de confirmation
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentConfirmationPage(book: widget.book),
          ),
        );
      });
    }
  }
}

// Page de confirmation de paiement
class PaymentConfirmationPage extends StatelessWidget {
  final Map<String, dynamic> book;

  const PaymentConfirmationPage({super.key, required this.book});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 100),
              const SizedBox(height: 24),
              Text(
                'Paiement réussi !',
                style: AppTextStyles.heading,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Votre achat de "${book['title']}" a été confirmé.',
                style: AppTextStyles.bodyText1,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Le livre a été ajouté à votre bibliothèque.',
                style: AppTextStyles.bodyText2,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // Retourner à la page d'accueil ou bibliothèque
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    'Retour à l\'accueil',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  // Naviguer vers la bibliothèque
                  Navigator.of(context).popUntil((route) => route.isFirst);
                  // Ici, on pourrait naviguer vers la bibliothèque si nécessaire
                },
                child: Text(
                  'Voir ma bibliothèque',
                  style: TextStyle(
                    color: AppColors.primary,
                    decoration: TextDecoration.underline,
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
