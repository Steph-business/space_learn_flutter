import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/book_model.dart';

class StatistiquesLivrePage extends StatelessWidget {
  final BookModel book;

  const StatistiquesLivrePage({super.key, required this.book});

  @override
  Widget build(BuildContext context) {
    // Calcul de données factices pour le graphique afin d'animer la page
    // Ou nous pouvons utiliser le nombre de téléchargements comme indicateur global
    final int estimatedRevenue = book.telechargements * book.prix;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "Statistiques : ${book.titre}",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 16,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Couverture et Info de base
            Row(
              children: [
                Container(
                  width: 80,
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child:
                      book.imageCouverture != null &&
                          book.imageCouverture!.isNotEmpty &&
                          !book.imageCouverture!.contains('example.com')
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            book.imageCouverture!,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.book,
                            color: Colors.white24,
                            size: 40,
                          ),
                        ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book.titre,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: book.statut == 'publie'
                              ? Colors.green.withOpacity(0.2)
                              : Colors.orange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          book.statut == 'publie' ? "En ligne" : book.statut,
                          style: TextStyle(
                            color: book.statut == 'publie'
                                ? Colors.greenAccent
                                : Colors.orangeAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Prix : ${book.prix} €",
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),

            // KPIs
            Row(
              children: [
                Expanded(
                  child: _buildKpiCard(
                    title: "Téléchargements",
                    value: "${book.telechargements}",
                    icon: Icons.download_rounded,
                    color: const Color(0xFF0EA5E9),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildKpiCard(
                    title: "Note",
                    value: "${book.noteMoyenne}/5",
                    icon: Icons.star_rounded,
                    color: Colors.amber,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildKpiCard(
              title: "Revenus (Estimés)",
              value: "$estimatedRevenue €",
              icon: Icons.account_balance_wallet_rounded,
              color: const Color(0xFF10B981), // Green
            ),
            const SizedBox(height: 30),

            // Graphique des Ventes (Mocks)
            Text(
              "Évolution (30 derniers jours)",
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 250,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(20),
              ),
              child: _buildChart(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Icon(icon, color: color, size: 18),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChart() {
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) {
            return FlLine(color: Colors.white.withOpacity(0.1), strokeWidth: 1);
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: 1,
              getTitlesWidget: (value, meta) {
                const style = TextStyle(color: Colors.grey, fontSize: 10);
                String text;
                switch (value.toInt()) {
                  case 0:
                    text = 'S1';
                    break;
                  case 1:
                    text = 'S2';
                    break;
                  case 2:
                    text = 'S3';
                    break;
                  case 3:
                    text = 'S4';
                    break;
                  default:
                    text = '';
                    break;
                }
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Text(text, style: style),
                );
              },
            ),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: 3,
        minY: 0,
        maxY: 100,
        lineBarsData: [
          LineChartBarData(
            spots: const [
              FlSpot(0, 20),
              FlSpot(1, 40),
              FlSpot(2, 25),
              FlSpot(3, 80),
            ],
            isCurved: true,
            color: const Color(0xFF0EA5E9),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: const Color(0xFF0EA5E9).withOpacity(0.2),
            ),
          ),
        ],
      ),
    );
  }
}
