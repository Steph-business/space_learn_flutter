import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/themes/app_text_styles.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:space_learn_flutter/core/themes/app_dimensions.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
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

  Future<void> _fetchGrouped() async {
    final token = await TokenStorage.getToken();
    if (token != null && mounted) {
      context.read<NotificationProvider>().loadGroupedNotifications(token);
    }
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
              final total =
                  provider.groupedNotifications[widget.role ?? 'lecteur']
                      ?.where((n) => !n.lu)
                      .length ??
                  0;
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
                      notifProvider.markAllAsRead(token);
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
        // Le seau du role, et a defaut la liste complete.
        //
        // Tout venait de . Quand cette cle est
        // absente — role non renseigne, groupement pas encore fait — la liste
        // etait vide, et l'ecran annoncait « Vous etes a jour ! » a quelqu'un
        // dont les notifications n'avaient tout simplement pas ete lues. Se
        // taire est preferable a affirmer le faux.
        final duRole = provider.groupedNotifications[widget.role ?? 'lecteur'];
        final rawNotifications = (duRole == null || duRole.isEmpty)
            ? provider.notifications
            : duRole;

        final notifications = rawNotifications.where((n) {
          if (_filter == 'non_read') return !n.lu;
          if (_filter == 'archives') return n.lu;
          return true;
        }).toList();

        // « Vous etes a jour » n'a de sens que s'il y a quelque chose a etre a
        // jour DE. Sans rien du tout, c'est « aucune notification » — et les
        // deux se confondaient.
        final rienDuTout = rawNotifications.isEmpty;

        return RefreshIndicator(
          onRefresh: _fetchGrouped,
          color: AppColors.accentInk,
          backgroundColor: AppColors.cardBackground,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
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
