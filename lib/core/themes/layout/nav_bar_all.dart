import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/settings/user_guide_page.dart';
import 'package:space_learn_flutter/core/themes/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:space_learn_flutter/core/utils/profile_image_helper.dart';
import 'package:space_learn_flutter/core/utils/token_storage.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/authServices.dart';
import 'package:provider/provider.dart';

import '../../space_learn/pages/principales/notificationPage.dart';
import '../../space_learn/pages/principales/messages_page.dart';
import '../../space_learn/pages/principales/profilePage.dart';
import '../../space_learn/data/dataServices/notification_provider.dart';

class NavBarAll extends StatefulWidget {
  final String? userName;
  final String? userUrl;
  final String? greeting;
  final String? subtitle;
  final String role; // 'lecteur' or 'auteur'

  const NavBarAll({
    super.key,
    this.userName,
    this.userUrl,
    this.greeting,
    this.subtitle,
    this.role = 'lecteur',
  });

  static String getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Bonjour';
    if (hour < 18) return 'Bon après-midi';
    return 'Bonsoir';
  }

  static String getFirstName(String fullName) {
    if (fullName.isEmpty) return 'Lecteur';
    return fullName.split(' ').first;
  }

  @override
  State<NavBarAll> createState() => _NavBarAllState();
}

class _NavBarAllState extends State<NavBarAll> {
  final AuthService _authService = AuthService();
  String _displayName = '';
  String? _profilePhoto;

  @override
  void initState() {
    super.initState();
    _displayName = widget.userName ?? '';
    _profilePhoto = widget.userUrl;
    _resolveUserInfo();
  }

  @override
  void didUpdateWidget(covariant NavBarAll oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.userName != null && widget.userName != oldWidget.userName) {
      setState(() {
        _displayName = widget.userName!;
      });
    }
    if (widget.userUrl != null && widget.userUrl != oldWidget.userUrl) {
      setState(() {
        _profilePhoto = widget.userUrl;
      });
    }
  }

  Future<void> _resolveUserInfo() async {
    // Si des informations complètes ont déjà été fournies par le parent, les conserver
    final isGeneric = _displayName.isEmpty ||
        _displayName == 'Lecteur' ||
        _displayName == 'Auteur';

    if (isGeneric) {
      final savedName = await TokenStorage.getUserName();
      if (savedName != null && savedName.isNotEmpty && mounted) {
        setState(() {
          _displayName = savedName;
        });
      }
    }

    if (_profilePhoto == null || isGeneric) {
      try {
        final token = await TokenStorage.getToken();
        if (token != null) {
          final user = await _authService.getUser(token);
          if (user != null && mounted) {
            TokenStorage.saveUserId(user.id);
            setState(() {
              if (user.nomComplet.isNotEmpty) {
                _displayName = user.nomComplet;
                TokenStorage.saveUserName(user.nomComplet);
              }
              if (user.profilePhoto != null && user.profilePhoto!.isNotEmpty) {
                _profilePhoto = user.profilePhoto;
              }
            });
          }
        }
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    AppColors.suivreLeTheme(context);
    final topPadding = MediaQuery.of(context).padding.top;
    final fallbackName = widget.role == 'auteur' ? 'Auteur' : 'Lecteur';
    final effectiveName = _displayName.isNotEmpty ? _displayName : fallbackName;
    final String initial = effectiveName.isNotEmpty
        ? effectiveName[0].toUpperCase()
        : (widget.role == 'auteur' ? 'A' : 'L');

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: topPadding > 0 ? topPadding + 10 : 50,
        bottom: 12,
      ),
      decoration: const BoxDecoration(color: Colors.transparent),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ProfilePage(),
                      ),
                    );
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: _profilePhoto != null && _profilePhoto!.isNotEmpty
                          ? null
                          : LinearGradient(
                              colors: [
                                AppColors.secondaryVariant,
                                AppColors.secondaryVariant.withValues(alpha: 0.85),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                      color: _profilePhoto != null && _profilePhoto!.isNotEmpty
                          ? AppColors.cardBackground
                          : null,
                      border: Border.all(
                        color: AppColors.secondaryVariant.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.secondaryVariant.withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: ProfileImageHelper.buildProfileImage(
                        _profilePhoto,
                        fallbackInitial: initial,
                        textStyle: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: "${widget.greeting ?? NavBarAll.getGreeting()}, ",
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: AppColors.textHint,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        TextSpan(
                          text: effectiveName,
                          style: AppTextStyles.sectionTitle.copyWith(
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Le mode d'emploi, en tête d'écran.
              //
              // Il vivait au fond des réglages, sous « Guide d'utilisation » —
              // c'est-à-dire là où personne ne va tant qu'il ne cherche pas
              // déjà quelque chose. Or on a besoin d'un mode d'emploi au moment
              // où l'on ne sait pas quoi faire, pas au moment où l'on règle ses
              // préférences.
              //
              // Le rôle décide de ce qui s'ouvre : un lecteur n'a rien à faire
              // du parcours auteur.
              IconButton(
                tooltip: "Aide et mode d'emploi",
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => UserGuidePage(
                        estAuteur: widget.role == 'auteur',
                      ),
                    ),
                  );
                },
                icon: Icon(
                  Icons.help_outline_rounded,
                  color: AppColors.textPrimary,
                  size: 24,
                ),
              ),
              IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MessagesPage(),
                    ),
                  );
                },
                icon: Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: AppColors.textPrimary,
                  size: 24,
                ),
              ),
              Stack(
                alignment: Alignment.topRight,
                children: [
                  IconButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => NotificationPage(role: widget.role),
                        ),
                      );
                    },
                    icon: Icon(
                      Icons.notifications_outlined,
                      color: AppColors.textPrimary,
                      size: 24,
                    ),
                  ),
                  Consumer<NotificationProvider>(
                    builder: (context, notificationProvider, child) {
                      final count = notificationProvider.getUnreadCountByRole(
                        widget.role,
                      );
                      if (count == 0) return const SizedBox.shrink();
                      return Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.scaffoldBackground,
                              width: 1.5,
                            ),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 14,
                            minHeight: 14,
                          ),
                          child: Text(
                            '$count',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
