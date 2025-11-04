import 'package:flutter/material.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/auteur/livres/livre_stats.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/auteur/livres/publications_liste.dart';

class LivresPage extends StatelessWidget {
  const LivresPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Mes livres",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[900],
                ),
              ),
              const SizedBox(height: 20),
              const LivreStatsSection(),
              const SizedBox(height: 30),
              const PublicationsList(),
            ],
          ),
        ),
      ),
    );
  }
}
