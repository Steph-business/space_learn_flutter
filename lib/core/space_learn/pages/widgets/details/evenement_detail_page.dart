import 'package:flutter/material.dart';
import 'package:space_learn_flutter/core/themes/app_dimensions.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/utils/app_notifications.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/evenementModel.dart';

import 'package:space_learn_flutter/core/space_learn/data/dataServices/authServices.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/evenementService.dart';
import 'package:space_learn_flutter/core/utils/token_storage.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/auteur/communaute/nouvelle_annonce_page.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/auteur/communaute/creer_evenement_page.dart';
import 'package:space_learn_flutter/core/utils/message_erreur.dart';

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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        ),
        title: Text(
          "Supprimer la publication",
          style: GoogleFonts.poppins(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          "Voulez-vous vraiment supprimer définitivement cette publication ? Cette action est irréversible.",
          style: GoogleFonts.poppins(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              "Annuler",
              style: GoogleFonts.poppins(
                color: AppColors.textHint,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusInner),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              "Supprimer",
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
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
            AppNotifications.showSnackBar(
              context,
              message: "Publication supprimée avec succès.",
              isSuccess: true,
            );
            Navigator.pop(context, true);
          }
        }
      } catch (e) {
        if (mounted) {
          AppNotifications.showSnackBar(
            context,
            message: messageLisible(e, repli: "Suppression impossible."),
            isError: true,
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
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    AppColors.suivreLeTheme(context);
    final isAnnonce = _evenement.typePublication.toLowerCase() == "annonce";
    final brandColor = AppColors.secondaryVariant;
    final iconType = isAnnonce ? Iconsax.notification : Iconsax.calendar_1;
    final categoryName = isAnnonce
        ? "Annonce officielle"
        : (_evenement.categorie ?? "Événement");

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
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isAnnonce ? "ANNONCE" : "ÉVÉNEMENT",
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
        actions: _isAuthor
            ? [
                IconButton(
                  tooltip: "Modifier",
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: brandColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Iconsax.edit, color: brandColor, size: 18),
                  ),
                  onPressed: _editEvenement,
                ),
                IconButton(
                  tooltip: "Supprimer",
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Iconsax.trash,
                      color: AppColors.error,
                      size: 18,
                    ),
                  ),
                  onPressed: _confirmDelete,
                ),
                const SizedBox(width: 8),
              ]
            : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Optional banner image
            if (_evenement.imageUrl != null && _evenement.imageUrl!.isNotEmpty)
              Container(
                width: double.infinity,
                height: 220,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
                  image: DecorationImage(
                    image: NetworkImage(_evenement.imageUrl!),
                    fit: BoxFit.cover,
                  ),
                  border: Border.all(
                    color: AppColors.textPrimary.withValues(alpha: 0.08),
                  ),
                ),
              ),

            // Top Header Card (Category badge + Title + Metadata)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
                border: Border.all(
                  color: AppColors.textPrimary.withValues(alpha: 0.08),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: brandColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusPill,
                      ),
                      border: Border.all(
                        color: brandColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(iconType, color: brandColor, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          categoryName,
                          style: GoogleFonts.poppins(
                            color: brandColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Title
                  Text(
                    _evenement.titre,
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Metadata row (Date & Author)
                  Row(
                    children: [
                      Icon(Iconsax.clock, size: 15, color: AppColors.textHint),
                      const SizedBox(width: 6),
                      Text(
                        _evenement.creeLe != null
                            ? "Publié le ${DateFormat('d MMMM yyyy', 'fr_FR').format(_evenement.creeLe!)}"
                            : "Publication récente",
                        style: GoogleFonts.poppins(
                          color: AppColors.textHint,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Event Schedule details card (if date exists)
            if (_evenement.dateEvenement != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
                  border: Border.all(color: brandColor.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: brandColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusInner,
                        ),
                      ),
                      child: Icon(
                        Iconsax.calendar_tick,
                        color: brandColor,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "DATE & HEURE DE L'ÉVÉNEMENT",
                            style: GoogleFonts.poppins(
                              color: brandColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat(
                              'EEEE d MMMM yyyy à HH:mm',
                              'fr_FR',
                            ).format(_evenement.dateEvenement!),
                            style: GoogleFonts.poppins(
                              color: AppColors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Main Content Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
                border: Border.all(
                  color: AppColors.textPrimary.withValues(alpha: 0.08),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 3,
                        height: 16,
                        decoration: BoxDecoration(
                          color: brandColor,
                          borderRadius: BorderRadius.circular(
                            AppDimensions.radiusXs,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isAnnonce
                            ? "DÉTAILS DE L'ANNONCE"
                            : "PROGRAMME & DÉTAILS",
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textHint,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SelectableText(
                    _evenement.contenu,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      height: 1.7,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),

            // Visio Button (if present)
            if (_evenement.lienVisio != null &&
                _evenement.lienVisio!.isNotEmpty) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: () => _ouvrirVisio(_evenement.lienVisio!),
                  icon: const Icon(Iconsax.video, size: 20),
                  label: Text(
                    "Rejoindre la visio",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.onAccent,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandColor,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusCard,
                      ),
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Future<void> _ouvrirVisio(String lien) async {
    final uri = Uri.tryParse(lien);
    if (uri == null) {
      if (mounted) {
        AppNotifications.showSnackBar(
          context,
          message: "Lien de visio invalide",
          isError: true,
        );
      }
      return;
    }
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        AppNotifications.showSnackBar(
          context,
          message: "Impossible d'ouvrir le lien de visio",
          isError: true,
        );
      }
    }
  }
}
