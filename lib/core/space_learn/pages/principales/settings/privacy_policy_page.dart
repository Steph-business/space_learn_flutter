import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/utils/contact.dart';

/// LA PAGE DE CONFIDENTIALITÉ, ET CE QU'ELLE DISAIT DE FAUX.
///
/// Trois défauts, dont un grave.
///
/// LE GRAVE : « Toutes vos transactions et données personnelles sont cryptées
/// de bout en bout. » C'était faux, et le dépôt le documentait lui-même à
/// vingt lignes d'intervalle — voir l'avertissement de `main.dart`, « Dit tout
/// haut que l'application parle EN CLAIR à une adresse publique » : les deux
/// serveurs écoutent 8083 et 8084 hors du proxy, et « un jeton de session, un
/// mot de passe et un OTP traversent le réseau lisibles par qui écoute le
/// Wi-Fi ». Une application qui encaisse des paiements promettait donc à ses
/// utilisateurs une garantie exactement inverse de ce que son propre code
/// décrit. Ce n'est pas une imprécision de rédaction : c'est la seule phrase
/// de l'application sur laquelle quelqu'un pourrait fonder une décision de
/// confiance.
///
/// La phrase ne revient PAS sous une forme atténuée. On ne remplace pas une
/// promesse fausse par une promesse vague ; on dit ce qui est vrai — le mot de
/// passe n'est pas conservé en clair, aucune coordonnée bancaire ne transite
/// par nos serveurs — et l'on se tait sur le reste. Le jour où le trafic
/// passera en HTTPS *et* où une version reconstruite de l'application sera
/// installée (les deux, dans cet ordre : un APK déjà posé sur un téléphone ne
/// se rattrape pas à distance), la phrase sur le transport pourra être ajoutée.
/// Pas avant.
///
/// LE DEUXIÈME : deux interrupteurs de consentement qui ne consentaient à
/// rien. « Partager les statistiques d'utilisation » et « Recommandations
/// personnalisées » n'étaient lus par personne, n'étaient enregistrés nulle
/// part — ils repartaient à leur valeur d'usine au lancement suivant — et
/// chaque bascule affichait « Préférences mises à jour ». Aucun SDK
/// d'analytique n'existe dans `pubspec.yaml` : il n'y avait pas même de
/// collecte à refuser. Un interrupteur de consentement qui ne gouverne rien
/// est pire que son absence : il fabrique la trace d'un choix qui n'a pas eu
/// lieu. Ils sont retirés. Le jour où une collecte existera, le réglage
/// reviendra AVEC elle.
///
/// LE TROISIÈME : trois paragraphes de remplissage là où le site porte une
/// vraie politique en cinq sections. Le texte ci-dessous est celui du site
/// (`Stepace_learn_web/src/app/politique-de-confidentialite/page.tsx`), moins
/// la même phrase fausse sur le chiffrement, qui y figurait aussi.
///
/// POURQUOI RECOPIER PLUTÔT QUE POINTER. Un lien vers la politique en ligne
/// serait la bonne réponse — une source unique, corrigible sans reconstruire
/// l'application. Il suppose un site public : le domaine est acheté, le site
/// n'est pas encore déployé. Un lien mort dans une page de confidentialité
/// vaut moins que le texte lui-même. À rebrancher le jour du déploiement.
class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  /// La date que porte la politique du site. Les deux doivent rester d'accord.
  static const String _derniereMiseAJour = "22 juillet 2026";

  @override
  Widget build(BuildContext context) {
    AppColors.suivreLeTheme(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark
          ? AppColors.scaffoldBackground
          : const Color.fromARGB(255, 250, 249, 246),
      appBar: AppBar(
        backgroundColor: AppColors.scaffoldBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.accentInk),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          "Confidentialité",
          style: GoogleFonts.poppins(
            color: isDark ? Colors.white : AppColors.accentInk,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            "Politique de confidentialité",
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Dernière mise à jour : $_derniereMiseAJour — plateforme et "
            "applications Space Learn.",
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 28),

          _Section(
            titre: "1. Introduction",
            corps:
                "La présente politique s'applique au site Space Learn et à ses "
                "applications mobiles. Elle décrit les données que nous "
                "recueillons, l'usage que nous en faisons, et les droits dont "
                "vous disposez sur elles.",
          ),
          _Section(
            titre: "2. Données collectées",
            corps:
                "Compte : nom complet, adresse électronique, rôle (lecteur ou "
                "auteur) et identifiant de profil.\n\n"
                "Lecture : progression, marque-pages, ouvrages ajoutés à votre "
                "bibliothèque et historique d'activité.\n\n"
                "Paiement : les références de transaction CinetPay et Mobile "
                "Money. Aucune coordonnée bancaire brute n'est conservée sur "
                "nos serveurs.",
          ),
          _Section(
            titre: "3. Conservation et sécurité",
            // CE QUI EST ÉCRIT ICI DOIT ÊTRE VÉRIFIABLE DANS LE CODE.
            //
            // L'empreinte du mot de passe : space_learn_auth, bcrypt à
            // l'inscription comme au changement. Les coordonnées de paiement :
            // le parcours passe par CinetPay, qui les reçoit directement — le
            // serveur ne voit qu'un identifiant de transaction.
            //
            // RIEN sur le transport, tant qu'il n'est pas chiffré : voir
            // l'en-tête de ce fichier.
            corps:
                "Votre mot de passe n'est jamais conservé en clair : nos "
                "serveurs n'en gardent qu'une empreinte irréversible, et "
                "personne — nous compris — ne peut le relire.\n\n"
                "Les paiements sont traités par CinetPay : vos coordonnées de "
                "paiement lui sont remises directement et ne transitent pas "
                "par nos serveurs, qui n'en conservent que la référence de "
                "transaction.\n\n"
                "Vos données ne sont ni vendues ni communiquées à des tiers à "
                "des fins publicitaires.",
          ),
          _Section(
            titre: "4. Suppression de compte et droit d'effacement",
            corps:
                "Vous disposez d'un droit d'accès, de rectification et "
                "d'effacement de vos données. La suppression se demande depuis "
                "les Réglages, dans l'application comme sur le site.\n\n"
                "La fermeture prend effet immédiatement. Vos données "
                "personnelles sont effacées trente jours plus tard ; d'ici là, "
                "vous reconnecter annule la suppression.\n\n"
                "S'il vous reste une somme à percevoir, l'effacement est "
                "retenu jusqu'à son versement : une créance ne s'éteint pas "
                "avec le compte.",
          ),
          _Section(
            titre: "5. Contact",
            corps:
                "Pour toute question sur vos données, ou pour exercer l'un de "
                "ces droits, écrivez-nous à $adresseContact depuis l'adresse "
                "associée à votre compte.",
            dernier: true,
          ),
        ],
      ),
    );
  }
}

/// Un titre et son texte, au même gabarit partout.
class _Section extends StatelessWidget {
  const _Section({
    required this.titre,
    required this.corps,
    this.dernier = false,
  });

  final String titre;
  final String corps;
  final bool dernier;

  @override
  Widget build(BuildContext context) {
    AppColors.suivreLeTheme(context);
    /* L'appel passe AVANT ce commentaire, et ce n'est pas du style : la
       règle 6 de `coherence_couleurs_test` cherche `suivreLeTheme` dans les
       200 premiers caractères qui suivent l'ouverture du `build`, et un
       paragraphe posé devant l'en pousse dehors. Sans cet abonnement, un
       widget garde la palette du rendu où il est né et reste sombre après un
       passage en clair — c'est ce test qui a rattrapé l'oubli. */
    return Padding(
      padding: EdgeInsets.only(bottom: dernier ? 24 : 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titre,
            style: GoogleFonts.poppins(
              fontSize: 15.5,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            corps,
            style: GoogleFonts.poppins(
              fontSize: 13.5,
              height: 1.6,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
