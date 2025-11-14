import 'package:flutter/material.dart';

import 'package:space_learn_flutter/core/space_learn/pages/widgets/auteur/livres/livre_stats.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/auteur/livres/publications_liste.dart';
import 'package:space_learn_flutter/core/themes/app_colors.dart';

class LivresPage extends StatelessWidget {
  const LivresPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: const Text(
          'Mes livres',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
