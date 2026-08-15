import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/utils/app_notifications.dart';
import 'package:space_learn_flutter/core/themes/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:space_learn_flutter/core/themes/app_dimensions.dart';
import 'dart:async' as java_timer;
import 'package:google_fonts/google_fonts.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/authServices.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/paymentService.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/libraryService.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/bookService.dart';
import 'package:space_learn_flutter/core/utils/token_storage.dart';
import 'package:space_learn_flutter/core/utils/profile_storage.dart';
import 'package:space_learn_flutter/core/themes/layout/nav_bar_lecteur.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/cinetpay_webview_page.dart';

class PaymentPage extends StatefulWidget {
  final Map<String, dynamic> book;

  const PaymentPage({super.key, required this.book});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AppColors.suivreLeTheme(context);
    final rawPrix = widget.book['prix'];
    final bool isFree =
        rawPrix == 0 ||
        rawPrix == '0' ||
        rawPrix == null ||
        rawPrix == 'Gratuit';

    if (isFree) {
      return Scaffold(
        backgroundColor: AppColors.darkSurface,
        appBar: AppBar(
          backgroundColor: AppColors.darkSurface,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios,
              color: AppColors.textPrimary,
              size: 20,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text('Ouvrage Gratuit', style: AppTextStyles.subtitle),
          centerTitle: true,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.card_giftcard,
                    color: AppColors.success,
                    size: 64,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  "Cet ouvrage est gratuit !",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "L'auteur a choisi d'offrir \"${widget.book['titre'] ?? 'cet ouvrage'}\" à tous ses lecteurs. Aucune transaction financière n'est requise.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        final token = await TokenStorage.getToken();
                        final profileId =
                            await ProfileStorage.getSelectedProfile() ?? '';
                        if (token != null) {
                          final bookId = widget.book['id']?.toString() ?? '';
                          if (bookId.isNotEmpty) {
                            await LibraryService().acquerirGratuitement(
                              bookId,
                              token,
                            );
                          }
                        }
                      } catch (_) {}
                      if (context.mounted) {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (_) => const MainNavBar()),
                        );
                      }
                    },
                    icon: const Icon(Icons.auto_stories),
                    label: Text(
                      "Ajouter & Lire gratuitement",
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusCard,
                        ),
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

    final String price = widget.book['prix']?.toString() ?? '9,99';
    final String currency = 'FCFA';

    return Scaffold(
      backgroundColor: AppColors.darkSurface, // Dark slate background
      appBar: AppBar(
        backgroundColor: AppColors.darkSurface,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            color: AppColors.textPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Paiement Sécurisé', style: AppTextStyles.subtitle),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Book Summary Card
            _buildBookSummary(price, currency),

            SizedBox(height: 30),
            Divider(
              color: AppColors.textPrimary.withOpacity(0.05),
              thickness: 1,
            ),
            SizedBox(height: 30),

            // Le choix de l'opérateur se fait sur la page CinetPay, qui
            // présente toutes les méthodes actives du pays — Orange Money,
            // MTN, Moov, Wave, cartes. Les rappeler ici imposerait de
            // maintenir cette liste à jour, et de saisir des coordonnées
            // bancaires que nous ne devons de toute façon jamais manipuler.
            Text(
              'Moyens de paiement',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Vous choisirez votre opérateur — Orange Money, MTN, Moov, Wave '
              'ou carte bancaire — sur la page de paiement sécurisée.',
              style: AppTextStyles.greyMedium12,
            ),

            SizedBox(height: 48),

            // Pay Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _processPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryLight,
                  foregroundColor: AppColors.onAccent,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusInner,
                    ),
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
                'Paiement 100% sécurisé ',
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
            borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
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
                  color: AppColors.accentInk,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _processPayment() async {
    // Plus rien à valider ici : les coordonnées de paiement sont saisies sur
    // la page CinetPay, pas dans l'application.
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          Center(child: CircularProgressIndicator(color: AppColors.accentInk)),
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

      final String auteurId =
          widget.book['auteur_id']?.toString() ??
          widget.book['auteurId']?.toString() ??
          "";
      final String auteurNom = widget.book['authorName']?.toString() ?? "";
      final bool isAuthor =
          (auteurId.isNotEmpty && auteurId == user.id) ||
          (auteurNom.isNotEmpty &&
              auteurNom.trim().toLowerCase() ==
                  user.nomComplet.trim().toLowerCase());

      if (!mounted) return;

      if (isAuthor) {
        Navigator.of(context).pop();
        AppNotifications.showPremiumDialog(
          context,
          title: "Auteur de l'ouvrage",
          message:
              "Vous êtes l'auteur de ce livre. Vous y avez accès gratuitement sans avoir besoin de l'acheter.",
          confirmText: "Compris",
          isSuccess: true,
        );
        return;
      }

      if (isAlreadyOwned) {
        Navigator.of(context).pop();
        _showOwnedDialog();
        return;
      }

      final double amount =
          double.tryParse(widget.book['prix']?.toString() ?? '0') ?? 0.0;

      // Tout paiement passe par CinetPay : le lecteur y choisit son
      // opérateur parmi ceux actifs dans son pays.
      final paymentService = PaymentService();
      if (amount > 0) {
        final result = await paymentService.initiateCinetpayPayment(
          livreId: widget.book['id']?.toString() ?? "",
          montant: amount,
          authToken: token,
          customerName: user.nomComplet,
          customerEmail: user.email,
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
      await libraryService.acquerirGratuitement(
        widget.book['id']?.toString() ?? "",
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
      AppNotifications.showSnackBar(
        context,
        message: "Erreur : $e",
        isError: true,
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
            child: Text('OK', style: TextStyle(color: AppColors.accentInk)),
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
    AppColors.suivreLeTheme(context);
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
                  color: AppColors.accentInk,
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
                  color: AppColors.accentInk,
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
                    foregroundColor: AppColors.onAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusCard,
                      ),
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
