import 'package:flutter/material.dart';

import 'package:space_learn_flutter/core/space_learn/pages/widgets/auteur/statistiques/graphique_revenus.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/auteur/statistiques/stat_card.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/auteur/statistiques/stat_detail.dart';
import 'package:space_learn_flutter/core/themes/app_colors.dart';

class StatsPage extends StatelessWidget {
  final VoidCallback? onBackPressed;

  const StatsPage({super.key, this.onBackPressed});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: const Text(
          'Statistiques',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (onBackPressed != null) {
              onBackPressed!();
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const StatistiquesWidget(),
            const SizedBox(height: 16),
            const RevenueChart(),
            const SizedBox(height: 16),
            const DetailedStatistics(),
            const SizedBox(height: 16),
            const GrowthIndicatorsWidget(),
          ],
        ),
      ),
    );
  }
}
