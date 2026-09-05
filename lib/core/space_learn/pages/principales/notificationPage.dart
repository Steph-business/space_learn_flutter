import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/themes/app_text_styles.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:space_learn_flutter/core/themes/app_dimensions.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/notification_provider.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/notificationModel.dart';
import 'package:space_learn_flutter/core/utils/app_notifications.dart';
import 'package:space_learn_flutter/core/utils/token_storage.dart';
import '../widgets/auteur/accueil/notification_recent.dart';

class NotificationPage extends StatefulWidget {
  final String? role; // 'lecteur' or 'auteur'

  const NotificationPage({super.key, this.role});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage>
    with SingleTickerProviderStateMixin {
  /// Ce que la page montre a l'ouverture.
  String _filter = 'non_read';

  late final AnimationController _emptyAnimController;
  late final Animation<double> _emptyFadeAnim;
  late final Animation<Offset> _emptySlideAnim;

  @override
  void initState() {
    super.initState();
    _fetchGrouped();

    _emptyAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _emptyFadeAnim = CurvedAnimation(
      parent: _emptyAnimController,
      curve: Curves.easeOut,
    );
    _emptySlideAnim =
        Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
          CurvedAnimation(parent: _emptyAnimController, curve: Curves.easeOut),
        );
    _emptyAnimController.forward();
  }

  @override
  void dispose() {
    _emptyAnimController.dispose();
    super.dispose();
  }

  /// Panne constatée AVANT d'appeler le réseau (session expirée).
  ///
  /// Le provider ne connaît que les échecs de ses propres appels : quand le
  /// jeton manquait, aucun chargement ne partait, `derniereErreurChargement`
  /// restait nul, et la page écrivait « Aucune notification pour l'instant. »
  /// à quelqu'un dont la session était morte — la phrase la plus rassurante
  /// possible pour dire qu'on n'a même pas regardé. Une session expirée se dit
  /// comme telle.
  String? _echecLocal;

  Future<void> _fetchGrouped() async {
    final token = await TokenStorage.getToken();
    if (!mounted) return;
    if (token == null || token.isEmpty) {
      setState(
        () => _echecLocal =
            "Votre session a expiré. Reconnectez-vous pour voir vos "
            "notifications.",
      );
      return;
    }
    setState(() => _echecLocal = null);
    // Attendu, et non lancé : sans cela le RefreshIndicator rendait la main
    // aussitôt et le geste « tirer pour rafraîchir » ne montrait aucune
    // progression — on ne savait pas si quelque chose s'était passé.
    await context.read<NotificationProvider>().loadGroupedNotifications(token);
  }

  /// « message_prive » s'adresse à la PERSONNE, pas à l'un de ses métiers.
  ///
  /// Une conversation a deux bouts, quel que soit le métier de chacun : le
  /// serveur le documente (notification/controller.go,
  /// estNotificationPersonnelle) mais son groupement par rôle reste une
  /// partition stricte, qui range ce type côté lecteur. Sans ce traitement,
  /// un auteur qui navigue en profil auteur n'apprenait JAMAIS qu'on lui
  /// avait écrit.
  bool _estPersonnelle(NotificationModel n) =>
      n.type.toLowerCase().trim() == 'message_prive';

  /// Les notifications du profil affiché : son seau, plus les personnelles.
  ///
  /// Le calcul vit ici parce que trois gestes doivent dire la même chose :
  /// la liste affichée, la pastille du menu, et « tout marquer comme lu ».
  List<NotificationModel> _notificationsDuProfil(
    NotificationProvider provider,
  ) {
    final role = widget.role ?? 'lecteur';
    final grouped = provider.groupedNotifications;

    // Groupement pas encore fait (ou jamais abouti) : repli sur la liste à
    // plat, RESTREINTE au rôle affiché. Le repli précédent la rendait
    // entière — et il se déclenchait aussi sur un simple seau vide, si bien
    // qu'un auteur tout neuf voyait les rappels de lecture de son profil
    // lecteur, pendant que le compteur du menu, calculé sur le seau, disait
    // zéro.
    //
    // Le test « n.role == null » qui suivait ne restreignait RIEN : le modèle
    // Go Notification n'a pas de champ Role (notification/model.go), la route
    // à plat n'en porte donc jamais, et le prédicat était vrai pour toutes les
    // lignes des deux profils — le mensonge d'origine, intact. On classe
    // maintenant nous-mêmes, avec la fonction qui reproduit isAuthorNotification
    // du serveur et qui sert aussi au provider (liste à plat et flux SSE) :
    // un seul tri pour les trois chemins.
    if (grouped.isEmpty) {
      return provider.notifications.where((n) {
        if (_estPersonnelle(n)) return true;
        final roleDeLaLigne =
            n.role ?? NotificationProvider.roleDeLaNotification(n.type);
        return roleDeLaLigne == null || roleDeLaLigne == role;
      }).toList();
    }

    final propres = grouped[role] ?? const <NotificationModel>[];

    // Les personnelles rangées dans l'autre seau rejoignent le profil
    // affiché, sans doublon si le serveur les rendait un jour des deux côtés.
    final dejaLa = propres.map((n) => n.id).toSet();
    final personnelles = <NotificationModel>[];
    for (final entree in grouped.entries) {
      if (entree.key == role) continue;
      for (final n in entree.value) {
        if (_estPersonnelle(n) && !dejaLa.contains(n.id)) personnelles.add(n);
      }
    }
    if (personnelles.isEmpty) return propres;
    return trierDuPlusRecent([...propres, ...personnelles]);
  }

  @override
  Widget build(BuildContext context) {
    AppColors.suivreLeTheme(context);
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.scaffoldBackground,
        elevation: 0,
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.textPrimary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(Icons.chevron_left, color: AppColors.textPrimary),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ),
        title: Text(
          "Notifications",
          style: GoogleFonts.poppins(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 20,
            letterSpacing: 0.3,
          ),
        ),
        actions: [
          Consumer<NotificationProvider>(
            builder: (context, provider, _) {
              // La même source que la liste : un compteur calculé sur le seau
              // seul ignorait les messages privés affichés dans ce profil.
              final total = _notificationsDuProfil(
                provider,
              ).where((n) => !n.lu).length;
              return PopupMenuButton<String>(
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(Icons.more_vert, color: AppColors.accentInk),
                    if (total > 0)
                      Positioned(
                        top: -4,
                        right: -4,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
                offset: const Offset(0, 45),
                color: AppColors.cardBackground,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppDimensions.radiusInner,
                  ),
                ),
                onSelected: (value) async {
                  if (value == 'mark_all') {
                    final notifProvider = context.read<NotificationProvider>();
                    final token = await TokenStorage.getToken();
                    if (token != null) {
                      // Une à une, et non PUT /read-all : côté serveur,
                      // MarkAllAsRead marque TOUTES les notifications du
                      // compte, sans filtre de rôle (notification/
                      // repository.go). Nettoyer ses rappels en profil
                      // lecteur éteignait donc aussi les « vente » et
                      // « avis » du profil auteur — des notifications
                      // d'argent passées lues sans avoir jamais été
                      // montrées. On ne marque que ce que ce profil affiche.
                      final nonLues = _notificationsDuProfil(
                        notifProvider,
                      ).where((n) => !n.lu).toList();
                      // Chaque échec était avalé en silence : le réseau tombe
                      // au milieu de la série, la moitié des lignes reste en
                      // gras et rien ne dit pourquoi. Aucun succès ne
                      // s'annonce sans réponse du serveur — donc on compte.
                      var echecs = 0;
                      for (final n in nonLues) {
                        if (!await notifProvider.markAsRead(n.id, token)) {
                          echecs++;
                        }
                      }
                      if (!context.mounted) return;
                      if (echecs > 0) {
                        AppNotifications.showSnackBar(
                          context,
                          message: echecs == 1
                              ? "Une notification n'a pas pu être marquée "
                                    "comme lue."
                              : "$echecs notifications n'ont pas pu être "
                                    "marquées comme lues.",
                          isError: true,
                        );
                      }
                    } else {
                      // Jeton absent : le geste n'a rien fait, et se taire
                      // laisserait croire qu'il a réussi.
                      if (!context.mounted) return;
                      AppNotifications.showSnackBar(
                        context,
                        message:
                            "Votre session a expiré. Reconnectez-vous pour "
                            "marquer vos notifications comme lues.",
                        isError: true,
                      );
                    }
                  } else {
                    setState(() {
                      _filter = value;
                      _emptyAnimController
                        ..reset()
                        ..forward();
                    });
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'tous',
                    height: 40,
                    child: Row(
                      children: [
                        Icon(
                          Icons.list_rounded,
                          size: 16,
                          color: _filter == 'tous'
                              ? AppColors.accentInk
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 10),
                        Text("Toutes", style: AppTextStyles.body13),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'non_read',
                    height: 40,
                    child: Row(
                      children: [
                        Icon(
                          Icons.mark_email_unread_outlined,
                          size: 16,
                          color: _filter == 'non_read'
                              ? AppColors.accentInk
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 10),
                        Text("Non lues", style: AppTextStyles.body13),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'archives',
                    height: 40,
                    child: Row(
                      children: [
                        Icon(
                          Icons.archive_outlined,
                          size: 16,
                          color: _filter == 'archives'
                              ? AppColors.accentInk
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 10),
                        Text("Archives", style: AppTextStyles.body13),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(height: 1),
                  PopupMenuItem(
                    value: 'mark_all',
                    height: 40,
                    child: Row(
                      children: [
                        Icon(
                          Icons.checklist_rounded,
                          size: 16,
                          color: AppColors.accentInk,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          "Tout marquer comme lu",
                          style: GoogleFonts.poppins(
                            color: AppColors.accentInk,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (context, provider, child) {
        // Le seau du profil affiché, complété des notifications personnelles.
        //
        // Le repli « seau vide ou absent → liste complète » montrait les
        // notifications de l'AUTRE profil : un auteur tout neuf (zéro vente,
        // zéro avis) ouvrait la cloche en profil auteur et voyait tous ses
        // rappels de lecture de LECTEUR. Voir _notificationsDuProfil.
        final rawNotifications = _notificationsDuProfil(provider);

        final notifications = rawNotifications.where((n) {
          if (_filter == 'non_read') return !n.lu;
          if (_filter == 'archives') return n.lu;
          return true;
        }).toList();

        // « Vous etes a jour » n'a de sens que s'il y a quelque chose a etre a
        // jour DE. Sans rien du tout, c'est « aucune notification » — et les
        // deux se confondaient.
        final rienDuTout = rawNotifications.isEmpty;

        // Une panne n'est pas un vide.
        //
        // Le provider avalait l'échec de son chargement : serveur injoignable
        // ou session expirée, la page affichait « Aucune notification pour
        // l'instant. » — la phrase la plus rassurante possible pour dire qu'on
        // n'a pas pu regarder. Le champ n'est posé qu'après un chargement en
        // échec, et repart à null au début du suivant.
        //
        // `_echecLocal` passe devant : c'est la panne constatée sans même
        // avoir pu appeler (session expirée), le seul chemin que le provider
        // ne peut pas connaître.
        final panne = _echecLocal ?? provider.derniereErreurChargement;

        if (panne != null && rienDuTout) {
          return RefreshIndicator(
            onRefresh: _fetchGrouped,
            color: AppColors.accentInk,
            backgroundColor: AppColors.cardBackground,
            child: ListView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(32, 90, 32, 40),
              children: [
                Icon(
                  Iconsax.cloud_cross,
                  size: 44,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(height: 16),
                Text(
                  panne,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: AppColors.textSecondary,
                    fontSize: 13.5,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: TextButton.icon(
                    onPressed: _fetchGrouped,
                    icon: Icon(
                      Iconsax.refresh,
                      size: 16,
                      color: AppColors.accentInk,
                    ),
                    label: Text(
                      "Réessayer",
                      style: GoogleFonts.poppins(
                        color: AppColors.accentInk,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _fetchGrouped,
          color: AppColors.accentInk,
          backgroundColor: AppColors.cardBackground,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              // Le dernier rafraîchissement a échoué, mais une liste est déjà
              // à l'écran : on la garde — c'est l'état connu de CE compte — et
              // on dit seulement qu'elle n'a pas pu être mise à jour.
              if (panne != null)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusInner,
                        ),
                        border: Border.all(
                          color: AppColors.textSecondary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Iconsax.cloud_cross,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              panne,
                              style: GoogleFonts.poppins(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _fetchGrouped,
                            child: Text(
                              "Réessayer",
                              style: GoogleFonts.poppins(
                                color: AppColors.accentInk,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              // ── Liste des notifications ──
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                sliver: SliverToBoxAdapter(
                  child: RecentNotificationsPage(
                    customNotifications: notifications,
                    title: null,
                    messageVide: rienDuTout
                        ? "Aucune notification pour l'instant."
                        : switch (_filter) {
                            'non_read' => "Aucune notification !",
                            'archives' => "Aucune notification archivée.",
                            _ => "Aucune notification.",
                          },
                    emptyIcon: rienDuTout
                        ? Iconsax.notification_bing
                        : switch (_filter) {
                            'non_read' => Iconsax.tick_circle,
                            'archives' => Iconsax.archive_1,
                            _ => Iconsax.notification_bing,
                          },
                    emptyFadeAnimation: _emptyFadeAnim,
                    emptySlideAnimation: _emptySlideAnim,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
