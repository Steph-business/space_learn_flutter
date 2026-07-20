import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/utils/app_notifications.dart';

class PublicationSettingsPage extends StatefulWidget {
  const PublicationSettingsPage({super.key});

  @override
  State<PublicationSettingsPage> createState() => _PublicationSettingsPageState();
}

class _PublicationSettingsPageState extends State<PublicationSettingsPage> {
  bool _defaultPublic = true;
  String _defaultLicense = "Tous droits réservés";
  String _defaultCurrency = "FCFA";
  final _royaltyController = TextEditingController(text: "70");

  final List<String> _licenses = [
    "Tous droits réservés",
    "Creative Commons BY",
    "Creative Commons BY-NC",
    "Domaine Public",
  ];

  final List<String> _currencies = ["FCFA", "EUR", "USD"];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.scaffoldBackground : Color.fromARGB(255, 250, 249, 246),
      appBar: AppBar(
        backgroundColor: AppColors.scaffoldBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          "Publication",
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
            "Paramètres de publication",
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 8),
          Text(
            "Configurez vos préférences par défaut pour vos futures œuvres.",
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: 28),
          
          Card(
            color: AppColors.cardBackground,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                SwitchListTile(
                  title: Text("Visibilité publique par défaut", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 14)),
                  subtitle: Text("Les livres créés sont directement visibles en boutique.", style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 12)),
                  value: _defaultPublic,
                  activeColor: AppColors.primary,
                  onChanged: (val) {
                    setState(() => _defaultPublic = val);
                    AppNotifications.showSnackBar(context, message: "Visibilité par défaut mise à jour.", isSuccess: true);
                  },
                ),
                Divider(height: 1, indent: 16, endIndent: 16),
                
                // Licence
                ListTile(
                  title: Text("Licence par défaut", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 14)),
                  subtitle: Text(_defaultLicense, style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 12)),
                  trailing: Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: _showLicenseSelector,
                ),
                Divider(height: 1, indent: 16, endIndent: 16),
                
                // Devise
                ListTile(
                  title: Text("Devise de vente", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 14)),
                  subtitle: Text(_defaultCurrency, style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 12)),
                  trailing: Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: _showCurrencySelector,
                ),
              ],
            ),
          ),
          SizedBox(height: 24),
          
          // Royalties / Prix
          Text(
            "Droits d'auteur & Rémunération",
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 12),
          TextFormField(
            controller: _royaltyController,
            keyboardType: TextInputType.number,
            style: GoogleFonts.poppins(color: AppColors.textPrimary),
            decoration: InputDecoration(
              labelText: "Part de l'auteur (%)",
              labelStyle: GoogleFonts.poppins(color: isDark ? AppColors.textHint : Colors.black54),
              filled: true,
              fillColor: AppColors.cardBackground,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          SizedBox(height: 32),
          
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () {
                AppNotifications.showSnackBar(context, message: "Paramètres de publication enregistrés !", isSuccess: true);
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                "Enregistrer les préférences",
                style: GoogleFonts.poppins(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLicenseSelector() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBackground,
      builder: (context) {
        return ListView(
          shrinkWrap: true,
          padding: EdgeInsets.symmetric(vertical: 20),
          children: _licenses.map((license) {
            return ListTile(
              title: Text(license, style: GoogleFonts.poppins(color: AppColors.textPrimary)),
              trailing: _defaultLicense == license ? Icon(Icons.check, color: AppColors.primary) : null,
              onTap: () {
                setState(() => _defaultLicense = license);
                Navigator.of(context).pop();
              },
            );
          }).toList(),
        );
      },
    );
  }

  void _showCurrencySelector() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBackground,
      builder: (context) {
        return ListView(
          shrinkWrap: true,
          padding: EdgeInsets.symmetric(vertical: 20),
          children: _currencies.map((currency) {
            return ListTile(
              title: Text(currency, style: GoogleFonts.poppins(color: AppColors.textPrimary)),
              trailing: _defaultCurrency == currency ? Icon(Icons.check, color: AppColors.primary) : null,
              onTap: () {
                setState(() => _defaultCurrency = currency);
                Navigator.of(context).pop();
              },
            );
          }).toList(),
        );
      },
    );
  }
}