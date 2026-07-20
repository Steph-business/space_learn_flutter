import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/themes/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';

import 'package:space_learn_flutter/core/space_learn/data/dataServices/evenementService.dart';
import 'package:space_learn_flutter/core/utils/token_storage.dart';

import 'package:space_learn_flutter/core/space_learn/data/model/evenementModel.dart';

class NouvelleAnnoncePage extends StatefulWidget {
  final Evenement? initialEvenement;
  const NouvelleAnnoncePage({super.key, this.initialEvenement});

  @override
  State<NouvelleAnnoncePage> createState() => _NouvelleAnnoncePageState();
}

class _NouvelleAnnoncePageState extends State<NouvelleAnnoncePage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final EvenementService _evenementService = EvenementService();
  String _selectedScope = "Tous les lecteurs";
  bool _isPublishing = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialEvenement != null) {
      _titleController.text = widget.initialEvenement!.titre;
      _contentController.text = widget.initialEvenement!.contenu;
    }
  }

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
          icon: Icon(Iconsax.arrow_left_2, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.initialEvenement != null
              ? "MODIFIER L'ANNONCE"
              : "NOUVELLE ANNONCE",
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
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
              style: AppTextStyles.grey14,
            ),
            SizedBox(height: 30),

            _buildLabel("Titre de l'annonce"),
            SizedBox(height: 8),
            _buildTextField(
              controller: _titleController,
              hint: "Ex: Sortie du Tome 3 prévue pour la fin d'année !",
            ),
            SizedBox(height: 20),

            _buildLabel("Audience"),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.textPrimary.withOpacity(0.1)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedScope,
                  isExpanded: true,
                  dropdownColor: AppColors.cardBackground,
                  icon: Icon(
                    Iconsax.arrow_down_1,
                    color: AppColors.textHint,
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
            SizedBox(height: 20),

            _buildLabel("Contenu"),
            SizedBox(height: 8),
            _buildTextField(
              controller: _contentController,
              hint: "Rédigez votre annonce ici...",
              maxLines: 8,
            ),
            SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isPublishing ? null : _publishAnnonce,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondaryVariant,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isPublishing
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: AppColors.textPrimary,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        widget.initialEvenement != null
                            ? "Sauvegarder les modifications"
                            : "Publier",
                        style: AppTextStyles.subtitle,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _publishAnnonce() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty || content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez remplir tous les champs.")),
      );
      return;
    }

    setState(() => _isPublishing = true);

    try {
      final token = await TokenStorage.getToken();
      if (token == null) throw Exception("Session expirée");

      if (widget.initialEvenement != null) {
        await _evenementService.updateEvenement(
          id: widget.initialEvenement!.id,
          typePublication: "Annonce",
          titre: title,
          contenu: content,
          token: token,
        );
      } else {
        await _evenementService.createEvenement(
          typePublication: "Annonce",
          titre: title,
          contenu: content,
          token: token,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.initialEvenement != null
                  ? "Annonce mise à jour !"
                  : "Annonce publiée avec succès !",
            ),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Erreur : ${e.toString()}")));
      }
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  Widget _buildLabel(String text) {
    return Text(text, style: AppTextStyles.button14);
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
        hintStyle: GoogleFonts.poppins(color: AppColors.textHint, fontSize: 14),
        filled: true,
        fillColor: AppColors.cardBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.textPrimary.withValues(alpha: 0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.textPrimary.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.secondaryVariant),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }
}