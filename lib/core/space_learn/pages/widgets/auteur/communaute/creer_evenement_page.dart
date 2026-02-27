import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/themes/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/evenementService.dart';
import 'package:space_learn_flutter/core/utils/token_storage.dart';

import 'package:space_learn_flutter/core/space_learn/data/model/evenementModel.dart';

class CreerEvenementPage extends StatefulWidget {
  final Evenement? initialEvenement;
  const CreerEvenementPage({super.key, this.initialEvenement});

  @override
  State<CreerEvenementPage> createState() => _CreerEvenementPageState();
}

class _CreerEvenementPageState extends State<CreerEvenementPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final EvenementService _evenementService = EvenementService();
  String _eventType = "Séance de Dédicace";
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialEvenement != null) {
      _titleController.text = widget.initialEvenement!.titre;
      _descController.text = widget.initialEvenement!.contenu;
      _eventType = widget.initialEvenement!.typePublication;
      _selectedDate = widget.initialEvenement!.dateEvenement;
      if (widget.initialEvenement!.dateEvenement != null) {
        _selectedTime = TimeOfDay.fromDateTime(
          widget.initialEvenement!.dateEvenement!,
        );
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.success,
              onPrimary: Colors.white,
              surface: AppColors.cardBackground,
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: AppColors.scaffoldBackground,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            timePickerTheme: const TimePickerThemeData(
              backgroundColor: AppColors.cardBackground,
              dialHandColor: AppColors.success,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
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
          widget.initialEvenement != null
              ? "MODIFIER L'ÉVÉNEMENT"
              : "NOUVEL ÉVÉNEMENT",
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
              "Organisez un événement pour réunir votre communauté (virtuel ou physique).",
              style: AppTextStyles.grey14,
            ),
            const SizedBox(height: 30),

            _buildLabel("Type d'événement"),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _eventType,
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
                        "Séance de Dédicace",
                        "Live Q&A",
                        "Lancement de livre",
                        "Atelier d'écriture",
                      ].map((type) {
                        return DropdownMenuItem<String>(
                          value: type,
                          child: Text(type),
                        );
                      }).toList(),
                  onChanged: (value) {
                    setState(() {
                      if (value != null) _eventType = value;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),

            _buildLabel("Titre de l'événement"),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _titleController,
              hint: "Ex: Soirée questions/réponses sur...",
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel("Date"),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: _pickDate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.cardBackground,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _selectedDate == null
                                    ? "Choisir"
                                    : "${_selectedDate!.day.toString().padLeft(2, '0')}/${_selectedDate!.month.toString().padLeft(2, '0')}/${_selectedDate!.year}",
                                style: GoogleFonts.poppins(
                                  color: _selectedDate == null
                                      ? Colors.white30
                                      : Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                              const Icon(
                                Iconsax.calendar,
                                color: Colors.white54,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel("Heure"),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: _pickTime,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.cardBackground,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _selectedTime == null
                                    ? "Choisir"
                                    : _selectedTime!.format(context),
                                style: GoogleFonts.poppins(
                                  color: _selectedTime == null
                                      ? Colors.white30
                                      : Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                              const Icon(
                                Iconsax.clock,
                                color: Colors.white54,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            _buildLabel("Description"),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _descController,
              hint: "Détails de l'événement (lien visio, adresse)...",
              maxLines: 5,
            ),
            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isCreating ? null : _createEvent,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isCreating
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        widget.initialEvenement != null
                            ? "Sauvegarder les modifications"
                            : "Créer l'événement",
                        style: AppTextStyles.subtitle,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createEvent() async {
    final title = _titleController.text.trim();
    final desc = _descController.text.trim();

    if (title.isEmpty ||
        desc.isEmpty ||
        _selectedDate == null ||
        _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez remplir tous les champs.")),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      final token = await TokenStorage.getToken();
      if (token == null) throw Exception("Session expirée");

      // Combine date and time
      final eventDate = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      if (widget.initialEvenement != null) {
        await _evenementService.updateEvenement(
          id: widget.initialEvenement!.id,
          typePublication: _eventType,
          titre: title,
          contenu: desc,
          token: token,
          dateEvenement: eventDate,
        );
      } else {
        await _evenementService.createEvenement(
          typePublication: "Evenement",
          titre: title,
          contenu: desc,
          token: token,
          dateEvenement: eventDate,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.initialEvenement != null
                  ? "Événement mis à jour !"
                  : "Événement créé avec succès !",
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
      if (mounted) setState(() => _isCreating = false);
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
          borderSide: const BorderSide(color: AppColors.success),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }
}
