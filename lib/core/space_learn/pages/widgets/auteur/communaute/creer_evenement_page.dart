import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/utils/app_notifications.dart';
import 'package:space_learn_flutter/core/themes/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:space_learn_flutter/core/themes/app_dimensions.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/evenementService.dart';
import 'package:space_learn_flutter/core/utils/token_storage.dart';

import 'package:space_learn_flutter/core/space_learn/data/model/evenementModel.dart';
import 'package:space_learn_flutter/core/utils/message_erreur.dart';

class CreerEvenementPage extends StatefulWidget {
  final Evenement? initialEvenement;
  const CreerEvenementPage({super.key, this.initialEvenement});

  @override
  State<CreerEvenementPage> createState() => _CreerEvenementPageState();
}

class _CreerEvenementPageState extends State<CreerEvenementPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _visioController = TextEditingController();
  final TextEditingController _customTypeController = TextEditingController();
  final EvenementService _evenementService = EvenementService();

  static const String _autreTypeOption = 'autre_custom';
  static const List<String> _predefinedTypes = [
    "Séance de Dédicace",
    "Live Q&A",
    "Lancement de livre",
    "Atelier d'écriture",
    "Club de lecture",
    "Conférence / Débat",
  ];

  String _eventType = "Séance de Dédicace";
  bool _showCustomType = false;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialEvenement != null) {
      _titleController.text = widget.initialEvenement!.titre;
      _descController.text = widget.initialEvenement!.contenu;
      final cat = widget.initialEvenement!.categorie ?? _eventType;
      if (_predefinedTypes.contains(cat)) {
        _eventType = cat;
        _showCustomType = false;
      } else if (cat.isNotEmpty) {
        _eventType = _autreTypeOption;
        _customTypeController.text = cat;
        _showCustomType = true;
      }
      // La date du modèle est déjà en heure LOCALE (evenementModel la convertit
      // à la lecture) : le formulaire réaffiche donc à l'auteur l'heure qu'il
      // lit partout ailleurs dans l'application. Aucune conversion ici — une
      // seconde par-dessus la première décalerait le rendez-vous à chaque
      // ouverture du formulaire de modification.
      _selectedDate = widget.initialEvenement!.dateEvenement;
      if (widget.initialEvenement!.dateEvenement != null) {
        _selectedTime = TimeOfDay.fromDateTime(
          widget.initialEvenement!.dateEvenement!,
        );
      }
      _visioController.text = widget.initialEvenement!.lienVisio ?? '';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _visioController.dispose();
    _customTypeController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppColors.secondaryVariant,
              onPrimary: AppColors.onAccent,
              surface: AppColors.cardBackground,
              onSurface: AppColors.textPrimary,
              surfaceContainerHighest: AppColors.cardBackground,
              onSurfaceVariant: AppColors.textSecondary,
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: AppColors.cardBackground,
            ),
            scaffoldBackgroundColor: AppColors.cardBackground,
            datePickerTheme: DatePickerThemeData(
              backgroundColor: AppColors.cardBackground,
              headerBackgroundColor: AppColors.cardBackground,
              headerForegroundColor: AppColors.textPrimary,
              surfaceTintColor: Colors.transparent,
              dayForegroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppColors.onAccent;
                }
                if (states.contains(WidgetState.disabled)) {
                  return AppColors.textHint;
                }
                return AppColors.textPrimary;
              }),
              dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppColors.secondaryVariant;
                }
                return Colors.transparent;
              }),
              todayForegroundColor: WidgetStateProperty.all(
                AppColors.secondaryVariant,
              ),
              todayBorder: BorderSide(color: AppColors.secondaryVariant),
              cancelButtonStyle: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
              ),
              confirmButtonStyle: TextButton.styleFrom(
                foregroundColor: AppColors.secondaryVariant,
                textStyle: const TextStyle(fontWeight: FontWeight.bold),
              ),
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
      initialTime: _selectedTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppColors.secondaryVariant,
              onPrimary: AppColors.onAccent,
              surface: AppColors.cardBackground,
              onSurface: AppColors.textPrimary,
              surfaceContainerHighest: AppColors.darkSurface,
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: AppColors.cardBackground,
            ),
            timePickerTheme: TimePickerThemeData(
              backgroundColor: AppColors.cardBackground,
              hourMinuteColor: AppColors.darkSurface,
              hourMinuteTextColor: AppColors.textPrimary,
              dayPeriodColor: AppColors.darkSurface,
              dayPeriodTextColor: AppColors.textPrimary,
              dialBackgroundColor: AppColors.darkSurface,
              dialHandColor: AppColors.secondaryVariant,
              dialTextColor: AppColors.textPrimary,
              entryModeIconColor: AppColors.secondaryVariant,
              cancelButtonStyle: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
              ),
              confirmButtonStyle: TextButton.styleFrom(
                foregroundColor: AppColors.secondaryVariant,
                textStyle: const TextStyle(fontWeight: FontWeight.bold),
              ),
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
    AppColors.suivreLeTheme(context);
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.scaffoldBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Iconsax.arrow_left_2,
            color: AppColors.textPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.initialEvenement != null
              ? "MODIFIER L'ÉVÉNEMENT"
              : "NOUVEL ÉVÉNEMENT",
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
                borderRadius: BorderRadius.circular(AppDimensions.radiusInner),
                border: Border.all(
                  color: AppColors.textPrimary.withValues(alpha: 0.1),
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _showCustomType ? _autreTypeOption : _eventType,
                  isExpanded: true,
                  dropdownColor: AppColors.cardBackground,
                  icon: Icon(
                    Iconsax.arrow_down_1,
                    color: AppColors.textHint,
                    size: 18,
                  ),
                  style: GoogleFonts.poppins(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                  ),
                  items: [
                    ..._predefinedTypes.map((type) {
                      return DropdownMenuItem<String>(
                        value: type,
                        child: Text(type),
                      );
                    }),
                    DropdownMenuItem<String>(
                      value: _autreTypeOption,
                      child: Text(
                        "Autre (personnalisé)...",
                        style: GoogleFonts.poppins(
                          color: AppColors.secondaryVariant,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      if (value == _autreTypeOption) {
                        _showCustomType = true;
                      } else if (value != null) {
                        _showCustomType = false;
                        _eventType = value;
                        _customTypeController.clear();
                      }
                    });
                  },
                ),
              ),
            ),
            if (_showCustomType) ...[
              const SizedBox(height: 12),
              _buildTextField(
                controller: _customTypeController,
                hint:
                    "Saisir votre type d'événement personnalisé (ex: Webinaire, Masterclass...)",
              ),
            ],
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
                            borderRadius: BorderRadius.circular(
                              AppDimensions.radiusInner,
                            ),
                            border: Border.all(
                              color: AppColors.textPrimary.withValues(
                                alpha: 0.1,
                              ),
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
                                      ? AppColors.textHint
                                      : AppColors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: _selectedDate == null
                                      ? FontWeight.normal
                                      : FontWeight.w500,
                                ),
                              ),
                              Icon(
                                Iconsax.calendar,
                                color: AppColors.textHint,
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
                            borderRadius: BorderRadius.circular(
                              AppDimensions.radiusInner,
                            ),
                            border: Border.all(
                              color: AppColors.textPrimary.withValues(
                                alpha: 0.1,
                              ),
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
                                      ? AppColors.textHint
                                      : AppColors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: _selectedTime == null
                                      ? FontWeight.normal
                                      : FontWeight.w500,
                                ),
                              ),
                              Icon(
                                Iconsax.clock,
                                color: AppColors.textHint,
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
              hint:
                  "Détails de l'événement (lieu, programme, comment participer…)",
              maxLines: 5,
            ),
            const SizedBox(height: 20),

            _buildLabel("Lien de visio (optionnel)"),
            const SizedBox(height: 4),
            Text(
              "Google Meet, Zoom, Jitsi, YouTube Live…",
              style: AppTextStyles.grey12,
            ),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _visioController,
              hint: "https://meet.google.com/abc-defg-hij",
              maxLines: 1,
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isCreating ? null : _createEvent,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondaryVariant,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusCard,
                    ),
                  ),
                ),
                child: _isCreating
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: AppColors.onAccent,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        widget.initialEvenement != null
                            ? "Sauvegarder les modifications"
                            : "Créer l'événement",
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.onAccent,
                        ),
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
    final customType = _customTypeController.text.trim();

    if (_showCustomType && customType.isEmpty) {
      AppNotifications.showSnackBar(
        context,
        message: "Veuillez préciser le type d'événement personnalisé.",
        isError: true,
      );
      return;
    }

    if (title.isEmpty ||
        desc.isEmpty ||
        _selectedDate == null ||
        _selectedTime == null) {
      AppNotifications.showSnackBar(
        context,
        message: "Veuillez remplir tous les champs obligatoires.",
        isError: true,
      );
      return;
    }

    final finalEventType = _showCustomType ? customType : _eventType;

    setState(() => _isCreating = true);

    try {
      final token = await TokenStorage.getToken();
      if (token == null) throw Exception("Session expirée");

      // L'heure choisie est celle de l'ORGANISATEUR, sur sa propre horloge.
      //
      // `DateTime(...)` construit donc volontairement une date locale : c'est
      // bien « 18 h chez moi » que l'auteur vient de désigner. Le service la
      // convertit ensuite en instant UTC avant l'envoi — voir
      // `_instantPourLeServeur`. Un lecteur d'un autre fuseau verra l'heure
      // correspondante chez lui, pas ce même 18 h déplacé.
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
          typePublication: "EVENEMENT",
          categorie: finalEventType,
          titre: title,
          contenu: desc,
          token: token,
          dateEvenement: eventDate,
          lienVisio: _visioController.text.trim().isEmpty
              ? null
              : _visioController.text.trim(),
        );
      } else {
        await _evenementService.createEvenement(
          typePublication: "EVENEMENT",
          categorie: finalEventType,
          titre: title,
          contenu: desc,
          token: token,
          dateEvenement: eventDate,
          lienVisio: _visioController.text.trim().isEmpty
              ? null
              : _visioController.text.trim(),
        );
      }

      if (mounted) {
        AppNotifications.showSnackBar(
          context,
          message: widget.initialEvenement != null
              ? "Événement mis à jour !"
              : "Événement créé avec succès !",
          isSuccess: true,
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        AppNotifications.showSnackBar(
          context,
          message: messageLisible(
            e,
            repli: "Cet événement n'a pas pu être enregistré.",
          ),
          isError: true,
        );
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
    TextInputType keyboardType = TextInputType.multiline,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: maxLines == 1 ? keyboardType : TextInputType.multiline,
      style: AppTextStyles.body,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.poppins(color: AppColors.textHint, fontSize: 14),
        filled: true,
        fillColor: AppColors.cardBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusInner),
          borderSide: BorderSide(
            color: AppColors.textPrimary.withValues(alpha: 0.1),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusInner),
          borderSide: BorderSide(
            color: AppColors.textPrimary.withValues(alpha: 0.1),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusInner),
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
