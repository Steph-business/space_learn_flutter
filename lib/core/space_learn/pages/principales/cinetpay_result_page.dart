import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:space_learn_flutter/core/themes/app_colors.dart';
import '../principales/lecteur/accueil_lecteur_page.dart';

/// Page de résultat après un paiement CinetPay
class CinetpayResultPage extends StatelessWidget {
  final String status; // "ACCEPTED", "REFUSED", "PENDING"
  final String livreTitle;
  final double montant;
  final String? paymentMethod;
  final String transactionId;

  const CinetpayResultPage({
    super.key,
    required this.status,
    required this.livreTitle,
    required this.montant,
    this.paymentMethod,
    required this.transactionId,
  });

  bool get isAccepted => status.toUpperCase() == 'ACCEPTED';
  bool get isRefused => status.toUpperCase() == 'REFUSED';

  @override
  Widget build(BuildContext context) {
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
                    color: isAccepted
                        ? Colors.green.withValues(alpha: 0.15)
                        : isRefused
                        ? Colors.red.withValues(alpha: 0.15)
                        : Colors.orange.withValues(alpha: 0.15),
                    border: Border.all(
                      color: isAccepted
                          ? Colors.green
                          : isRefused
                          ? Colors.red
                          : Colors.orange,
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
                    color: isAccepted
                        ? Colors.green
                        : isRefused
                        ? Colors.red
                        : Colors.orange,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                isAccepted
                    ? 'Paiement réussi !'
                    : isRefused
                    ? 'Paiement refusé'
                    : 'Paiement en attente',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                isAccepted
                    ? 'Votre paiement de ${montant.toStringAsFixed(0)} XOF a été validé.\n"$livreTitle" a été ajouté à votre bibliothèque.'
                    : isRefused
                    ? 'Votre paiement de ${montant.toStringAsFixed(0)} XOF a été refusé.\nVeuillez réessayer avec un autre moyen de paiement.'
                    : 'Votre paiement de ${montant.toStringAsFixed(0)} XOF est en cours de traitement.\nVous serez notifié dès sa validation.',
                style: GoogleFonts.poppins(
                  color: Colors.white60,
                  fontSize: 14,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              // Détails de la transaction
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Column(
                  children: [
                    _buildDetailRow('Livre', livreTitle),
                    const SizedBox(height: 8),
                    _buildDetailRow(
                      'Montant',
                      '${montant.toStringAsFixed(0)} XOF',
                    ),
                    if (paymentMethod != null) ...[
                      const SizedBox(height: 8),
                      _buildDetailRow('Méthode', paymentMethod!),
                    ],
                    const SizedBox(height: 8),
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
                  onPressed: () {
                    // Retour à l'accueil lecteur
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (_) => const HomePageLecteur(profileId: ''),
                      ),
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isAccepted
                        ? AppColors.primary
                        : Colors.white24,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    isAccepted ? 'Lire mon livre' : 'Retour à l\'accueil',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
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
          style: GoogleFonts.poppins(color: Colors.white38, fontSize: 12),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
