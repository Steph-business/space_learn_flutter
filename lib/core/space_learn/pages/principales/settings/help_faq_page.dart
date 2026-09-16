import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:space_learn_flutter/core/themes/app_dimensions.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/utils/app_notifications.dart';
import 'package:space_learn_flutter/core/utils/contact.dart';
import 'package:space_learn_flutter/core/services/onboarding_guide_service.dart';
import 'package:space_learn_flutter/core/themes/layout/nav_bar_lecteur.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/settings/user_guide_page.dart';

class HelpFaqPage extends StatelessWidget {
  /// Le parcours de la personne qui consulte.
  ///
  /// Sans lui, le lien « guide d'utilisation » de cette page ouvrait toujours
  /// le parcours LECTEUR — y compris pour un auteur venu de ses propres
  /// réglages, avec une question d'auteur.
  final bool estAuteur;

  const HelpFaqPage({super.key, this.estAuteur = false});

  @override
  Widget build(BuildContext context) {
    AppColors.suivreLeTheme(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark
          ? AppColors.scaffoldBackground
          : Color.fromARGB(255, 250, 249, 246),
      appBar: AppBar(
        backgroundColor: AppColors.scaffoldBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.accentInk),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          "Aide & FAQ",
          style: GoogleFonts.poppins(
            color: AppColors.accentInk,
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
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 20),
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
          const SizedBox(height: 28),

          // Manuel & Guide Utilisateur
          Card(
            color: AppColors.accentInk.withValues(alpha: 0.10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
              side: BorderSide(
                color: AppColors.accentInk.withValues(alpha: 0.35),
                width: 1.2,
              ),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.accentInk.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.menu_book_rounded,
                  color: AppColors.accentInk,
                  size: 24,
                ),
              ),
              title: Text(
                "Guide & Manuel d'utilisation",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
              ),
              subtitle: Text(
                "Consulter le guide complet pour les lecteurs et les auteurs.",
                style: GoogleFonts.poppins(
                  color: AppColors.textSecondary,
                  fontSize: 12.5,
                ),
              ),
              trailing: Icon(
                Icons.arrow_forward_ios_rounded,
                color: AppColors.accentInk,
                size: 20,
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UserGuidePage(estAuteur: estAuteur),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          // Guide interactif
          Card(
            color: AppColors.accentInk.withValues(alpha: 0.08),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
              side: BorderSide(
                color: AppColors.purple.withOpacity(0.35),
                width: 1.2,
              ),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.purple.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.explore_outlined,
                  color: AppColors.accentInk,
                  size: 24,
                ),
              ),
              title: Text(
                "Visite guidée de l'application",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
              ),
              subtitle: Text(
                "Revoir le tutoriel interactif pour redécouvrir les fonctionnalités clés.",
                style: GoogleFonts.poppins(
                  color: AppColors.textSecondary,
                  fontSize: 12.5,
                ),
              ),
              trailing: Icon(
                Icons.play_circle_fill,
                color: AppColors.accentInk,
                size: 28,
              ),
              onTap: () async {
                await OnboardingGuideService.resetHomeTour();
                if (context.mounted) {
                  AppNotifications.showSnackBar(
                    context,
                    message: "Visite guidée réactivée ! Redirection...",
                    isSuccess: true,
                  );
                  Navigator.of(context).pop();
                  MainNavBar.mainNavBarKey.currentState?.goHome();
                }
              },
            ),
          ),
          const SizedBox(height: 32),
          Text(
            "Vous ne trouvez pas de réponse ?",
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 12),
          Card(
            color: AppColors.cardBackground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
            ),
            child: ListTile(
              leading: Icon(
                Icons.mail_outline,
                color: AppColors.accentInk,
                size: 28,
              ),
              title: Text(
                "Contacter l'assistance",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              // L'ADRESSE EST ÉCRITE, ELLE N'EST PAS SEULEMENT OUVRABLE.
              //
              // C'est ici qu'aboutissent les deux entrées « Contacter le
              // support » des réglages, et l'application n'a jamais contenu la
              // moindre adresse, alors que le site l'affiche depuis toujours
              // (Stepace_learn_web, src/lib/contact.ts). Un lien qui
              // s'ouvre ne remplace pas une adresse qu'on peut lire et recopier
              // — un téléphone sans application de messagerie configurée est le
              // cas courant, pas l'exception.
              // CE QUE LE SUPPORT COUVRE, ET CE QU'IL NE COUVRE PLUS. La
              // suppression de compte s'annule maintenant en SE RECONNECTANT,
              // par mot de passe ou avec Google (space_learn_auth, login.go et
              // oauth_google.go) : écrire ici ne sert plus qu'aux deux cas
              // qu'une connexion ne rouvre pas — le délai de trente jours
              // écoulé, et l'archivage prononcé par l'administration. Le
              // commentaire ci-dessus annonçait le contraire, et c'était le
              // monde d'avant.
              subtitle: Text(
                "Écrivez-nous à $adresseContact — nous vous répondrons dans "
                "les plus brefs délais.",
                style: GoogleFonts.poppins(color: AppColors.textSecondary),
              ),
              trailing: Icon(Icons.arrow_forward_ios, size: 14),
              onTap: () => _ecrireAuSupport(context),
            ),
          ),
        ],
      ),
    );
  }

  /// Ouvre l'application de messagerie sur un courriel au support.
  ///
  /// L'entrée annonçait « Ouverture de votre application de messagerie... »
  /// en vert, et n'ouvrait RIEN : aucun appel, aucun lien, un succès annoncé
  /// pour un geste qui n'avait pas lieu. On n'annonce plus rien à l'avance —
  /// la messagerie qui s'affiche est sa propre confirmation — et quand aucune
  /// application ne répond, on redonne l'adresse plutôt qu'un appui sans effet.
  Future<void> _ecrireAuSupport(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: adresseContact,
      queryParameters: const {'subject': 'Aide Space Learn'},
    );

    var ouvert = false;
    try {
      ouvert = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // launchUrl lève quand aucune application ne répond : même issue, même
      // message que si elle avait simplement rendu `false`.
      ouvert = false;
    }

    if (ouvert || !context.mounted) return;
    AppNotifications.showSnackBar(
      context,
      message:
          "Aucune application de messagerie sur cet appareil. "
          "Écrivez-nous à $adresseContact.",
      isError: true,
    );
  }

  Widget _buildFaqItem(BuildContext context, String question, String answer) {
    return Card(
      color: AppColors.cardBackground,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusInner),
      ),
      child: ExpansionTile(
        title: Text(
          question,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: AppColors.textPrimary,
          ),
        ),
        iconColor: AppColors.primary,
        collapsedIconColor: AppColors.textHint,
        childrenPadding: const EdgeInsets.all(16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            answer,
            style: GoogleFonts.poppins(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
