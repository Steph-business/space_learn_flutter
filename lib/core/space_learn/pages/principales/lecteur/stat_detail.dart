import 'package:flutter/material.dart';

class DetailedStatistics extends StatelessWidget {
  const DetailedStatistics({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              "Statistiques Détaillées",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            ListTile(
              leading: Icon(Icons.person),
              title: Text("Nouveaux abonnés"),
              trailing: Text("+56"),
            ),
            ListTile(
              leading: Icon(Icons.share),
              title: Text("Partages"),
              trailing: Text("+120"),
            ),
          ],
        ),
      ),
    );
  }
}

class GrowthIndicatorsWidget extends StatelessWidget {
  const GrowthIndicatorsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              "Indicateurs de Croissance",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text("La croissance de vos revenus est de 15% ce mois-ci."),
          ],
        ),
      ),
    );
  }
}
