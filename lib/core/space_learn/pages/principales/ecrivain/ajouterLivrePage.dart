import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/services/supabase_service.dart';
import 'dart:io';
import 'package:path/path.dart' as p;

class AjouterLivrePage extends StatefulWidget {
  const AjouterLivrePage({super.key});

  @override
  State<AjouterLivrePage> createState() => _AjouterLivrePageState();
}

class _AjouterLivrePageState extends State<AjouterLivrePage> {
  final _formKey = GlobalKey<FormState>();
  final _titreController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _prixController = TextEditingController();

  String? _selectedFileName;
  String? _selectedFilePath;
  String? _selectedCoverName;
  String? _selectedCoverPath;
  bool _isUploading = false;

  @override
  void dispose() {
    _titreController.dispose();
    _descriptionController.dispose();
    _prixController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'epub'],
      );

      if (result != null) {
        setState(() {
          _selectedFileName = result.files.single.name;
          _selectedFilePath = result.files.single.path;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Fichier sélectionné : $_selectedFileName")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur lors de la sélection du fichier : $e")),
      );
    }
  }

  Future<void> _pickCover() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image != null) {
        setState(() {
          _selectedCoverName = image.name;
          _selectedCoverPath = image.path;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Image sélectionnée : $_selectedCoverName")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur lors de la sélection de l'image : $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 250, 249, 246),
      appBar: AppBar(
        title: Text(
          "Publier une œuvre",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  "Détails du livre",
                  style: GoogleFonts.poppins(
                    color: Colors.black87,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  controller: _titreController,
                  label: "Titre du livre",
                  icon: Icons.book,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _descriptionController,
                  label: "Description/Synopsis",
                  icon: Icons.description,
                  maxLines: 4,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _prixController,
                  label: "Prix (en €)",
                  icon: Icons.euro,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 30),

                Text(
                  "Fichiers",
                  style: GoogleFonts.poppins(
                    color: Colors.black87,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),

                // File Upload Area
                _buildUploadCard(
                  title: "Fichier du livre (PDF/EPUB)",
                  subtitle:
                      _selectedFileName ??
                      "Appuyez pour sélectionner un fichier",
                  icon: Icons.upload_file,
                  isSelected: _selectedFileName != null,
                  onTap: _pickFile,
                ),

                const SizedBox(height: 16),

                // Cover Upload Area
                _buildUploadCard(
                  title: "Image de couverture",
                  subtitle:
                      _selectedCoverName ??
                      "Appuyez pour sélectionner une image",
                  icon: Icons.image,
                  isSelected: _selectedCoverName != null,
                  onTap: _pickCover,
                ),

                const SizedBox(height: 40),

                ElevatedButton(
                  onPressed: _isUploading
                      ? null
                      : () async {
                          if (_formKey.currentState!.validate()) {
                            if (_selectedFileName == null ||
                                _selectedCoverName == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "Veuillez sélectionner le fichier et l'image de couverture.",
                                  ),
                                ),
                              );
                              return;
                            }

                            setState(() => _isUploading = true);

                            try {
                              // 1. Upload Cover
                              final coverExt = p.extension(_selectedCoverPath!);
                              final coverPath =
                                  'covers/${DateTime.now().millisecondsSinceEpoch}$coverExt';
                              final coverUrl = await SupabaseService.uploadFile(
                                bucket: 'covers',
                                path: coverPath,
                                file: File(_selectedCoverPath!),
                              );

                              if (coverUrl == null) {
                                throw Exception(
                                  "Erreur lors de l'upload de la couverture",
                                );
                              }

                              // 2. Upload Book
                              final bookExt = p.extension(_selectedFilePath!);
                              final bookPath =
                                  'books/${DateTime.now().millisecondsSinceEpoch}$bookExt';
                              final bookUrl = await SupabaseService.uploadFile(
                                bucket: 'books',
                                path: bookPath,
                                file: File(_selectedFilePath!),
                              );

                              if (bookUrl == null) {
                                throw Exception(
                                  "Erreur lors de l'upload du livre",
                                );
                              }

                              // Logic to add book record in database could go here
                              // using coverUrl and bookUrl

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Livre publié avec succès !"),
                                  backgroundColor: Colors.green,
                                ),
                              );
                              Navigator.pop(context);
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("Échec de la publication : $e"),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            } finally {
                              if (mounted) {
                                setState(() => _isUploading = false);
                              }
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                    shadowColor: AppColors.primary.withOpacity(0.4),
                  ),
                  child: _isUploading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          'Publier maintenant',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: GoogleFonts.poppins(color: Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(color: Colors.grey[600]),
        prefixIcon: Icon(icon, color: AppColors.primary),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Ce champ est requis';
        }
        return null;
      },
    );
  }

  Widget _buildUploadCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey[200]!,
            width: 1.5,
          ),
          boxShadow: [
            if (!isSelected)
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                isSelected ? Icons.check : icon,
                color: isSelected ? Colors.white : Colors.grey[500],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      color: Colors.black87,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      color: isSelected ? AppColors.primary : Colors.grey[500],
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
