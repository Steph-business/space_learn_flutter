import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/utils/app_notifications.dart';

class SalesReportPage extends StatelessWidget {
  const SalesReportPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.scaffoldBackground : const Color.fromARGB(255, 250, 249, 246),
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.scaffoldBackground : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          "Rapports de Ventes",
          style: GoogleFonts.poppins(
            color: isDark ? Colors.white : AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            "Votre tableau de bord",
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 20),

          // Total Earnings Card
          _buildEarningsCard(context),
          const SizedBox(height: 28),

          Text(
            "Historique des transactions",
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          _buildTransactionItem(context, "L'Énigme du Cosmos", "Achat Direct", "+ 3 500 FCFA", "10 Juillet 2026"),
          _buildTransactionItem(context, "Physique Quantique 101", "Achat Direct", "+ 2 000 FCFA", "08 Juillet 2026"),
          _buildTransactionItem(context, "Retrait d'argent", "Mobile Money", "- 15 000 FCFA", "01 Juillet 2026"),
        ],
      ),
    );
  }

  Widget _buildEarningsCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFF0284C7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Gains Totaux",
            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            "178 500 FCFA",
            style: GoogleFonts.poppins(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Solde disponible", style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
                  Text("34 200 FCFA", style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              ElevatedButton(
                onPressed: () {
                  AppNotifications.showSnackBar(context, message: "Demande de retrait mobile money envoyée !", isSuccess: true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text("Retirer", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(BuildContext context, String title, String type, String amount, String date) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPositive = amount.startsWith('+');
    return Card(
      color: isDark ? AppColors.cardBackground : Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isPositive ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isPositive ? Icons.arrow_upward : Icons.arrow_downward,
            color: isPositive ? Colors.green : Colors.red,
            size: 20,
          ),
        ),
        title: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87, fontSize: 14)),
        subtitle: Text("$type • $date", style: GoogleFonts.poppins(color: isDark ? Colors.white70 : Colors.black54, fontSize: 12)),
        trailing: Text(
          amount,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: isPositive ? Colors.green : Colors.red,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
