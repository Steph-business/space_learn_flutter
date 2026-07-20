import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/evenementModel.dart';

import 'package:space_learn_flutter/core/space_learn/data/dataServices/authServices.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/evenementService.dart';
import 'package:space_learn_flutter/core/utils/token_storage.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/auteur/communaute/nouvelle_annonce_page.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/auteur/communaute/creer_evenement_page.dart';

class EvenementDetailPage extends StatefulWidget {
  final Evenement evenement;

  const EvenementDetailPage({super.key, required this.evenement});

  @override
  State<EvenementDetailPage> createState() => _EvenementDetailPageState();
}

class _EvenementDetailPageState extends State<EvenementDetailPage> {
  final AuthService _authService = AuthService();
  final EvenementService _evenementService = EvenementService();
  String? _currentUserId;
  late Evenement _evenement;

  @override
  void initState() {
    super.initState();
    _evenement = widget.evenement;
    _checkOwnership();
  }

  Future<void> _checkOwnership() async {
    final token = await TokenStorage.getToken();
    if (token != null) {
      final user = await _authService.getUser(token);
      if (mounted) {
        setState(() {
          _currentUserId = user?.id;
        });
      }
    }
  }

  bool get _isAuthor =>
      _currentUserId != null && _currentUserId == _evenement.auteurId;

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: Text("Supprimer", style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          "Voulez-vous vraiment supprimer cette publication ?",
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              "Annuler",
              style: TextStyle(color: AppColors.textHint),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              "Supprimer",
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final token = await TokenStorage.getToken();
        if (token != null) {
          await _evenementService.deleteEvenement(_evenement.id, token);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Supprimé avec succès")),
            );
            Navigator.pop(context, true);
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Erreur lors de la suppression: $e")),
          );
        }
      }
    }
  }

  void _editEvenement() async {
    final isAnnonce = _evenement.typePublication.toLowerCase() == "annonce";
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => isAnnonce
            ? NouvelleAnnoncePage(initialEvenement: _evenement)
            : CreerEvenementPage(initialEvenement: _evenement),
      ),
    );

    if (result == true && mounted) {
      // Refresh local data after edit
      try {
        final token = await TokenStorage.getToken();
        if (token != null) {
          final updated = await _evenementService.getEvenementById(
            _evenement.id,
            token,
          );
          if (mounted) {
            setState(() {
              _evenement = updated;
            });
          }
        }
      } catch (e) {
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAnnonce = _evenement.typePublication.toLowerCase() == "annonce";
    final colorType = isAnnonce
        ? AppColors.secondaryVariant
        : AppColors.success;
    final iconType = isAnnonce ? Iconsax.notification : Iconsax.calendar;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.scaffoldBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Iconsax.arrow_left_2, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isAnnonce ? "ANNONCE" : "ÉVÉNEMENT",
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: colorType,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
        actions: _isAuthor
            ? [
                IconButton(
                  icon: Icon(Iconsax.edit, color: AppColors.textPrimary, size: 20),
                  onPressed: _editEvenement,
                ),
                IconButton(
                  icon: Icon(
                    Iconsax.trash,
                    color: Colors.redAccent,
                    size: 20,
                  ),
                  onPressed: _confirmDelete,
                ),
              ]
            : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_evenement.imageUrl != null && _evenement.imageUrl!.isNotEmpty)
              Container(
                width: double.infinity,
                height: 200,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  image: DecorationImage(
                    image: NetworkImage(_evenement.imageUrl!),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colorType.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(iconType, color: colorType, size: 24),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _evenement.titre,
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (_evenement.dateEvenement != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            "Le ${DateFormat('dd MMMM yyyy', 'fr_FR').format(_evenement.dateEvenement!)}",
                            style: GoogleFonts.poppins(
                              color: colorType,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 32),
            Text(
              "CONTENU",
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary.withOpacity(0.4),
                letterSpacing: 1.5,
              ),
            ),
            SizedBox(height: 16),
            Text(
              _evenement.contenu,
              style: GoogleFonts.poppins(
                fontSize: 16,
                height: 1.6,
                color: AppColors.textPrimary.withOpacity(0.9),
              ),
            ),
            SizedBox(height: 40),
            if (_evenement.creeLe != null)
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  "Publié le ${DateFormat('dd/MM/yyyy').format(_evenement.creeLe!)}",
                  style: GoogleFonts.poppins(
                    color: AppColors.textHint,
                    fontSize: 12,
                  ),
                ),
              ),
            SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}