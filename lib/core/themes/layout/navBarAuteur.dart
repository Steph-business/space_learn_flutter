import 'package:flutter/material.dart';

class NavBarAuteur extends StatefulWidget {
  const NavBarAuteur({super.key});

  @override
  State<NavBarAuteur> createState() => _NavBarAuteurState();
}

class _NavBarAuteurState extends State<NavBarAuteur> {
  int _currentIndex = 0;

  final List<Map<String, dynamic>> _items = [
    {'icon': Icons.home, 'label': 'Accueil'},
    {'icon': Icons.edit, 'label': 'Écrire'},
    {'icon': Icons.book, 'label': 'Mes Livres'},
    {'icon': Icons.bar_chart, 'label': 'Analytics'},
    {'icon': Icons.group, 'label': 'Teams'},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: const BoxDecoration(color: Colors.white),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(_items.length, (index) {
          final item = _items[index];
          final bool isActive = _currentIndex == index;

          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _currentIndex = index);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      item['icon'],
                      color: isActive ? Colors.orange.shade600 : Colors.black54,
                      size: 20,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item['label'],
                      style: TextStyle(
                        color: isActive
                            ? Colors.orange.shade600
                            : Colors.black87,
                        fontWeight: isActive
                            ? FontWeight.w600
                            : FontWeight.normal,
                        fontSize: 10,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
