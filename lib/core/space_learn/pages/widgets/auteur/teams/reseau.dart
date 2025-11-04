import 'package:flutter/material.dart';

class Reseau extends StatelessWidget {
  const Reseau({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        "Votre réseau s'affichera ici.",
        style: TextStyle(fontSize: 18, color: Colors.grey),
      ),
    );
  }
}
