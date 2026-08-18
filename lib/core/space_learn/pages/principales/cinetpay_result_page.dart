import 'package:flutter/material.dart';
import 'package:space_learn_flutter/core/themes/app_dimensions.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/bookService.dart';
import 'package:space_learn_flutter/core/utils/token_storage.dart';
import '../principales/lecteur/accueil_lecteur_page.dart';
import '../widgets/details/reading_page.dart'; // Ajout de l'import

/// Page de résultat après un paiement CinetPay
class CinetpayResultPage extends StatelessWidget {
  final String status; // "ACCEPTED", "REFUSED", "PENDING"
  final Map<String, dynamic> book; // Ajout du livre complet
  final double montant;
  final String? paymentMethod;
  final String transactionId;

  const CinetpayResultPage({
    super.key,
    required this.status,
    required this.book,
    required this.montant,
    this.paymentMethod,
    required this.transactionId,
  });

  bool get isAccepted => status.toUpperCase() == 'ACCEPTED';
  bool get isRefused => status.toUpperCase() == 'REFUSED';

  /// La couleur de l'issue du paiement, prise dans la palette.
  ///
  /// L'écran utilisait `Colors.green`, `Colors.red` et `Colors.orange` — les
  /// teintes de Material, étrangères à la charte et identiques en clair comme
  /// en sombre, là où `success`, `error` et `warning` sont calibrées sur les
  /// deux fonds. C'est l'écran qui annonce à un lecteur qu'il vient de payer :
  /// il ne peut pas être le seul à ne pas ressembler à l'application.
  ///
  /// Une seule définition, appelée trois fois — la teinte du fond, celle du
  /// liseré et celle de l'icône ne peuvent plus diverger.
  static Color _couleurEtat(bool accepte, bool refuse) {
    if (accepte) return AppColors.success;
    if (refuse) return AppColors.error;
    return AppColors.warning;
  }

  @override
  Widget build(BuildContext context) {
    AppColors.suivreLeTheme(context);
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              // Icône de résultat animée
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 600),
                curve: Curves.elasticOut,
                builder: (ctx, val, child) =>
                    Transform.scale(scale: val, child: child),
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _couleurEtat(
                      isAccepted,
                      isRefused,
                    ).withValues(alpha: 0.15),
                    border: Border.all(
                      color: _couleurEtat(isAccepted, isRefused),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    isAccepted
                        ? Icons.check_circle_outline_rounded
                        : isRefused
                        ? Icons.cancel_outlined
                        : Icons.hourglass_top_rounded,
                    size: 52,
                    color: _couleurEtat(isAccepted, isRefused),
                  ),
                ),
              ),
              SizedBox(height: 32),
              Text(
                isAccepted
                    ? 'Paiement réussi !'
                    : isRefused
                    ? 'Paiement refusé'
                    : 'Paiement en attente',
                style: GoogleFonts.poppins(
                  color: AppColors.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 12),
              Text(
                isAccepted
                    ? 'Votre paiement de ${montant.toStringAsFixed(0)} XOF a été validé.\n"${book['titre'] ?? 'Livre inconnu'}" a été ajouté à votre bibliothèque.'
                    : isRefused
                    ? 'Votre paiement de ${montant.toStringAsFixed(0)} XOF a été refusé.\nVeuillez réessayer avec un autre moyen de paiement.'
                    : 'Votre paiement de ${montant.toStringAsFixed(0)} XOF est en cours de traitement.\nVous serez notifié dès sa validation.',
                style: GoogleFonts.poppins(
                  color: AppColors.textHint,
                  fontSize: 14,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 32),
              // Détails de la transaction
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.textPrimary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
                  border: Border.all(
                    color: AppColors.textPrimary.withValues(alpha: 0.08),
                  ),
                ),
                child: Column(
                  children: [
                    _buildDetailRow(
                      'Livre',
                      book['titre']?.toString() ?? 'Livre inconnu',
                    ),
                    SizedBox(height: 8),
                    _buildDetailRow(
                      'Montant',
                      '${montant.toStringAsFixed(0)} XOF',
                    ),
                    if (paymentMethod != null) ...[
                      SizedBox(height: 8),
                      _buildDetailRow('Méthode', paymentMethod!),
                    ],
                    SizedBox(height: 8),
                    _buildDetailRow(
                      'Transaction',
                      transactionId.length > 16
                          ? '${transactionId.substring(0, 16)}...'
                          : transactionId,
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // Bouton d'action principal
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () async {
                    if (isAccepted) {
                      Map<String, dynamic> bookToOpen = Map<String, dynamic>.from(book);
                      try {
                        final token = await TokenStorage.getToken();
                        final bookId = (book['id'] ?? book['ID'] ?? '').toString();
                        if (token != null && token.isNotEmpty && bookId.isNotEmpty) {
                          final freshBook = await BookService().getBookById(bookId, authToken: token);
                          bookToOpen = freshBook.toJson();
                        }
                      } catch (_) {
                        // Fallback silencieux vers les métadonnées du livre disponibles
                      }
                      if (context.mounted) {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => ReadingPage(book: bookToOpen),
                          ),
                        );
                      }
                    } else {
                      // Retour à l'accueil lecteur
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (_) => const HomePageLecteur(profileId: ''),
                        ),
                        (route) => false,
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isAccepted
                        ? AppColors.primary
                        : AppColors.textHint,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusInner,
                      ),
                    ),
                  ),
                  child: Text(
                    isAccepted ? 'Lire mon livre' : 'Retour à l\'accueil',
                    style: GoogleFonts.poppins(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(color: AppColors.textHint, fontSize: 12),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
