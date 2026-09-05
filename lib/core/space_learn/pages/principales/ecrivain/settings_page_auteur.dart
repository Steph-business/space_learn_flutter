import 'package:flutter/material.dart';
import 'package:space_learn_flutter/core/themes/app_dimensions.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/themes/theme_provider.dart';
import 'package:space_learn_flutter/core/utils/app_notifications.dart';
import 'package:space_learn_flutter/core/utils/token_storage.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/authServices.dart';
import 'package:space_learn_flutter/core/utils/message_erreur.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/profilePage.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/base_settings_layout.dart';
import 'package:space_learn_flutter/core/utils/profile_storage.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/lecteur/accueil_lecteur_page.dart'
    as lecteurHome;

// Nouvelles pages de paramètres
import 'package:space_learn_flutter/core/space_learn/pages/principales/settings/password_change_page.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/settings/help_faq_page.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/settings/notification_settings_page.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/settings/privacy_policy_page.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/settings/language_selection_page.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/settings/publication_settings_page.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/settings/sales_report_page.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/settings/terms_of_use_page.dart';

/// Réglages de l'espace auteur.
///
/// Écran devenu STATEFUL pour une seule raison : « Passer au mode Lecteur »
/// n'est plus une écriture locale mais un appel réseau (POST
/// /utilisateurs/me/profil). Il lui fallait donc ce que possède la bascule
/// inverse (settings_page.dart) — un garde-fou anti-double-appui — et ce qui
/// lui manquait des deux côtés : un retour visible pendant l'attente.
class SettingsPageAuteur extends StatefulWidget {
  const SettingsPageAuteur({super.key});

  @override
  State<SettingsPageAuteur> createState() => _SettingsPageAuteurState();
}

class _SettingsPageAuteurState extends State<SettingsPageAuteur> {
  /// Empêche un second appel pendant que le serveur répond, et voile l'écran.
  ///
  /// Le dialogue de confirmation se referme AVANT l'appel (showPremiumDialog
  /// ferme puis exécute onConfirm) : l'écran des réglages restait affiché et
  /// inerte le temps de la requête. Deux appuis rapprochés lançaient deux
  /// SelectProfile, chacun régénérant un jeton, et le second pouvait arriver
  /// après la navigation.
  bool _basculeEnCours = false;

  @override
  Widget build(BuildContext context) {
    AppColors.suivreLeTheme(context);
    return Stack(
      children: [
        _construireLesReglages(context),
        // Le voile dit qu'il se passe quelque chose ET absorbe les appuis :
        // les deux moitiés du même problème.
        if (_basculeEnCours)
          Positioned.fill(
            child: AbsorbPointer(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.35),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
          ),
      ],
    );
  }

  Widget _construireLesReglages(BuildContext context) {
    return BaseSettingsLayout(
      title: "Paramètres Auteur",
      primaryAccentColor: AppColors.secondaryVariant,
      children: [
        // Section Profil
        SettingSectionHeader(
          title: "Profil",
          accentColor: AppColors.secondaryVariant,
        ),
        SettingItemTile(
          icon: Icons.person_outline_rounded,
          title: "Informations personnelles",
          subtitle: "Modifier vos informations d'auteur",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfilePage()),
            );
          },
        ),
        SettingItemTile(
          icon: Icons.photo_camera_outlined,
          title: "Photo de profil",
          subtitle: "Changer votre photo d'auteur",
          onTap: () {
            _pickProfilePhoto(context);
          },
        ),
        SettingItemTile(
          icon: Icons.switch_account_outlined,
          title: "Passer au mode Lecteur",
          subtitle: "Basculer vers votre espace lecteur",
          onTap: () => _switchToReaderMode(context),
        ),

        // Section Publication

        // Section Publication
        SettingSectionHeader(
          title: "Publication",
          accentColor: AppColors.secondaryVariant,
        ),
        SettingItemTile(
          icon: Icons.publish_outlined,
          title: "Paramètres de publication",
          subtitle: "Visibilité, prix, droits d'auteur",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const PublicationSettingsPage(),
              ),
            );
          },
        ),
        SettingItemTile(
          icon: Icons.analytics_outlined,
          title: "Rapports de ventes",
          subtitle: "Statistiques détaillées",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SalesReportPage()),
            );
          },
        ),

        // Section Application
        SettingSectionHeader(
          title: "Application",
          accentColor: AppColors.secondaryVariant,
        ),
        SettingItemTile(
          icon: Icons.language_outlined,
          title: "Langue",
          subtitle: "Français",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const LanguageSelectionPage(),
              ),
            );
          },
        ),
        SettingItemTile(
          icon: Icons.dark_mode_outlined,
          title: "Thème",
          subtitle: "Changer le thème de l'application",
          onTap: () {
            _showThemeSelectorDialog(context);
          },
        ),
        // L'auteur n'avait aucun accès à ses réglages de notification : la page
        // n'était construite qu'ici, côté lecteur, et toujours avec
        // `isAuthorMode: false`. Les alertes de vente étaient donc inatteignables.
        SettingItemTile(
          icon: Icons.notifications_outlined,
          title: "Notifications",
          subtitle: "Ventes, avis, rappels de lecture",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    const NotificationSettingsPage(isAuthorMode: true),
              ),
            );
          },
        ),

        // Section Sécurité
        SettingSectionHeader(
          title: "Sécurité",
          accentColor: AppColors.secondaryVariant,
        ),
        SettingItemTile(
          icon: Icons.lock_outline,
          title: "Mot de passe",
          subtitle: "Changer votre mot de passe",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const PasswordChangePage(),
              ),
            );
          },
        ),
        SettingItemTile(
          icon: Icons.security_outlined,
          title: "Confidentialité",
          subtitle: "Gérer vos données personnelles d'auteur",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const PrivacyPolicyPage(),
              ),
            );
          },
        ),

        // Section Support
        SettingSectionHeader(
          title: "Support",
          accentColor: AppColors.secondaryVariant,
        ),
        // Le guide de l'auteur et l'aide ont quitté cet écran : ils sont sous
        // l'icône « ? » de l'en-tête, atteignable depuis n'importe quelle page.
        SettingItemTile(
          icon: Icons.contact_support_outlined,
          title: "Contacter le support",
          subtitle: "Nous contacter",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const HelpFaqPage(estAuteur: true),
              ),
            );
          },
        ),

        // Section À propos
        SettingSectionHeader(
          title: "À propos",
          accentColor: AppColors.secondaryVariant,
        ),
        SettingItemTile(
          icon: Icons.description_outlined,
          title: "Conditions d'utilisation",
          subtitle: "Lire les conditions",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const TermsOfUsePage()),
            );
          },
        ),
        SettingItemTile(
          icon: Icons.info_outline,
          title: "Version de l'application",
          subtitle: "1.0.0",
          onTap: () {
            AppNotifications.showPremiumDialog(
              context,
              title: "Version de l'application",
              message:
                  "SpaceLearn Mobile (Auteur)\nVersion: 1.0.0\nConstruit avec amour par Steph-business.",
              confirmText: "Fermer",
              isSuccess: true,
            );
          },
        ),
      ],
    );
  }

  Future<void> _pickProfilePhoto(BuildContext context) async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (image == null) return;

      AppNotifications.showSnackBar(
        context,
        message: "Téléversement de l'image en cours...",
      );

      String? photoUrl;
      try {
        final bytes = await image.readAsBytes();
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';

        await Supabase.instance.client.storage
            .from('avatars')
            .uploadBinary(
              fileName,
              bytes,
              fileOptions: const FileOptions(
                contentType: 'image/jpeg',
                upsert: true,
              ),
            );

        photoUrl = Supabase.instance.client.storage
            .from('avatars')
            .getPublicUrl(fileName);
      } catch (_) {
        try {
          final bytes = await image.readAsBytes();
          final base64String = base64Encode(bytes);
          final extension = image.path.split('.').last;
          photoUrl = 'data:image/$extension;base64,$base64String';
        } catch (_) {
          AppNotifications.showSnackBar(
            context,
            message: "Erreur lors du traitement de l'image.",
            isError: true,
          );
          return;
        }
      }

      final token = await TokenStorage.getToken();
      if (token != null) {
        final authService = AuthService();
        final user = await authService.getUser(token);
        if (user != null) {
          await authService.updateProfileDetails(
            userId: user.id,
            profilePhoto: photoUrl,
          );
          AppNotifications.showSnackBar(
            context,
            message: "Photo de profil mise à jour !",
            isSuccess: true,
          );
        }
      }
    } catch (e) {
      AppNotifications.showSnackBar(
        context,
        message: "Erreur lors du choix de l'image.",
        isError: true,
      );
    }
  }

  void _showThemeSelectorDialog(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
              border: Border.all(
                color: isDark
                    ? AppColors.textHint
                    : Colors.black.withOpacity(0.05),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Sélectionner le thème",
                  style: GoogleFonts.poppins(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 16),
                _buildThemeOption(
                  context,
                  "Thème Clair",
                  ThemeMode.light,
                  Icons.light_mode_outlined,
                  themeProvider,
                ),
                _buildThemeOption(
                  context,
                  "Thème Sombre",
                  ThemeMode.dark,
                  Icons.dark_mode_outlined,
                  themeProvider,
                ),
                _buildThemeOption(
                  context,
                  "Thème Système",
                  ThemeMode.system,
                  Icons.phone_android_outlined,
                  themeProvider,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildThemeOption(
    BuildContext context,
    String title,
    ThemeMode mode,
    IconData icon,
    ThemeProvider themeProvider,
  ) {
    final isSelected = themeProvider.themeMode == mode;
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? AppColors.accentInk : (AppColors.textSecondary),
      ),
      title: Text(
        title,
        style: GoogleFonts.poppins(
          color: isSelected ? AppColors.accentInk : (AppColors.textPrimary),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check_circle, color: AppColors.accentInk)
          : null,
      onTap: () {
        themeProvider.setThemeMode(mode);
        Navigator.of(context).pop();
      },
    );
  }

  void _switchToReaderMode(BuildContext context) {
    // Rouvrir la confirmation pendant que la première est en vol n'aurait
    // aucun sens : on le dit au lieu de ne rien faire.
    if (_basculeEnCours) {
      AppNotifications.showSnackBar(
        context,
        message: "Bascule en cours, veuillez patienter…",
      );
      return;
    }
    AppNotifications.showPremiumDialog(
      context,
      title: "Mode Lecteur",
      message: "Voulez-vous vraiment basculer vers votre espace Lecteur ?",
      confirmText: "Basculer",
      cancelText: "Annuler",
      onConfirm: () => _executeSwitchToReaderMode(context),
    );
  }

  /// Bascule vers l'espace lecteur — côté SERVEUR, et pas seulement à l'écran.
  ///
  /// Cette bascule ne faisait que getUser puis une écriture locale du rôle :
  /// le profil en base et le rôle porté par le jeton restaient « auteur »,
  /// donc la bascule ne survivait pas à une reconnexion — même appareil ou
  /// autre — et l'écran lecteur tournait avec l'identifiant du profil AUTEUR.
  /// C'est exactement le défaut que la bascule inverse a corrigé
  /// (_executeSwitchToAuthorMode, settings_page.dart) : on demande le profil
  /// au serveur, on attend son accord, et on ne navigue qu'ensuite.
  Future<void> _executeSwitchToReaderMode(BuildContext context) async {
    // Même garde-fou que la bascule inverse (settings_page.dart), posé AVANT
    // l'await : le voile de build() suit le drapeau.
    if (_basculeEnCours) return;
    setState(() => _basculeEnCours = true);

    try {
      // Le serveur résout le profil par son libellé, et n'accepte que les
      // profils librement attribuables — « Lecteur » en fait partie. Le jeton
      // renvoyé porte le nouveau rôle ; le service l'enregistre.
      final tokenUser = await AuthService().updateProfileForUser("Lecteur");

      await ProfileStorage.saveSelectedProfileRole("lecteur");
      // Le nouveau profil (lecteur) remplace l'ancien dans le stockage : le
      // démarrage hors ligne route selon lui.
      await ProfileStorage.saveSelectedProfile(tokenUser.user.profilId);
      if (!context.mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => lecteurHome.HomePageLecteur(
            // L'identifiant du NOUVEAU profil, renvoyé par le serveur — pas
            // celui du profil auteur qu'on vient de quitter.
            profileId: tokenUser.user.profilId,
            userName: tokenUser.user.nomComplet,
          ),
        ),
        (route) => false,
      );
    } catch (e) {
      if (context.mounted) {
        // Le message du serveur dit la cause (profil refusé, compte inactif,
        // réseau) ; un « Erreur » générique ne dit rien à personne.
        AppNotifications.showSnackBar(
          context,
          message: messageLisible(
            e,
            repli: "Le passage en mode lecteur a échoué.",
          ),
          isError: true,
        );
      }
    } finally {
      // Après la navigation réussie, l'écran est démonté : le test évite le
      // setState sur un State disposé.
      if (mounted) setState(() => _basculeEnCours = false);
    }
  }
}
