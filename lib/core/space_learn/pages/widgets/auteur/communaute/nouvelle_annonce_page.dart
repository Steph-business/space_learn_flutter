import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/themes/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';

class NouvelleAnnoncePage extends StatefulWidget {
  const NouvelleAnnoncePage({super.key});

  @override
  State<NouvelleAnnoncePage> createState() => _NouvelleAnnoncePageState();
}

class _NouvelleAnnoncePageState extends State<NouvelleAnnoncePage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  String _selectedScope = "Tous les lecteurs";

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.scaffoldBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Iconsax.arrow_left_2, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          "NOUVELLE ANNONCE",
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Publiez une annonce pour informer votre communauté des nouveautés, promotions, ou de l'avancement de vos projets.",
              style: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 14),
            ),
            const SizedBox(height: 30),

            _buildLabel("Titre de l'annonce"),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _titleController,
              hint: "Ex: Sortie du Tome 3 prévue pour la fin d'année !",
            ),
            const SizedBox(height: 20),

            _buildLabel("Audience"),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedScope,
                  isExpanded: true,
                  dropdownColor: AppColors.cardBackground,
                  icon: const Icon(
                    Iconsax.arrow_down_1,
                    color: Colors.white54,
                    size: 18,
                  ),
                  style: AppTextStyles.body,
                  items:
                      [
                        "Tous les lecteurs",
                        "Lecteurs VIP seulement",
                        "Forums de livres spécifiques",
                      ].map((scope) {
                        return DropdownMenuItem<String>(
                          value: scope,
                          child: Text(scope),
                        );
                      }).toList(),
                  onChanged: (value) {
                    setState(() {
                      if (value != null) _selectedScope = value;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),

            _buildLabel("Contenu"),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _contentController,
              hint: "Rédigez votre annonce ici...",
              maxLines: 8,
            ),
            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Annonce publiée !")),
                  );
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondaryVariant,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  "Publier",
                  style: AppTextStyles.subtitle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: AppTextStyles.body,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.poppins(color: Colors.white30, fontSize: 14),
        filled: true,
        fillColor: AppColors.cardBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.secondaryVariant),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }
}
