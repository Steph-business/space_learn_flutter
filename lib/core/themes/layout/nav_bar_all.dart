import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/themes/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:space_learn_flutter/core/utils/profile_image_helper.dart';

import '../../space_learn/pages/principales/notificationPage.dart';
import '../../space_learn/pages/principales/messages_page.dart';
import 'package:provider/provider.dart';
import '../../space_learn/data/dataServices/cart_provider.dart';
import '../../space_learn/data/dataServices/notification_provider.dart';
import '../../space_learn/pages/widgets/lecteur/boutique/cart_page.dart';

class NavBarAll extends StatelessWidget {
  final String userName;
  final String? userUrl;
  final String? greeting;
  final String? subtitle;
  final bool showCart;
  final String role; // 'lecteur' or 'auteur'

  const NavBarAll({
    super.key,
    this.userName = 'Lecteur',
    this.userUrl,
    this.greeting,
    this.subtitle,
    this.showCart = true,
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
  Widget build(BuildContext context) {
    final String initial = userName.isNotEmpty
        ? userName[0].toUpperCase()
        : 'L';

    return Container(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 60, bottom: 16),
      decoration: const BoxDecoration(color: Colors.transparent),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.textHint, width: 1),
                  color: AppColors.cardBackground,
                ),
                child: ClipOval(
                  child: ProfileImageHelper.buildProfileImage(
                    userUrl,
                    fallbackInitial: initial,
                    textStyle: AppTextStyles.sectionTitle,
                    width: 45,
                    height: 45,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              SizedBox(width: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    "${greeting ?? getGreeting()}, ",
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: AppColors.textHint,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  Text(
                    userName,
                    style: AppTextStyles.sectionTitle.copyWith(fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Chat icon currently exists in NavBarAll but not in image, I'll keep just notifications if it's Auteur
              if (showCart) // Just a trick to distinguish Reader/Author if needed, but safer to just show icons
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
                          builder: (context) => NotificationPage(role: role),
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
                      final currentRole =
                          role; // Use currentRole local to avoid any field access issues if possible
                      final count = notificationProvider.getUnreadCountByRole(
                        currentRole,
                      );
                      if (count == 0) return const SizedBox.shrink();
                      return Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.red,
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
              if (showCart)
                Stack(
                  alignment: Alignment.topRight,
                  children: [
                    IconButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CartPage(),
                          ),
                        );
                      },
                      icon: Icon(
                        Icons.shopping_cart_outlined,
                        color: AppColors.textPrimary,
                        size: 24,
                      ),
                    ),
                    Consumer<CartProvider>(
                      builder: (context, cart, child) {
                        if (cart.itemCount == 0) return const SizedBox.shrink();
                        return Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            padding: EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
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
                              '${cart.itemCount}',
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