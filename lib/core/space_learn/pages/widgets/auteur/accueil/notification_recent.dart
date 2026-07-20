import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/notificationService.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/notification_provider.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/notificationModel.dart';
import 'package:space_learn_flutter/core/utils/token_storage.dart';

class RecentNotificationsPage extends StatefulWidget {
  final VoidCallback? onTapOpenNotifications;
  final List<NotificationModel>? customNotifications;
  final String? title;

  const RecentNotificationsPage({
    super.key,
    this.onTapOpenNotifications,
    this.customNotifications,
    this.title,
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

  /// Navigate based on notification type and reference
  Future<void> _handleNotificationTap(
    BuildContext context,
    NotificationModel notif,
  ) async {
    final notifProvider = context.read<NotificationProvider>();
    final token = await TokenStorage.getToken();
    if (token != null && !notif.lu) {
      notifProvider.markAsRead(notif.id, token);
    }

    // Use centralized logic from NotificationService
    NotificationService.handleNotificationTap(notif);
  }

  @override
  Widget build(BuildContext context) {
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
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 60),
          child: Column(
            children: [
              Icon(
                Iconsax.notification_bing,
                size: 64,
                color: AppColors.textPrimary.withOpacity(0.2),
              ),
              SizedBox(height: 16),
              Text(
                'Aucune notification.',
                style: GoogleFonts.poppins(
                  color: AppColors.textPrimary.withOpacity(0.5),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.title != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 20),
            child: Text(
              widget.title!,
              style: GoogleFonts.outfit(
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
            return _NotificationCardFromModel(
              model: notif,
              icon: _iconForType(notif.type),
              accentColor: _accentColorForType(notif.type),
              timeAgo: _formatTimeAgo(notif.creeLe),
              onTap: () => _handleNotificationTap(context, notif),
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
    final isUnread = !model.lu;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(16),
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
                borderRadius: BorderRadius.circular(16),
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
                              borderRadius: BorderRadius.circular(12),
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
                                  model.type.toUpperCase(),
                                  style: GoogleFonts.outfit(
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
                                    color: AppColors.textPrimary.withOpacity(0.4),
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