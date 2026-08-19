import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:space_learn_flutter/core/themes/app_dimensions.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/notificationService.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/notification_provider.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/notificationModel.dart';
import 'package:space_learn_flutter/core/utils/token_storage.dart';
import 'package:space_learn_flutter/core/utils/app_notifications.dart';

/// Le type, en francais.
///
/// Il s'affichait brut : « RAPPEL_LECTURE », « COMMUNAUTE », « VENTE ». Ce
/// sont des valeurs de base de donnees, pas des mots qu'on lit.
String libelleTypeNotification(String type) {
  switch (type.toLowerCase().trim()) {
    case 'rappel_lecture':
      return 'REPRENDRE LA LECTURE';
    case 'communaute':
      return 'COMMUNAUTÉ';
    case 'vente':
      return 'VENTE';
    case 'achat':
      return 'ACHAT';
    case 'paiement':
      return 'PAIEMENT';
    case 'annonce':
      return 'ANNONCE';
    case 'evenement':
      return 'ÉVÉNEMENT';
    case 'message':
    case 'reponse':
      return 'MESSAGE';
    default:
      // Un type inconnu reste lisible : les tirets bas s'effacent.
      return type.replaceAll('_', ' ').toUpperCase();
  }
}

class RecentNotificationsPage extends StatefulWidget {
  final VoidCallback? onTapOpenNotifications;
  final List<NotificationModel>? customNotifications;
  final String? title;

  /// Ce qu'on affiche quand il n'y a rien.
  ///
  /// « Aucune notification » est faux des qu'un filtre est actif : la liste
  /// peut etre vide parce que tout a ete lu, ce qui est une bonne nouvelle et
  /// non une absence.
  final String? messageVide;

  /// Icône affichée dans l'état vide (optionnel, sinon icone cloche par défaut).
  final IconData? emptyIcon;

  /// Animation de fondu pour l'état vide (optionnel).
  final Animation<double>? emptyFadeAnimation;

  /// Animation de glissement pour l'état vide (optionnel).
  final Animation<Offset>? emptySlideAnimation;

  const RecentNotificationsPage({
    super.key,
    this.onTapOpenNotifications,
    this.customNotifications,
    this.title,
    this.messageVide,
    this.emptyIcon,
    this.emptyFadeAnimation,
    this.emptySlideAnimation,
  });

  @override
  State<RecentNotificationsPage> createState() =>
      _RecentNotificationsPageState();
}

class _RecentNotificationsPageState extends State<RecentNotificationsPage> {
  String _formatTimeAgo(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes}m';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
    return 'Il y a ${diff.inDays}j';
  }

  IconData _iconForType(String type) {
    final t = type.toLowerCase();
    if (t.contains('payment') ||
        t.contains('paiement') ||
        t.contains('vente') ||
        t.contains('achat')) {
      return Iconsax.wallet_3;
    }
    if (t.contains('review') || t.contains('avis')) {
      return Iconsax.star;
    }
    if (t.contains('message') || t.contains('reponse')) {
      return Iconsax.message_2;
    }
    if (t.contains('chapitre') ||
        t.contains('livre') ||
        t.contains('lecture')) {
      return Iconsax.book;
    }
    if (t.contains('abonné') || t.contains('follow')) {
      return Iconsax.user_add;
    }
    return Iconsax.notification;
  }

  Color _accentColorForType(String type) {
    final t = type.toLowerCase();
    if (t.contains('payment') ||
        t.contains('paiement') ||
        t.contains('vente') ||
        t.contains('achat')) {
      return AppColors.success;
    }
    if (t.contains('review') || t.contains('avis')) {
      return AppColors.warning;
    }
    if (t.contains('message') || t.contains('reponse')) {
      return AppColors.secondary;
    }
    if (t.contains('chapitre') || t.contains('livre')) {
      return AppColors.violet;
    }
    if (t.contains('lecture')) {
      return AppColors.primary;
    }
    if (t.contains('abonné') || t.contains('follow')) {
      return AppColors.pinkVivid;
    }
    return AppColors.primary;
  }

  Future<void> _supprimer(BuildContext context, NotificationModel notif) async {
    final provider = context.read<NotificationProvider>();
    final token = await TokenStorage.getToken();
    if (token == null) return;

    final retire = await provider.supprimer(notif.id, token);
    if (!retire && context.mounted) {
      // Elle est revenue a sa place : il faut le dire, sinon on croit l'avoir
      // ecartee et on la retrouve au prochain affichage sans comprendre.
      AppNotifications.showSnackBar(
        context,
        message: "La notification n'a pas pu être retirée.",
        isError: true,
      );
    }
  }

  /// Ouvrir la notification, PUIS la marquer lue.
  ///
  /// L'ordre était inverse, et il se voyait : le filtre par défaut de l'écran
  /// est « non lues ». Marquer d'abord faisait sortir la notification de la
  /// liste à l'instant du doigt — elle disparaissait sous les yeux — et la
  /// navigation ne partait qu'ensuite. Quand elle échouait, il ne restait rien
  /// du tout : ni la notification, ni l'écran promis.
  ///
  /// Naviguer d'abord garde la ligne en place jusqu'à ce que l'écran suivant
  /// soit poussé. Et si la navigation ne mène nulle part, la notification
  /// reste là, non lue : on peut réessayer, au lieu de perdre la trace de ce
  /// qu'on n'a jamais vu.
  Future<void> _handleNotificationTap(
    BuildContext context,
    NotificationModel notif,
  ) async {
    final notifProvider = context.read<NotificationProvider>();

    final ouverte = NotificationService.handleNotificationTap(notif);
    if (!ouverte) return;

    final token = await TokenStorage.getToken();
    if (token != null && !notif.lu) {
      notifProvider.markAsRead(notif.id, token);
    }
  }

  @override
  Widget build(BuildContext context) {
    AppColors.suivreLeTheme(context);
    final notificationProvider = context.watch<NotificationProvider>();
    final notifications =
        widget.customNotifications ?? notificationProvider.notifications;
    final loading = notificationProvider.isLoading;

    if (loading && notifications.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryLight),
          ),
        ),
      );
    }

    if (notifications.isEmpty) {
      Widget emptyContent = Padding(
        padding: const EdgeInsets.symmetric(vertical: 80),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: Icon(
                widget.emptyIcon ?? Iconsax.notification_bing,
                size: 40,
                color: AppColors.textPrimary.withOpacity(0.25),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.messageVide ?? 'Aucune notification.',
              style: GoogleFonts.poppins(
                color: AppColors.textPrimary.withOpacity(0.5),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );

      if (widget.emptyFadeAnimation != null) {
        emptyContent = FadeTransition(
          opacity: widget.emptyFadeAnimation!,
          child: widget.emptySlideAnimation != null
              ? SlideTransition(
                  position: widget.emptySlideAnimation!,
                  child: emptyContent,
                )
              : emptyContent,
        );
      }

      return Center(child: emptyContent);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.title != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 20),
            child: Text(
              widget.title!,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary.withOpacity(0.9),
                letterSpacing: 0.5,
              ),
            ),
          ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: notifications.length,
          itemBuilder: (context, index) {
            final notif = notifications[index];
            // Ecarter sans ouvrir.
            //
            // La seule facon de se debarrasser d'une notification etait de la
            // lire : pour dix rappels sur le meme livre, dix ouvertures. Le
            // glissement lateral est le geste attendu partout, et la route de
            // suppression existait deja cote serveur.
            return Dismissible(
              key: ValueKey(notif.id),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 24),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
                ),
                child: Icon(Iconsax.trash, color: AppColors.error, size: 20),
              ),
              onDismissed: (_) => _supprimer(context, notif),
              child: _NotificationCardFromModel(
                model: notif,
                icon: _iconForType(notif.type),
                accentColor: _accentColorForType(notif.type),
                timeAgo: _formatTimeAgo(notif.creeLe),
                onTap: () => _handleNotificationTap(context, notif),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _NotificationCardFromModel extends StatelessWidget {
  final NotificationModel model;
  final IconData icon;
  final Color accentColor;
  final String timeAgo;
  final VoidCallback onTap;

  const _NotificationCardFromModel({
    required this.model,
    required this.icon,
    required this.accentColor,
    required this.timeAgo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    AppColors.suivreLeTheme(context);
    final isUnread = !model.lu;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
              border: Border.all(
                color: isUnread
                    ? accentColor.withOpacity(0.3)
                    : AppColors.border,
                width: 1,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: accentColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(
                                AppDimensions.radiusInner,
                              ),
                            ),
                            child: Icon(icon, color: accentColor, size: 20),
                          ),
                          if (isUnread)
                            Positioned(
                              top: 0,
                              right: 0,
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: accentColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.scaffoldBackground,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  libelleTypeNotification(model.type),
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: accentColor,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                                Text(
                                  timeAgo,
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    color: AppColors.textPrimary.withOpacity(
                                      0.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 4),
                            Text(
                              model.contenu,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                height: 1.3,
                                color: isUnread
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                                fontWeight: isUnread
                                    ? FontWeight.w500
                                    : FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(top: 12, left: 4),
                        child: Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.textHint,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
