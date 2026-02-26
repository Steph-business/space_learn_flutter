import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
        color: const Color(0xFF0F172A),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.05), width: 1),
        ),
      ),
      child: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: currentIndex,
        onTap: onTap,
        elevation: 0,
        backgroundColor: Colors.transparent,
        selectedItemColor: const Color(0xFF0EA5E9),
        unselectedItemColor: Colors.white.withOpacity(0.4),
        showUnselectedLabels: true,
        selectedLabelStyle: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        unselectedLabelStyle: GoogleFonts.poppins(
          fontWeight: FontWeight.w400,
          fontSize: 12,
        ),
        items: [
          _buildItem(Icons.home_filled, "Accueil", 0),
          _buildItem(Icons.add_circle, "Publier", 1),
          _buildItem(Icons.book, "Mes Livres", 2),
          _buildItem(Icons.group, "Communauté", 3),
          _buildItem(Icons.settings, "Paramètres", 4),
        ],
      ),
    );
  }

  BottomNavigationBarItem _buildItem(IconData icon, String label, int index) {
    return BottomNavigationBarItem(
      icon: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Icon(icon, size: currentIndex == index ? 26 : 24),
      ),
      label: label,
    );
  }
}
