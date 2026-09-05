import 'package:flutter/material.dart';
import 'package:space_learn_flutter/core/themes/app_dimensions.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/publication_settings_service.dart';
import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/utils/app_notifications.dart';
import 'package:space_learn_flutter/core/utils/token_storage.dart';

class PublicationSettingsPage extends StatefulWidget {
  const PublicationSettingsPage({super.key});

  @override
  State<PublicationSettingsPage> createState() =>
      _PublicationSettingsPageState();
}

class _PublicationSettingsPageState extends State<PublicationSettingsPage> {
  final PublicationSettingsService _service = PublicationSettingsService();

  bool _defaultPublic = true;
  String _defaultLicense = "Tous droits réservés";
  String _defaultCurrency = "FCFA";

  /// La part de l'auteur, telle que le serveur la calcule. Affichée, jamais
  /// saisie : le taux appartient à la plateforme.
  double _partAuteur = 0;
  double _commission = 0;

  bool _chargement = true;
  bool _enregistrement = false;
  String? _erreur;

  final List<String> _licenses = [
    "Tous droits réservés",
    "Creative Commons BY",
    "Creative Commons BY-NC",
    "Domaine Public",
  ];

  final List<String> _currencies = ["FCFA", "EUR", "USD"];

  @override
  void initState() {
    super.initState();
    _loadPublicationSettings();
  }

  Future<void> _loadPublicationSettings() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });

    try {
      final token = await TokenStorage.getToken();
      if (token == null || token.isEmpty) {
        throw Exception("Reconnectez-vous pour accéder à vos préférences.");
      }
      final p = await _service.lire(token);
      if (!mounted) return;
      setState(() {
        _defaultPublic = p.visibiliteParDefaut;
        _defaultLicense = _licenses.contains(p.licenceParDefaut)
            ? p.licenceParDefaut
            : _licenses.first;
        _defaultCurrency = _currencies.contains(p.deviseParDefaut)
            ? p.deviseParDefaut
            : _currencies.first;
        _partAuteur = p.partAuteurPourcent;
        _commission = p.commissionPourcent;
        _chargement = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erreur = _lisible(e);
        _chargement = false;
      });
    }
  }

  /// Enregistre les trois choix, d'un seul envoi. Rend vrai si le serveur a
  /// confirmé.
  ///
  /// Chaque bascule écrivait auparavant dans les préférences du téléphone, et
  /// le bouton « Enregistrer » réécrivait les mêmes clés : rien ne quittait
  /// l'appareil, et rien n'agissait sur les livres.
  ///
  /// Le résultat est rendu par la méthode elle-même : le bouton testait
  /// « _erreur == null » pour décider de fermer la page, or _erreur n'est
  /// écrit que par le chargement initial — jamais ici. Après un échec réseau,
  /// la condition restait vraie et la page se fermait comme après un succès :
  /// visibilité, licence et devise choisies étaient perdues, et le snackbar
  /// d'erreur, affiché pendant la fermeture, se ratait facilement.
  Future<bool> _enregistrer() async {
    setState(() => _enregistrement = true);
    try {
      final token = await TokenStorage.getToken();
      if (token == null || token.isEmpty) {
        throw Exception("Reconnectez-vous pour enregistrer vos préférences.");
      }
      final p = await _service.enregistrer(
        token,
        visibiliteParDefaut: _defaultPublic,
        licenceParDefaut: _defaultLicense,
        deviseParDefaut: _defaultCurrency,
      );
      // Le serveur a confirmé : l'enregistrement est acquis, que l'écran soit
      // encore là ou non.
      if (!mounted) return true;
      setState(() {
        _partAuteur = p.partAuteurPourcent;
        _commission = p.commissionPourcent;
        _enregistrement = false;
      });
      AppNotifications.showSnackBar(
        context,
        message: "Préférences de publication enregistrées.",
        isSuccess: true,
      );
      return true;
    } catch (e) {
      if (!mounted) return false;
      setState(() => _enregistrement = false);
      AppNotifications.showSnackBar(
        context,
        message: _lisible(e),
        isError: true,
      );
      return false;
    }
  }

  static String _lisible(Object erreur) {
    var t = erreur.toString();
    if (t.startsWith('Exception: ')) t = t.substring('Exception: '.length);
    return t.trim().isEmpty ? "L'opération a échoué." : t;
  }

  @override
  Widget build(BuildContext context) {
    AppColors.suivreLeTheme(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark
          ? AppColors.scaffoldBackground
          : Color.fromARGB(255, 250, 249, 246),
      appBar: AppBar(
        backgroundColor: AppColors.scaffoldBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.accentInk),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          "Publication",
          style: GoogleFonts.poppins(
            color: isDark ? Colors.white : AppColors.accentInk,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: _chargement
          ? Center(child: CircularProgressIndicator(color: AppColors.accentInk))
          // Une panne n'est pas un vide : quand le chargement initial échoue,
          // _erreur était posé puis ignoré, et l'écran affichait un formulaire
          // rempli de valeurs par défaut — qu'un « Enregistrer » aurait
          // écrites par-dessus les vraies préférences. On montre la panne et
          // on propose de réessayer.
          : _erreur != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.cloud_off_outlined,
                      size: 40,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _erreur!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadPublicationSettings,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.onAccent,
                      ),
                      child: Text(
                        "Réessayer",
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusCard,
                    ),
                  ),
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: Text(
                          "Visibilité publique par défaut",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          "Les livres créés sont directement visibles en boutique.",
                          style: GoogleFonts.poppins(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        value: _defaultPublic,
                        activeColor: AppColors.primary,
                        onChanged: (val) {
                          setState(() => _defaultPublic = val);
                        },
                      ),
                      Divider(height: 1, indent: 16, endIndent: 16),

                      // Licence
                      ListTile(
                        title: Text(
                          "Licence par défaut",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          _defaultLicense,
                          style: GoogleFonts.poppins(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        trailing: Icon(Icons.arrow_forward_ios, size: 14),
                        onTap: _showLicenseSelector,
                      ),
                      Divider(height: 1, indent: 16, endIndent: 16),

                      // Devise
                      ListTile(
                        title: Text(
                          "Devise de vente",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          _defaultCurrency,
                          style: GoogleFonts.poppins(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
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
                // La part de l'auteur se lit, elle ne se saisit pas.
                //
                // C'était un champ libre. On pouvait y taper 95, lire « Paramètres
                // enregistrés ! », et croire qu'on toucherait 95 % de ses ventes. Le
                // taux appartient à la plateforme : le serveur le calcule et le
                // renvoie, l'écran l'affiche.
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusInner,
                    ),
                    border: Border.all(
                      color: AppColors.textHint.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.percent_rounded,
                        color: AppColors.accentInk,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Vous percevez ${_partAuteur.toStringAsFixed(0)} % de chaque vente",
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Space Learn retient ${_commission.toStringAsFixed(0)} % "
                              "au titre des frais de plateforme et de paiement.",
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _enregistrement
                        ? null
                        : () async {
                            // La page ne se ferme que sur le succès CONFIRMÉ
                            // par _enregistrer : sur un échec, elle reste
                            // ouverte avec les choix intacts, prête à
                            // réessayer.
                            final ok = await _enregistrer();
                            if (ok && mounted) {
                              Navigator.of(context).pop();
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusInner,
                        ),
                      ),
                    ),
                    child: Text(
                      "Enregistrer les préférences",
                      style: GoogleFonts.poppins(
                        color: AppColors.onAccent,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  void _showLicenseSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBackground,
      builder: (context) {
        // Une feuille est une route a part : elle lit la palette sans
        // s'y abonner, donc elle garde celle du dernier ecran construit.
        AppColors.suivreLeTheme(context);
        return ListView(
          shrinkWrap: true,
          padding: EdgeInsets.symmetric(vertical: 20),
          children: _licenses.map((license) {
            return ListTile(
              title: Text(
                license,
                style: GoogleFonts.poppins(color: AppColors.textPrimary),
              ),
              trailing: _defaultLicense == license
                  ? Icon(Icons.check, color: AppColors.accentInk)
                  : null,
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
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBackground,
      builder: (context) {
        // Une feuille est une route a part : elle lit la palette sans
        // s'y abonner, donc elle garde celle du dernier ecran construit.
        AppColors.suivreLeTheme(context);
        return ListView(
          shrinkWrap: true,
          padding: EdgeInsets.symmetric(vertical: 20),
          children: _currencies.map((currency) {
            return ListTile(
              title: Text(
                currency,
                style: GoogleFonts.poppins(color: AppColors.textPrimary),
              ),
              trailing: _defaultCurrency == currency
                  ? Icon(Icons.check, color: AppColors.accentInk)
                  : null,
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
