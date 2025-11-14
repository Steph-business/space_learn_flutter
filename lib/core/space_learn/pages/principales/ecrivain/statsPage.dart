import 'package:flutter/material.dart';

import 'package:space_learn_flutter/core/space_learn/pages/widgets/auteur/analytics/revenue_chart.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/auteur/analytics/stat_card.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/auteur/analytics/stat_detail.dart';
import 'package:space_learn_flutter/core/themes/app_colors.dart';

class StatsPage extends StatelessWidget {
  const StatsPage({super.key});

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
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: const [
            StatistiquesWidget(),
            SizedBox(height: 16),
            RevenueChart(),
            SizedBox(height: 16),
            DetailedStatistics(),
            SizedBox(height: 16),
            GrowthIndicatorsWidget(),
          ],
        ),
      ),
    );
  }
}
