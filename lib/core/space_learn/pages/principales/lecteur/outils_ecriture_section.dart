import 'package:flutter/material.dart';

class OutilsEcritureSection extends StatelessWidget {
  final Function(String) onToolSelected;

  const OutilsEcritureSection({super.key, required this.onToolSelected});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: [
        ElevatedButton.icon(
          onPressed: () => onToolSelected('livre'),
          icon: const Icon(Icons.book),
          label: const Text("Nouveau Livre"),
        ),
        ElevatedButton.icon(
          onPressed: () => onToolSelected('chapitre'),
          icon: const Icon(Icons.note_add),
          label: const Text("Nouveau Chapitre"),
        ),
        ElevatedButton.icon(
          onPressed: () => onToolSelected('template'),
          icon: const Icon(Icons.dashboard_customize),
          label: const Text("Templates"),
        ),
      ],
    );
  }
}
