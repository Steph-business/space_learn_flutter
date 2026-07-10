import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/utils/app_notifications.dart';

class NotificationSettingsPage extends StatefulWidget {
  final bool isAuthorMode;
  const NotificationSettingsPage({super.key, this.isAuthorMode = false});

  @override
  State<NotificationSettingsPage> createState() => _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  bool _readingReminders = true;
  bool _newChapters = true;
  bool _salesReminders = true;
  bool _newComments = true;
  bool _marketingPush = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.scaffoldBackground : const Color.fromARGB(255, 250, 249, 246),
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.scaffoldBackground : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          "Notifications",
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
            "Gérer vos alertes",
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Choisissez les notifications que vous souhaitez recevoir sur votre appareil.",
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: 28),
          
          if (!widget.isAuthorMode) ...[
            _buildSectionHeader("Lecture"),
            Card(
              color: isDark ? AppColors.cardBackground : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  SwitchListTile(
                    title: Text("Rappels de lecture", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87, fontSize: 14)),
                    subtitle: Text("Notifications quotidiennes pour maintenir vos habitudes.", style: GoogleFonts.poppins(color: isDark ? Colors.white70 : Colors.black54, fontSize: 12)),
                    value: _readingReminders,
                    activeColor: AppColors.primary,
                    onChanged: (val) {
                      setState(() => _readingReminders = val);
                      AppNotifications.showSnackBar(context, message: "Préférences de rappels mises à jour.", isSuccess: true);
                    },
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  SwitchListTile(
                    title: Text("Nouveaux chapitres", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87, fontSize: 14)),
                    subtitle: Text("Être alerté dès qu'un auteur publie une suite.", style: GoogleFonts.poppins(color: isDark ? Colors.white70 : Colors.black54, fontSize: 12)),
                    value: _newChapters,
                    activeColor: AppColors.primary,
                    onChanged: (val) {
                      setState(() => _newChapters = val);
                      AppNotifications.showSnackBar(context, message: "Préférences de nouveautés mises à jour.", isSuccess: true);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          if (widget.isAuthorMode) ...[
            _buildSectionHeader("Ventes & Écriture"),
            Card(
              color: isDark ? AppColors.cardBackground : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  SwitchListTile(
                    title: Text("Notifications de ventes", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87, fontSize: 14)),
                    subtitle: Text("Recevoir une alerte lors de l'achat d'un de vos livres.", style: GoogleFonts.poppins(color: isDark ? Colors.white70 : Colors.black54, fontSize: 12)),
                    value: _salesReminders,
                    activeColor: AppColors.primary,
                    onChanged: (val) {
                      setState(() => _salesReminders = val);
                      AppNotifications.showSnackBar(context, message: "Préférences de notifications de ventes mises à jour.", isSuccess: true);
                    },
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  SwitchListTile(
                    title: Text("Nouveaux commentaires", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87, fontSize: 14)),
                    subtitle: Text("Être notifié quand un lecteur laisse son avis.", style: GoogleFonts.poppins(color: isDark ? Colors.white70 : Colors.black54, fontSize: 12)),
                    value: _newComments,
                    activeColor: AppColors.primary,
                    onChanged: (val) {
                      setState(() => _newComments = val);
                      AppNotifications.showSnackBar(context, message: "Préférences de commentaires mises à jour.", isSuccess: true);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          _buildSectionHeader("Général"),
          Card(
            color: isDark ? AppColors.cardBackground : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: SwitchListTile(
              title: Text("Offres & Nouveautés", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87, fontSize: 14)),
              subtitle: Text("Alertes sur les promotions, événements et actus de la plateforme.", style: GoogleFonts.poppins(color: isDark ? Colors.white70 : Colors.black54, fontSize: 12)),
              value: _marketingPush,
              activeColor: AppColors.primary,
              onChanged: (val) {
                setState(() => _marketingPush = val);
                AppNotifications.showSnackBar(context, message: "Préférences de promotions mises à jour.", isSuccess: true);
              },
            ),
          ),
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
          color: AppColors.primary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
