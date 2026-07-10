import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/utils/app_notifications.dart';

class DownloadManagerPage extends StatefulWidget {
  const DownloadManagerPage({super.key});

  @override
  State<DownloadManagerPage> createState() => _DownloadManagerPageState();
}

class _DownloadManagerPageState extends State<DownloadManagerPage> {
  final List<Map<String, String>> _downloads = [
    {"title": "L'Énigme du Cosmos", "author": "Marc Laurent", "size": "14.2 Mo"},
    {"title": "Physique Quantique 101", "author": "Sophie Martin", "size": "8.5 Mo"},
    {"title": "Les Fondements de la Relativité", "author": "Albert E.", "size": "21.1 Mo"},
  ];

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
          "Téléchargements",
          style: GoogleFonts.poppins(
            color: isDark ? Colors.white : AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: _downloads.isEmpty
          ? Center(
              child: Text(
                "Aucun téléchargement trouvé.",
                style: GoogleFonts.poppins(color: isDark ? Colors.white60 : Colors.black54),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _downloads.length,
              itemBuilder: (context, index) {
                final item = _downloads[index];
                return Card(
                  color: isDark ? AppColors.cardBackground : Colors.white,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: const Icon(Icons.picture_as_pdf, color: AppColors.error, size: 32),
                    title: Text(item["title"]!, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                    subtitle: Text("${item["author"]!} • ${item["size"]!}", style: GoogleFonts.poppins(color: isDark ? Colors.white70 : Colors.black54, fontSize: 13)),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppColors.error),
                      onPressed: () {
                        setState(() {
                          _downloads.removeAt(index);
                        });
                        AppNotifications.showSnackBar(context, message: "Livre supprimé de l'appareil.", isSuccess: true);
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}
