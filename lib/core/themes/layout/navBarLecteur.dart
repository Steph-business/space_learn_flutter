import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';

import 'package:space_learn_flutter/core/space_learn/pages/principales/lecteur/bibliothequePage.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/lecteur/markeplacePage.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/lecteur/teamsPage.dart';
import 'package:space_learn_flutter/core/themes/app_colors.dart';

class MainNavBar extends StatefulWidget {
  final Widget? child;
  const MainNavBar({super.key, this.child});

  @override
  State<MainNavBar> createState() => _MainNavBarState();

  static _MainNavBarState? of(BuildContext context) {
    return context.findAncestorStateOfType<_MainNavBarState>();
  }
}

class _MainNavBarState extends State<MainNavBar> {
  int _selectedIndex = 0;

  final List<String> _titles = [
    "Accueil",
    "Marketplace",
    "Bibliothèque",
    "Teams",
  ];

  final List<IconData> _icons = [
    Icons.home,
    Icons.store,
    Icons.library_books,
    Icons.group,
  ];

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  void navigateToBibliotheque() {
    _onItemTapped(3);
  }

  Widget _getPage(int index) {
    switch (index) {
      case 0:
        return widget.child ?? const Center(child: Text('Accueil'));
      case 1:
        return const MarketplacePage();
      case 2:
        return const BibliothequePage();
      case 3:
        return const TeamsPageLecteur();
      default:
        return widget.child ?? const Center(child: Text('Accueil'));
    }
  }

  void _navigateToPage(BuildContext context, int index) {
    setState(() => _selectedIndex = index);
    // Navigation logique si nécessaire
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: _getPage(_selectedIndex),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          elevation: 0,
          backgroundColor: Colors.white,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: Colors.grey[500],
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
              icon: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
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
