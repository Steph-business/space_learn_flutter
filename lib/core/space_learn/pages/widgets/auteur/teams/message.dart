import 'package:flutter/material.dart';

class Messages extends StatelessWidget {
  const Messages({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        "Aucun message pour le moment.",
        style: TextStyle(fontSize: 18, color: Colors.grey),
      ),
    );
  }
}
