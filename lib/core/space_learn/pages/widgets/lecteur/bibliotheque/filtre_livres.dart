import 'package:flutter/material.dart';

class FiltreLivres extends StatelessWidget {
  final String filtreActif;
  final ValueChanged<String> onFiltreChange;

  const FiltreLivres({
    super.key,
    required this.filtreActif,
    required this.onFiltreChange,
  });

  @override
  Widget build(BuildContext context) {
    final filtres = ["Tous", "En cours", "Terminés", "Favoris"];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filtres.map((f) {
          final actif = f == filtreActif;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(f),
              selected: actif,
              selectedColor: const Color(0xFF38445A),
              onSelected: (_) => onFiltreChange(f),
              labelStyle: TextStyle(
                color: actif ? Colors.white : Colors.black87,
                fontWeight: actif ? FontWeight.bold : FontWeight.normal,
              ),
              backgroundColor: Colors.grey[200],
            ),
          );
        }).toList(),
      ),
    );
  }
}
