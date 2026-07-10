import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/utils/app_notifications.dart';

class HelpFaqPage extends StatelessWidget {
  const HelpFaqPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.scaffoldBackground : const Color.fromARGB(255, 250, 249, 246),
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.scaffoldBackground : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          "Aide & FAQ",
          style: GoogleFonts.poppins(
            color: isDark ? Colors.white : AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            "Comment pouvons-nous vous aider ?",
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 20),
          _buildFaqItem(
            context,
            "Comment télécharger un livre ?",
            "Pour télécharger un livre, rendez-vous sur la fiche du livre dans la boutique et cliquez sur l'icône de téléchargement. Une fois le téléchargement terminé, le livre sera accessible hors-connexion depuis votre bibliothèque.",
          ),
          _buildFaqItem(
            context,
            "Comment publier un livre en tant qu'auteur ?",
            "Si vous possédez un profil auteur, cliquez sur l'onglet 'Publier' dans le menu du bas. Remplissez ensuite le formulaire avec le titre, la description, la catégorie et téléversez votre fichier PDF ou ePUB.",
          ),
          _buildFaqItem(
            context,
            "Comment fonctionne le système de parrainage ?",
            "Vous pouvez partager votre lien ou code de parrainage avec vos amis. Dès qu'un nouvel utilisateur s'inscrit en l'utilisant, vous recevrez tous les deux des récompenses sur vos portefeuilles virtuels respectifs.",
          ),
          _buildFaqItem(
            context,
            "Quels sont les moyens de paiement acceptés ?",
            "Nous intégrons actuellement le service de paiement CinetPay qui accepte les cartes bancaires ainsi que les paiements par Mobile Money (Orange, MTN, Moov, Wave, etc.) selon votre pays de résidence.",
          ),
          const SizedBox(height: 40),
          Text(
            "Vous ne trouvez pas de réponse ?",
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            color: isDark ? AppColors.cardBackground : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: const Icon(Icons.mail_outline, color: AppColors.primary, size: 28),
              title: Text("Contacter l'assistance", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
              subtitle: Text("Nous vous répondrons dans les plus brefs délais.", style: GoogleFonts.poppins(color: isDark ? Colors.white70 : Colors.black54)),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              onTap: () {
                AppNotifications.showSnackBar(context, message: "Ouverture de votre application de messagerie...", isSuccess: true);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFaqItem(BuildContext context, String question, String answer) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      color: isDark ? AppColors.cardBackground : Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        title: Text(
          question,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        iconColor: AppColors.primary,
        collapsedIconColor: isDark ? Colors.white30 : Colors.black38,
        childrenPadding: const EdgeInsets.all(16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            answer,
            style: GoogleFonts.poppins(
              color: isDark ? Colors.white70 : Colors.black54,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
