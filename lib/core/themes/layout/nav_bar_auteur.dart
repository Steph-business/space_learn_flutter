import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';

class NavBarAuteur extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const NavBarAuteur({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.scaffoldBackground,
        border: Border(
          top: BorderSide(color: AppColors.textPrimary.withOpacity(0.05), width: 1),
        ),
        
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                icon: Iconsax.home_2,
                activeIcon: Iconsax.home_25,
                label: "Accueil",
                index: 0,
              ),
              _buildNavItem(
                icon: Iconsax.book,
                activeIcon: Iconsax.book_1,
                label: "Mes Livres",
                index: 1,
              ),
              _buildNavItem(
                icon: Iconsax.add_circle,
                activeIcon: Iconsax.add_circle5,
                label: "Publier",
                index: 2,
                isSpecial: true,
              ),
              _buildNavItem(
                icon: Iconsax.people,
                activeIcon: Iconsax.people4,
                label: "Communauté",
                index: 3,
              ),
              _buildNavItem(
                icon: Iconsax.setting_2,
                activeIcon: Iconsax.setting_25,
                label: "Paramètres",
                index: 4,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
    bool isSpecial = false,
  }) {
    final isActive = currentIndex == index;

    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: isActive && !isSpecial
            ? BoxDecoration(
                color: AppColors.secondaryVariant.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSpecial)
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.secondaryVariant, AppColors.secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  
                ),
                child: Icon(
                  isActive ? activeIcon : icon,
                  size: 20,
                  color: AppColors.textPrimary,
                ),
              )
            else
              Icon(
                isActive ? activeIcon : icon,
                size: 22,
                color: isActive
                    ? AppColors.secondaryVariant
                    : AppColors.textHint,
              ),
            SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: isSpecial ? 10 : 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isSpecial
                    ? AppColors.secondaryVariant
                    : isActive
                    ? AppColors.secondaryVariant
                    : AppColors.textHint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}