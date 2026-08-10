import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:space_learn_flutter/core/space_learn/data/dataServices/reversementService.dart';
import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/themes/app_dimensions.dart';
import 'package:space_learn_flutter/core/themes/widgets/app_card.dart';
import 'package:space_learn_flutter/core/utils/app_notifications.dart';
import 'package:space_learn_flutter/core/utils/token_storage.dart';

/// Saisie du numéro Mobile Money vers lequel l'auteur est payé.
///
/// Sans ce numéro, les reversements restent au statut « sans_infos » : la somme
/// est bien enregistrée comme due, mais aucun virement ne peut partir.
class PayoutInfoPage extends StatefulWidget {
  const PayoutInfoPage({super.key});

  @override
  State<PayoutInfoPage> createState() => _PayoutInfoPageState();
}

class _PayoutInfoPageState extends State<PayoutInfoPage> {
  final _formKey = GlobalKey<FormState>();
  final _reversementService = ReversementService();

  final _telephoneController = TextEditingController();
  final _nomController = TextEditingController();

  /// Indicatifs des pays couverts par CinetPay en zone Mobile Money.
  static const List<(String, String)> _indicatifs = [
    ('225', "Côte d'Ivoire"),
    ('221', 'Sénégal'),
    ('226', 'Burkina Faso'),
    ('223', 'Mali'),
    ('228', 'Togo'),
    ('229', 'Bénin'),
    ('227', 'Niger'),
    ('224', 'Guinée'),
    ('237', 'Cameroun'),
  ];

  String _prefix = '225';
  bool _isLoading = true;
  bool _isSaving = false;
  bool _dejaEnregistre = false;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void dispose() {
    _telephoneController.dispose();
    _nomController.dispose();
    super.dispose();
  }

  Future<void> _charger() async {
    try {
      final token = await TokenStorage.getToken();
      if (token == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final infos = await _reversementService.getInfosPaiement(token);
      if (!mounted) return;

      setState(() {
        if (infos != null) {
          if (infos.prefix.isNotEmpty &&
              _indicatifs.any((i) => i.$1 == infos.prefix)) {
            _prefix = infos.prefix;
          }
          _telephoneController.text = infos.telephone;
          _nomController.text = infos.nomComplet;
          _dejaEnregistre = infos.estRenseigne;
        }
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _enregistrer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final token = await TokenStorage.getToken();
      if (token == null) throw Exception('Session expirée');

      await _reversementService.setInfosPaiement(
        authToken: token,
        prefix: _prefix,
        telephone: _telephoneController.text.trim(),
        nomComplet: _nomController.text.trim(),
      );

      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _dejaEnregistre = true;
      });
      AppNotifications.showSnackBar(
        context,
        message: 'Numéro enregistré. Vos prochaines ventes y seront versées.',
        isSuccess: true,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      AppNotifications.showSnackBar(
        context,
        message: e.toString().replaceFirst('Exception: ', ''),
        isSuccess: false,
      );
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
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Compte de versement',
          style: GoogleFonts.poppins(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.accentInk))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(AppDimensions.screenPadding),
                children: [
                  AppCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          _dejaEnregistre
                              ? Icons.check_circle_outline
                              : Icons.info_outline,
                          color: _dejaEnregistre
                              ? AppColors.success
                              : AppColors.accentInk,
                          size: 22,
                        ),
                        const SizedBox(width: AppDimensions.spaceMd),
                        Expanded(
                          child: Text(
                            _dejaEnregistre
                                ? "Vos ventes sont versées sur ce numéro, après déduction de la commission de la plateforme."
                                : "Renseignez le numéro Mobile Money sur lequel recevoir vos ventes. Tant qu'il est absent, vos gains sont enregistrés mais ne peuvent pas vous être virés.",
                            style: GoogleFonts.poppins(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppDimensions.sectionGap),

                  Text(
                    'Pays',
                    style: GoogleFonts.poppins(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spaceSm),
                  DropdownButtonFormField<String>(
                    value: _prefix,
                    decoration: _decoration(),
                    dropdownColor: AppColors.cardBackground,
                    style: GoogleFonts.poppins(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                    items: _indicatifs
                        .map(
                          (i) => DropdownMenuItem(
                            value: i.$1,
                            child: Text('${i.$2}  (+${i.$1})'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _prefix = v);
                    },
                  ),
                  const SizedBox(height: AppDimensions.spaceLg),

                  Text(
                    'Numéro Mobile Money',
                    style: GoogleFonts.poppins(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spaceSm),
                  TextFormField(
                    controller: _telephoneController,
                    keyboardType: TextInputType.phone,
                    style: GoogleFonts.poppins(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                    decoration: _decoration(hint: '07 00 00 00 00'),
                    validator: (v) {
                      final chiffres = (v ?? '').replaceAll(
                        RegExp(r'[^0-9]'),
                        '',
                      );
                      if (chiffres.isEmpty) {
                        return 'Le numéro est obligatoire';
                      }
                      if (chiffres.length < 8) {
                        return 'Numéro trop court';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppDimensions.spaceLg),

                  Text(
                    'Nom du titulaire du compte',
                    style: GoogleFonts.poppins(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spaceSm),
                  TextFormField(
                    controller: _nomController,
                    style: GoogleFonts.poppins(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                    decoration: _decoration(hint: 'Nom et prénoms'),
                  ),
                  const SizedBox(height: AppDimensions.spaceXl),

                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _enregistrer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.onAccent,
                        disabledBackgroundColor: AppColors.primary.withValues(
                          alpha: 0.5,
                        ),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppDimensions.radiusInner,
                          ),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: AppColors.onAccent,
                              ),
                            )
                          : Text(
                              'Enregistrer',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  InputDecoration _decoration({String? hint}) {
    OutlineInputBorder bordure(Color couleur) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDimensions.radiusInner),
      borderSide: BorderSide(color: couleur),
    );

    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.poppins(color: AppColors.textHint, fontSize: 14),
      filled: true,
      fillColor: AppColors.cardBackground,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: bordure(AppColors.border),
      focusedBorder: bordure(AppColors.primary),
      errorBorder: bordure(AppColors.error),
      focusedErrorBorder: bordure(AppColors.error),
    );
  }
}
