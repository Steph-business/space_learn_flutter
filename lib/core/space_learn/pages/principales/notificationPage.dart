import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/themes/app_text_styles.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/notification_provider.dart';
import 'package:space_learn_flutter/core/utils/token_storage.dart';
import '../widgets/auteur/accueil/notification_recent.dart';

class NotificationPage extends StatefulWidget {
  final String? role; // 'lecteur' or 'auteur'

  const NotificationPage({super.key, this.role});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  String _filter = 'tous'; // 'tous', 'non_read', 'read'

  @override
  void initState() {
    super.initState();
    _fetchGrouped();
  }

  Future<void> _fetchGrouped() async {
    final token = await TokenStorage.getToken();
    if (token != null && mounted) {
      context.read<NotificationProvider>().loadGroupedNotifications(token);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: AppBar(
              backgroundColor: Colors.white.withOpacity(0.05),
              elevation: 0,
              centerTitle: true,
              leading: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.chevron_left, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
              title: Text(
                "Notifications",
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 22,
                  letterSpacing: 0.5,
                ),
              ),
              actions: [
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert,
                    color: AppColors.primaryLight,
                  ),
                  offset: const Offset(0, 45),
                  color: AppColors.cardBackground,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onSelected: (value) async {
                    if (value == 'mark_all') {
                      final notifProvider = context.read<NotificationProvider>();
                      final token = await TokenStorage.getToken();
                      if (token != null) {
                        notifProvider.markAllAsRead(token);
                      }
                    } else {
                      setState(() {
                        _filter = value;
                      });
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'tous',
                      height: 35,
                      child: Row(
                        children: [
                          Icon(
                            Icons.list,
                            size: 16,
                            color: _filter == 'tous'
                                ? AppColors.primaryLight
                                : Colors.white70,
                          ),
                          const SizedBox(width: 8),
                          Text("Toutes", style: AppTextStyles.body13),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'non_read',
                      height: 35,
                      child: Row(
                        children: [
                          Icon(
                            Icons.mark_email_unread_outlined,
                            size: 16,
                            color: _filter == 'non_read'
                                ? AppColors.primaryLight
                                : Colors.white70,
                          ),
                          const SizedBox(width: 8),
                          Text("Non lues", style: AppTextStyles.body13),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'archives',
                      height: 35,
                      child: Row(
                        children: [
                          Icon(
                            Icons.archive_outlined,
                            size: 16,
                            color: _filter == 'archives'
                                ? AppColors.primaryLight
                                : Colors.white70,
                          ),
                          const SizedBox(width: 8),
                          Text("Archives", style: AppTextStyles.body13),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(height: 1),
                    PopupMenuItem(
                      value: 'mark_all',
                      height: 35,
                      child: Row(
                        children: [
                          const Icon(
                            Icons.checklist,
                            size: 16,
                            color: AppColors.primaryLight,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Tout lire",
                            style: GoogleFonts.poppins(
                              color: AppColors.primaryLight,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
      body: _buildNotificationList(context, widget.role ?? 'lecteur'),
    );
  }

  Widget _buildNotificationList(BuildContext context, String role) {
    return Consumer<NotificationProvider>(
      builder: (context, provider, child) {
        final rawNotifications = provider.groupedNotifications[role] ?? [];

        // Appliquer le filtre local
        final notifications = rawNotifications.where((n) {
          if (_filter == 'non_read') return !n.lu;
          if (_filter == 'archives') return n.lu;
          return true;
        }).toList();

        return RefreshIndicator(
          onRefresh: _fetchGrouped,
          color: AppColors.primaryLight,
          backgroundColor: AppColors.cardBackground,
          edgeOffset: 100,
          child: ListView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(16, 40, 16, 40),
            children: [
              RecentNotificationsPage(
                customNotifications: notifications,
                title: null, // Supprimé "Récemment"
              ),
            ],
          ),
        );
      },
    );
  }
}
