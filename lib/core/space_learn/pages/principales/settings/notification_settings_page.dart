import 'package:flutter/material.dart';
import 'package:space_learn_flutter/core/utils/preferences_notifications.dart';
import 'package:space_learn_flutter/core/themes/app_dimensions.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/utils/app_notifications.dart';

class NotificationSettingsPage extends StatefulWidget {
  final bool isAuthorMode;
  const NotificationSettingsPage({super.key, this.isAuthorMode = false});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  bool _readingReminders = true;
  bool _newChapters = true;
  bool _salesReminders = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _readingReminders = prefs.getBool(PreferencesNotifications.cleRappelsLecture) ?? true;
        _newChapters = prefs.getBool(PreferencesNotifications.cleCommunaute) ?? true;
        _salesReminders = prefs.getBool(PreferencesNotifications.cleVentes) ?? true;
        _isLoading = false;
      });
    }
  }

  Future<void> _savePreference(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
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
          "Notifications",
          style: GoogleFonts.poppins(
            color: isDark ? Colors.white : AppColors.accentInk,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.accentInk))
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            "Gérer vos alertes",
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 8),
          Text(
            "Choisissez les notifications que vous souhaitez recevoir sur votre appareil.",
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: 28),

          // Lecture et communauté valent pour tout le monde : un auteur lit
          // aussi, et c'est lui qui reçoit les avis sur ses livres. Les masquer
          // derrière `isAuthorMode` le privait de ces deux réglages.
          ...[
            _buildSectionHeader("Lecture et communauté"),
            Card(
              color: AppColors.cardBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    title: Text(
                      "Rappels de lecture",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      "Notifications quotidiennes pour maintenir vos habitudes.",
                      style: GoogleFonts.poppins(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    value: _readingReminders,
                    activeColor: AppColors.primary,
                    onChanged: (val) {
                      setState(() => _readingReminders = val);
                      _savePreference(PreferencesNotifications.cleRappelsLecture, val);
                      AppNotifications.showSnackBar(
                        context,
                        message: "Préférences de rappels mises à jour.",
                        isSuccess: true,
                      );
                    },
                  ),
                  Divider(height: 1, indent: 16, endIndent: 16),
                  SwitchListTile(
                    title: Text(
                      "Activité de la communauté",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      "Avis reçus, messages dans un salon, nouvelle publication d'un auteur suivi.",
                      style: GoogleFonts.poppins(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    value: _newChapters,
                    activeColor: AppColors.primary,
                    onChanged: (val) {
                      setState(() => _newChapters = val);
                      _savePreference(PreferencesNotifications.cleCommunaute, val);
                      AppNotifications.showSnackBar(
                        context,
                        message: "Préférences de nouveautés mises à jour.",
                        isSuccess: true,
                      );
                    },
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),
          ],

          if (widget.isAuthorMode) ...[
            _buildSectionHeader("Ventes & Écriture"),
            Card(
              color: AppColors.cardBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    title: Text(
                      "Notifications de ventes",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      "Recevoir une alerte lors de l'achat d'un de vos livres.",
                      style: GoogleFonts.poppins(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    value: _salesReminders,
                    activeColor: AppColors.primary,
                    onChanged: (val) {
                      setState(() => _salesReminders = val);
                      _savePreference(PreferencesNotifications.cleVentes, val);
                      AppNotifications.showSnackBar(
                        context,
                        message:
                            "Préférences de notifications de ventes mises à jour.",
                        isSuccess: true,
                      );
                    },
                  ),
                  // « Nouveaux commentaires » a été retiré : les avis relèvent
                  // de l'activité de la communauté, réglée plus haut. Deux
                  // interrupteurs sur la même préférence se seraient contredits.
                ],
              ),
            ),
            SizedBox(height: 24),
          ],

          // « Offres & Nouveautés » a été retiré.
          //
          // Le serveur n'émet aucune notification promotionnelle : l'interrupteur
          // enregistrait un choix que rien ne consultait, et sa bascule affichait
          // « Préférences de promotions mises à jour » — une confirmation sans
          // objet. Le jour où de telles notifications existeront, l'interrupteur
          // reviendra avec elles, et PreferencesNotifications lui donnera son type.
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: AppColors.accentInk,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
