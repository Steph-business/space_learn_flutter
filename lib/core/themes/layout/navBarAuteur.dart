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
        currentIndex: currentIndex,
        onTap: onTap,
        elevation: 0,
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFFF59E0B),
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
        items: [
          _buildItem(Icons.home, "Accueil", 0),
          _buildItem(Icons.add_circle_outline, "Publier", 1),
          _buildItem(Icons.book, "Mes Livres", 2),
          _buildItem(Icons.bar_chart, "Analytics", 3),
          _buildItem(Icons.group, "Teams", 4),
        ],
      ),
    );
  }

  BottomNavigationBarItem _buildItem(IconData icon, String label, int index) {
    return BottomNavigationBarItem(
      icon: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.only(bottom: 4),
        child: Icon(
          icon,
          size: currentIndex == index ? 28 : 24,
        ),
      ),
      label: label,
    );
  }
}
