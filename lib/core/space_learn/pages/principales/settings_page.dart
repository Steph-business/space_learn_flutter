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
import 'package:space_learn_flutter/core/space_learn/pages/principales/auth/bienvenue.dart';
import 'package:space_learn_flutter/core/utils/message_erreur.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/favoriteService.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/libraryService.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/readerStatsService.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/library_model.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/profilePage.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/readingPreferencesPage.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/base_settings_layout.dart';
import 'package:space_learn_flutter/core/utils/profile_storage.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/ecrivain/accueil_auteur_page.dart'
    as ecrivainHome;

// Nouvelles pages de paramètres
import 'package:space_learn_flutter/core/space_learn/pages/principales/settings/password_change_page.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/settings/help_faq_page.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/settings/privacy_policy_page.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/settings/language_selection_page.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/settings/download_manager_page.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/settings/notification_settings_page.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/settings/terms_of_use_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  int _favoritesCount = 0;

  /// Livres réellement terminés, tels que le serveur les compte.
  ///
  /// À ne pas confondre avec la taille de la bibliothèque : « Livres lus »
  /// affichait autrefois le nombre de livres POSSÉDÉS.
  int _livresLus = 0;
  int _inProgressCount = 0;

  /// Repli hors ligne : compter depuis la bibliothèque déjà chargée.
  ///
  /// La règle est celle du serveur — un livre possédé ET dont la progression
  /// atteint 100 %. La bibliothèque ne contient que des livres possédés, la
  /// jointure est donc implicite ici.
  int _compterLocalement(List<LibraryModel> livres, {required bool termines}) {
    return livres.where((b) {
      final progressions = b.livre?.progressions;
      if (progressions == null || progressions.isEmpty) return false;
      final pourcentage = progressions.first.pourcentage;
      return termines
          ? pourcentage >= 100
          : pourcentage > 0 && pourcentage < 100;
    }).length;
  }

  bool _isLoadingStats = true;

  /// Empêche un second appel pendant que le serveur répond. Sur un réseau lent,
  /// la boîte de dialogue se referme aussitôt et rien n'indique qu'il se passe
  /// quelque chose : sans ce garde-fou, on tape deux fois.
  bool _basculeEnCours = false;

  /// Même garde-fou pour la suppression du compte.
  ///
  /// Posé par setState, et non en douce : il éteint aussi l'entrée de la liste
  /// (« Suppression en cours… » au lieu d'un appui sans effet) le temps que le
  /// serveur réponde. Un champ ordinaire, que rien ne relisait à l'écran, ne
  /// faisait qu'avaler le second appui en silence.
  bool _suppressionEnCours = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final token = await TokenStorage.getToken();
      if (token != null) {
        final favService = FavoriteService();
        final libService = LibraryService();

        final favs = await favService.getFavorites(token);
        List<LibraryModel> libBooks = [];
        try {
          libBooks = await libService.getUserLibrary(token);
        } catch (_) {}

        // Le serveur compte les livres lus et en cours ; c'est lui qui fait foi.
        //
        // Cet écran affichait `libBooks.length` sous le libellé « Livres lus ».
        // C'est la TAILLE DE LA BIBLIOTHÈQUE : deux livres possédés, un seul
        // terminé — d'où « 1 » sur l'accueil et « 2 » ici, le même jour, pour
        // le même lecteur.
        //
        // « En cours » était pire encore : quand aucun livre n'était en cours,
        // on en affichait un quand même (`if (inProgress == 0) inProgress = 1`).
        // Un chiffre inventé est plus grave qu'un chiffre absent — il ne se
        // corrige jamais, puisque rien ne signale qu'il est faux.
        final bilan = await ReaderStatsService().lireBilan();

        if (mounted) {
          setState(() {
            _favoritesCount = favs.length;
            _livresLus =
                bilan?['lus'] ?? _compterLocalement(libBooks, termines: true);
            _inProgressCount =
                bilan?['en_cours'] ??
                _compterLocalement(libBooks, termines: false);
            _isLoadingStats = false;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingStats = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    AppColors.suivreLeTheme(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      children: [
        _construireLesReglages(context, isDark),
        // Le drapeau _basculeEnCours ne se voyait nulle part : la confirmation
        // se referme avant l'appel (showPremiumDialog ferme puis exécute
        // onConfirm), et l'écran restait affiché et inerte le temps de la
        // requête. Le voile le dit, et absorbe les appuis.
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

  Widget _construireLesReglages(BuildContext context, bool isDark) {
    return BaseSettingsLayout(
      title: "Paramètres",
      primaryAccentColor: AppColors.primary,
      children: [
        // Section Statistiques de lecture (Demandée par l'utilisateur)
        SettingSectionHeader(
          title: "Vos Statistiques",
          accentColor: AppColors.primary,
        ),
        _buildStatsCard(isDark),
        SizedBox(height: 10),

        // Section Profil
        SettingSectionHeader(title: "Profil", accentColor: AppColors.primary),
        SettingItemTile(
          icon: Icons.person_outline_rounded,
          title: "Informations personnelles",
          subtitle: "Modifier vos informations",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfilePage()),
            ).then((_) => _loadStats()); // Recharger après modification
          },
        ),
        SettingItemTile(
          icon: Icons.photo_camera_outlined,
          title: "Photo de profil",
          subtitle: "Changer votre photo",
          onTap: () {
            _pickProfilePhoto(context);
          },
        ),
        SettingItemTile(
          icon: Icons.switch_account_outlined,
          title: "Passer au mode Auteur",
          subtitle: "Basculer vers votre espace créateur",
          onTap: () => _switchToAuthorMode(context),
        ),

        // Section Lecture
        SettingSectionHeader(title: "Lecture", accentColor: AppColors.primary),
        SettingItemTile(
          icon: Icons.book_outlined,
          title: "Préférences de lecture",
          subtitle: "Police, taille du texte, thème",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ReadingPreferencesPage(),
              ),
            );
          },
        ),
        SettingItemTile(
          icon: Icons.notifications_outlined,
          title: "Notifications de lecture",
          subtitle: "Rappels de lecture, nouveaux chapitres",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    const NotificationSettingsPage(isAuthorMode: false),
              ),
            );
          },
        ),

        // Section Application
        SettingSectionHeader(
          title: "Application",
          accentColor: AppColors.primary,
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
        SettingItemTile(
          icon: Icons.download_outlined,
          title: "Téléchargements",
          subtitle: "Gérer les livres téléchargés",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const DownloadManagerPage(),
              ),
            );
          },
        ),

        // Section Sécurité
        SettingSectionHeader(title: "Sécurité", accentColor: AppColors.primary),
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
          subtitle: "Gérer vos données personnelles et lire la politique",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const PrivacyPolicyPage(),
              ),
            );
          },
        ),
        SettingItemTile(
          icon: Icons.delete_forever_outlined,
          title: "Supprimer mon compte",
          // Le libellé dit le contrat réel du serveur : désactivation
          // immédiate, purge définitive après un délai de grâce de 30 jours —
          // pas une suppression « irréversible » sur-le-champ.
          //
          // (Les accents s'écrivent en clair, comme dans tout le fichier : ce
          // bloc était le seul rédigé en échappements Unicode bruts —
          // illisible à la relecture, trace d'une réécriture interrompue.)
          subtitle: "Désactivation immédiate, suppression après 30 jours",
          onTap: () {
            // Un appui pendant que la demande est en vol ne tombe plus dans le
            // vide : le dialogue ne se rouvre pas, mais on dit pourquoi. Le
            // garde-fou anti-double-appui rendait la main sans un mot.
            if (_suppressionEnCours) {
              AppNotifications.showSnackBar(
                context,
                message: "Suppression en cours, veuillez patienter…",
              );
              return;
            }
            _showDeleteAccountDialog(context);
          },
        ),

        // Section Support
        //
        // Le guide d'utilisation a quitté cet écran : il est désormais sous
        // l'icône « ? » de l'en-tête, présente sur toutes les pages. On a
        // besoin d'un mode d'emploi au moment où l'on ne sait pas quoi faire,
        // pas au moment où l'on règle ses préférences.
        SettingSectionHeader(title: "Support", accentColor: AppColors.primary),
        SettingItemTile(
          icon: Icons.contact_support_outlined,
          title: "Contacter le support",
          subtitle: "Nous contacter",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const HelpFaqPage()),
            );
          },
        ),

        // Section À propos
        SettingSectionHeader(title: "À propos", accentColor: AppColors.primary),
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
                  "SpaceLearn Mobile\nVersion: 1.0.0\nConstruit avec amour par Steph-business.",
              confirmText: "Fermer",
              isSuccess: true,
            );
          },
        ),
      ],
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      // Le dialogue RESTE ouvert pendant l'appel, et ne se ferme plus d'un
      // appui à côté : c'est lui qui porte l'attente.
      //
      // Il se fermait auparavant avant même que la requête ne parte, et plus
      // rien ne bougeait à l'écran jusqu'à la réponse du serveur. Sur un
      // réseau lent, la personne rouvrait le dialogue et ré-appuyait : le
      // garde-fou anti-double-appui lui rendait alors la main sans le moindre
      // message — ni dialogue, ni snackbar. Pour un geste irréversible,
      // l'absence totale de retour est le pire des états. Même patron que
      // showLogoutDialog (base_settings_layout.dart) : bouton en attente,
      // actions désactivées.
      barrierDismissible: false,
      builder: (dialogContext) {
        bool enCours = false;
        return StatefulBuilder(
          builder: (contexteDuDialogue, setDialogState) {
            return PopScope(
              // Le bouton retour du système n'escamote pas l'attente non plus.
              canPop: !enCours,
              child: Dialog(
                backgroundColor: Colors.transparent,
                insetPadding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 24,
                ),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusPill,
                    ),
                    border: Border.all(
                      color: AppColors.textPrimary.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Warning icon
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.error.withValues(alpha: 0.12),
                          border: Border.all(
                            color: AppColors.error.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.warning_amber_rounded,
                          size: 28,
                          color: AppColors.error,
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Title
                      Text(
                        "Supprimer mon compte",
                        style: GoogleFonts.poppins(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      // Message
                      //
                      // La phrase ne promet QUE ce que le serveur fait.
                      // DeleteAccount (space_learn_auth, controllers/user.go)
                      // ne touche que trois champs : statut « supprime », nom
                      // affiché remplacé, date de suppression — et
                      // PeutOuvrirSession referme la porte aussitôt. L'e-mail,
                      // le pseudo, le téléphone, la biographie et la photo
                      // restent en base pendant le délai de grâce : parler
                      // d'« anonymisation » de toutes les données personnelles
                      // était un second mensonge, plus petit que le premier
                      // (« suppression irréversible immédiate ») mais un
                      // mensonge quand même.
                      Text(
                        "Votre compte sera immédiatement désactivé : vous ne pourrez plus vous y connecter et votre nom cessera d'être affiché. Vos données sont conservées pendant un délai de grâce de 30 jours, puis supprimées définitivement.",
                        style: GoogleFonts.poppins(
                          color: AppColors.textPrimary.withValues(alpha: 0.7),
                          fontSize: 14,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      // Actions
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: TextButton(
                                onPressed: enCours
                                    ? null
                                    : () => Navigator.pop(dialogContext),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.textHint,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppDimensions.radiusInner,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  "Annuler",
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: ElevatedButton(
                                onPressed: enCours
                                    ? null
                                    : () async {
                                        setDialogState(() => enCours = true);
                                        if (mounted) {
                                          setState(
                                            () => _suppressionEnCours = true,
                                          );
                                        }
                                        await _executerLaSuppression(
                                          dialogContext,
                                        );
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.error,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppDimensions.radiusInner,
                                    ),
                                  ),
                                ),
                                child: enCours
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      )
                                    : Text(
                                        "Supprimer",
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Enchaîne l'appel au serveur, la fermeture du dialogue d'attente et
  /// l'annonce du résultat.
  ///
  /// Isolée du `builder` pour que le `await` ne vive pas au milieu de l'arbre
  /// de widgets : le dialogue se ferme ici, dans tous les cas, avant que quoi
  /// que ce soit ne s'affiche.
  Future<void> _executerLaSuppression(BuildContext dialogContext) async {
    String? messageDuServeur;
    Object? echec;
    try {
      messageDuServeur = await _demanderLaSuppression();
    } catch (e) {
      echec = e;
    }

    if (dialogContext.mounted) {
      Navigator.of(dialogContext).pop();
    }
    if (!mounted) return;
    setState(() => _suppressionEnCours = false);

    if (echec != null) {
      // Échec = rien n'a changé, ni sur le serveur ni en local. On affiche la
      // raison du serveur au lieu d'annoncer un succès qui n'a pas eu lieu.
      AppNotifications.showSnackBar(
        context,
        message: messageLisible(
          echec,
          repli: "La suppression du compte n'a pas abouti. Réessayez.",
        ),
        isError: true,
      );
      return;
    }

    await AppNotifications.showPremiumDialog(
      context,
      title: "Compte désactivé",
      // Le message du serveur, tel quel.
      message: messageDuServeur!,
      confirmText: "Fermer",
      isSuccess: true,
    );

    // La session n'existe plus : rester sur les réglages n'aurait aucun sens.
    // Retour au point de départ de l'application — et par le retour du
    // dialogue plutôt que par onConfirm, car showPremiumDialog se ferme aussi
    // d'un appui à côté (barrierDismissible) : on serait alors resté sur les
    // réglages d'un compte qui n'existe plus, jusqu'au premier 401.
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const BienvenuePage()),
      (route) => false,
    );
  }

  /// Demande la suppression au serveur, et n'annonce QUE ce qu'il a confirmé.
  ///
  /// Ce gestionnaire n'appelait que SessionService.terminer() — un nettoyage
  /// purement LOCAL — puis affichait « votre demande a bien été transmise » :
  /// aucune requête ne partait, le compte restait pleinement actif en base
  /// avec toutes ses données, et il suffisait de se reconnecter pour le
  /// retrouver intact. La route existe (DELETE /utilisateurs/:id) : c'est
  /// elle qui fait foi, et le nettoyage local ne vient qu'APRÈS son accord.
  ///
  /// Rend le message du serveur, ou lève. Aucun affichage ici : c'est
  /// _executerLaSuppression qui décide de ce que voit la personne.
  Future<String> _demanderLaSuppression() async {
    final message = await AuthService().deleteAccount();

    // Le compte est désactivé côté serveur : on révoque la session sur le
    // serveur puis on efface toute trace locale — logout() fait les deux.
    //
    // Un ennui ICI ne remet pas en cause ce que le serveur a déjà fait : le
    // signaler comme un échec de suppression ferait croire que le compte est
    // intact. On le journalise, et on annonce ce qui s'est réellement produit.
    try {
      await AuthService().logout();
    } catch (e) {
      debugPrint('Suppression du compte : fin de session imparfaite — $e');
    }

    return message;
  }

  Widget _buildStatsCard(bool isDark) {
    if (_isLoadingStats) {
      return Container(
        margin: EdgeInsets.symmetric(vertical: 8),
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          border: Border.all(
            color: isDark ? AppColors.textHint : Colors.black12,
          ),
        ),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              color: AppColors.accentInk,
              strokeWidth: 2,
            ),
          ),
        ),
      );
    }

    return Container(
      margin: EdgeInsets.symmetric(vertical: 8),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(color: isDark ? AppColors.textHint : Colors.black12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatCol("Livres lus", "$_livresLus"),
          _buildStatCol("En cours", "$_inProgressCount"),
          _buildStatCol("Favoris", "$_favoritesCount"),
        ],
      ),
    );
  }

  Widget _buildStatCol(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.accentInk,
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
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

      if (photoUrl != null) {
        final token = await TokenStorage.getToken();
        if (token != null) {
          final authService = AuthService();
          final user = await authService.getUser(token);
          if (user != null) {
            final updatedUser = await authService.updateProfileDetails(
              userId: user.id,
              profilePhoto: photoUrl,
            );
            if (updatedUser != null) {
              AppNotifications.showSnackBar(
                context,
                message: "Photo de profil mise à jour !",
                isSuccess: true,
              );
            } else {
              AppNotifications.showSnackBar(
                context,
                message: "Erreur lors de la mise à jour.",
                isError: true,
              );
            }
          }
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

  void _switchToAuthorMode(BuildContext context) {
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
      title: "Mode Auteur",
      message: "Voulez-vous vraiment basculer vers votre espace Auteur ?",
      confirmText: "Basculer",
      cancelText: "Annuler",
      onConfirm: () => _executeSwitchToAuthorMode(context),
    );
  }

  /// Bascule vers l'espace auteur — côté SERVEUR, et pas seulement à l'écran.
  ///
  /// Cette bascule n'écrivait que dans le stockage local : elle changeait la
  /// page affichée sans rien dire au serveur. Le compte restait « lecteur », et
  /// c'est le rôle porté par le jeton qui décide de ce qui est permis. Tant que
  /// la publication n'était gardée par rien, personne ne s'en apercevait ;
  /// depuis qu'elle exige le rôle Auteur, le parcours se terminait par un refus
  /// au dernier geste — après avoir écrit le livre, choisi la couverture et
  /// fixé le prix.
  ///
  /// On demande donc le profil au serveur, on attend son accord, et on ne
  /// navigue qu'ensuite. Le jeton renvoyé porte le nouveau rôle ; le service
  /// l'enregistre à la place de l'ancien.
  Future<void> _executeSwitchToAuthorMode(BuildContext context) async {
    if (_basculeEnCours) return;
    setState(() => _basculeEnCours = true);

    try {
      // Le serveur résout le profil par son libellé aussi bien que par son
      // identifiant, et n'accepte que les profils librement attribuables —
      // lecteur, auteur, éditeur. « Auteur » en fait partie.
      final tokenUser = await AuthService().updateProfileForUser("Auteur");

      await ProfileStorage.saveSelectedProfileRole("auteur");
      // Le nouveau profil remplace l'ancien dans le stockage : sans cela, un
      // démarrage hors ligne relisait l'identifiant du profil précédent avec
      // le rôle tout juste enregistré — un attelage incohérent.
      await ProfileStorage.saveSelectedProfile(tokenUser.user.profilId);
      if (!context.mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => ecrivainHome.HomePageAuteur(
            key: ecrivainHome.HomePageAuteur.navKey,
            profileId: tokenUser.user.profilId,
            userName: tokenUser.user.nomComplet,
          ),
        ),
        (route) => false,
      );
    } catch (e) {
      if (context.mounted) {
        // Le service relaie le message du serveur dans l'exception. Le montrer
        // vaut mieux qu'un « Erreur » générique : c'est lui qui dit si le
        // profil est refusé, si le compte n'est plus actif, ou si le réseau a
        // lâché.
        AppNotifications.showSnackBar(
          context,
          message: messageLisible(
            e,
            repli: "Le passage en mode auteur a échoué.",
          ),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _basculeEnCours = false);
    }
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
}
