import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';

import 'package:space_learn_flutter/core/space_learn/pages/principales/lecteur/bibliotheque_page.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/lecteur/boutique_page.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/lecteur/communaute_page.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/settings_page.dart';

class MainNavBar extends StatefulWidget {
  final Widget? child;
  static final GlobalKey<MainNavBarState> mainNavBarKey =
      GlobalKey<MainNavBarState>();

  const MainNavBar({super.key, this.child});

  @override
  State<MainNavBar> createState() => MainNavBarState();

  static MainNavBarState? of(BuildContext context) {
    return context.findAncestorStateOfType<MainNavBarState>();
  }
}

class MainNavBarState extends State<MainNavBar> {
  int _selectedIndex = 0;

  final List<String> _titles = [
    "Accueil",
    "Boutique",
    "Bibliothèque",
    "Teams",
    "Paramètres",
  ];

  final List<IconData> _icons = [
    Icons.home_filled,
    Iconsax.shop,
    Iconsax.book,
    Iconsax.messages_1,
    Icons.settings,
  ];

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  void navigateToBibliotheque() {
    _onItemTapped(2);
  }

  void navigateToMarketplace() {
    _onItemTapped(1);
  }

  void navigateToCommunaute() {
    _onItemTapped(3);
  }

  void goHome() {
    _onItemTapped(0);
  }

  Widget _getPage(int index) {
    switch (index) {
      case 0:
        return widget.child ?? Center(child: Text('Accueil'));
      case 1:
        return const MarketplacePage();
      case 2:
        return const BibliothequePage();
      case 3:
        return TeamsPageLecteur(
          onBackPressed: () => setState(() => _selectedIndex = 0),
        );
      case 4:
        return const SettingsPage();
      default:
        return widget.child ?? Center(child: Text('Accueil'));
    }
  }

  void _navigateToPage(BuildContext context, int index) {
    setState(() => _selectedIndex = index);
    // Navigation logique si nécessaire
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: _getPage(_selectedIndex),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          elevation: 0,
          backgroundColor: AppColors.cardBackground,
          selectedItemColor: AppColors.primary, // Cyan
          unselectedItemColor: AppColors.textSecondary,
          showUnselectedLabels: true,
          selectedLabelStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          unselectedLabelStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w400,
            fontSize: 12,
          ),
          items: List.generate(
            _titles.length,
            (index) => BottomNavigationBarItem(
              icon: Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Icon(
                  _icons[index],
                  size: _selectedIndex == index ? 28 : 24,
                ),
              ),
              label: _titles[index],
            ),
          ),
        ),
      ),
    );
  }
}