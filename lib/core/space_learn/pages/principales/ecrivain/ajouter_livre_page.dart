import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/themes/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

import 'package:space_learn_flutter/core/services/supabase_service.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/bookService.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/categorie_service.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/authServices.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/book_model.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/categorie.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/ecrivain/accueil_auteur_page.dart';
import 'package:space_learn_flutter/core/utils/token_storage.dart';
import 'package:space_learn_flutter/core/utils/app_notifications.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

class AjouterLivrePage extends StatefulWidget {
  final BookModel? book;
  const AjouterLivrePage({super.key, this.book});

  @override
  State<AjouterLivrePage> createState() => _AjouterLivrePageState();
}

class _AjouterLivrePageState extends State<AjouterLivrePage> {
  final _formKey = GlobalKey<FormState>();
  final _titreController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _prixController = TextEditingController();
  final _categorieController = TextEditingController();

  String? _selectedFileName;
  String? _selectedFilePath;
  Uint8List? _selectedFileBytes;
  String? _selectedCoverName;
  String? _selectedCoverPath;
  Uint8List? _selectedCoverBytes;
  bool _isUploading = false;
  bool _isFree = false;

  // Services
  final CategorieService _categorieService = CategorieService();
  final BookService _bookService = BookService();
  final AuthService _authService = AuthService();

  // Liste des catégories chargées depuis l'API
  List<Categorie> _categories = [];
  bool _isLoadingCategories = true;
  String? _categoriesError;

  // Utiliser l'ID de la catégorie au lieu de l'objet pour éviter les problèmes de comparaison
  String? _selectedCategorieId;
  bool _showCustomCategorie = false;

  // Catégorie spéciale "Autre" avec un ID fixe
  static const String _autreCategorieId = 'autre_custom';

  // User info
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    if (widget.book != null) {
      _titreController.text = widget.book!.titre;
      _descriptionController.text = widget.book!.description;
      _prixController.text = widget.book!.prix.toString();
      _isFree = widget.book!.prix == 0;
      _selectedCategorieId = widget.book!.categorieId;
      _selectedFileName = widget.book!.fichierUrl?.split('/').last;
      _selectedCoverName = widget.book!.imageCouverture?.split('/').last;
    }
    _loadCategories();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final token = await TokenStorage.getToken();
      if (token != null) {
        final user = await _authService.getUser(token);
        if (user != null && mounted) {
          setState(() {
            _currentUserId = user.id;
          });
        }
      }
    } catch (e) {
    }
  }

  Future<void> _loadCategories() async {
    try {
      setState(() {
        _isLoadingCategories = true;
        _categoriesError = null;
      });

      final categories = await _categorieService.getCategories();

      if (mounted) {
        setState(() {
          _categories = categories;
          _isLoadingCategories = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _categoriesError = 'Erreur lors du chargement des catégories';
          _isLoadingCategories = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _titreController.dispose();
    _descriptionController.dispose();
    _prixController.dispose();
    _categorieController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'epub'],
        withData: kIsWeb,
      );

      if (result != null && mounted) {
        setState(() {
          _selectedFileName = result.files.single.name;
          _selectedFilePath = result.files.single.path;
          if (kIsWeb) {
            _selectedFileBytes = result.files.single.bytes;
          }
        });
        if (mounted) {
          AppNotifications.showSnackBar(
            context,
            message: "Fichier du livre sélectionné avec succès",
            isSuccess: true,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        AppNotifications.showSnackBar(
          context,
          message: "Erreur lors de la sélection du fichier : $e",
          isError: true,
        );
      }
    }
  }

  Future<void> _pickCover() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image != null && mounted) {
        final bytes = kIsWeb ? await image.readAsBytes() : null;
        setState(() {
          _selectedCoverName = image.name;
          _selectedCoverPath = image.path;
          if (kIsWeb) {
            _selectedCoverBytes = bytes;
          }
        });
        if (mounted) {
          AppNotifications.showSnackBar(
            context,
            message: "Image de couverture sélectionnée avec succès",
            isSuccess: true,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        AppNotifications.showSnackBar(
          context,
          message: "Erreur lors de la sélection de l'image : $e",
          isError: true,
        );
      }
    }
  }

  String _getFileFormat(String? filePath) {
    if (filePath == null) return 'PDF';
    final extension = p.extension(filePath).toLowerCase();
    if (extension == '.epub') return 'EPUB';
    if (extension == '.mobi') return 'MOBI';
    return 'PDF';
  }

  Future<void> _publishBook({bool isDraft = false}) async {
    if (!_formKey.currentState!.validate()) return;

    if (widget.book == null &&
        (_selectedFileName == null || _selectedCoverName == null)) {
      AppNotifications.showSnackBar(
        context,
        message: "Veuillez sélectionner le fichier et l'image de couverture.",
        isError: true,
      );
      return;
    }

    if (_currentUserId == null) {
      AppNotifications.showSnackBar(
        context,
        message: "Erreur: Utilisateur non connecté.",
        isError: true,
      );
      return;
    }

    final token = await TokenStorage.getToken();
    if (!mounted) return;
    if (token == null) {
      AppNotifications.showSnackBar(
        context,
        message: "Erreur: Session expirée. Veuillez vous reconnecter.",
        isError: true,
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      String? coverUrl = widget.book?.imageCouverture;
      String? bookUrl = widget.book?.fichierUrl;

      // 1. Upload Cover
      if (_selectedCoverPath != null || _selectedCoverBytes != null) {
        final coverExt = _selectedCoverPath != null ? p.extension(_selectedCoverPath!) : '.jpg';
        final coverPath = '${DateTime.now().millisecondsSinceEpoch}$coverExt';

        if (kIsWeb && _selectedCoverBytes != null) {
          coverUrl = await SupabaseService.uploadBytes(
            bucket: 'book_covers',
            path: coverPath,
            bytes: _selectedCoverBytes!,
          );
        } else if (_selectedCoverPath != null) {
          coverUrl = await SupabaseService.uploadFile(
            bucket: 'book_covers',
            path: coverPath,
            file: File(_selectedCoverPath!),
          );
        }

        if (coverUrl == null) {
          throw Exception("Erreur lors de l'upload de la couverture");
        }
      }

      // 2. Upload Book
      if (_selectedFilePath != null || _selectedFileBytes != null) {
        final bookExt = _selectedFilePath != null ? p.extension(_selectedFilePath!) : '.pdf';
        final bookPath = '${DateTime.now().millisecondsSinceEpoch}$bookExt';

        if (kIsWeb && _selectedFileBytes != null) {
          bookUrl = await SupabaseService.uploadBytes(
            bucket: 'books',
            path: bookPath,
            bytes: _selectedFileBytes!,
          );
        } else if (_selectedFilePath != null) {
          bookUrl = await SupabaseService.uploadFile(
            bucket: 'books',
            path: bookPath,
            file: File(_selectedFilePath!),
          );
        }

        if (bookUrl == null) {
          throw Exception("Erreur lors de l'upload du livre");
        }
      }

      // 3. Determine category ID
      String categorieId = widget.book?.categorieId ?? '';
      if (_showCustomCategorie && _categorieController.text.isNotEmpty) {
        try {
          final newCategorieMap = {
            'nom': _categorieController.text.trim(),
            'statut': 'actif',
          };
          final createdCat = await _categorieService.createCategorie(
            newCategorieMap,
            token,
          );
          categorieId = createdCat.id;
        } catch (e) {
          throw Exception("Impossible de créer la catégorie personnalisée: $e");
        }
      } else if (_selectedCategorieId != null &&
          _selectedCategorieId != _autreCategorieId) {
        categorieId = _selectedCategorieId!;
      } else if (categorieId.isEmpty) {
        final categories = await _categorieService.getCategories();
        if (categories.isNotEmpty) {
          categorieId = categories.first.id;
        } else {
          final defaultCategorieMap = {'nom': 'Général', 'statut': 'actif'};
          final defaultCategorie = await _categorieService.createCategorie(
            defaultCategorieMap,
            token,
          );
          categorieId = defaultCategorie.id;
        }
      }

      final int prixParsed = _isFree ? 0 : (int.tryParse(_prixController.text) ?? 0);
      final format = _getFileFormat(_selectedFilePath ?? bookUrl);

      if (widget.book != null) {
        // Mode modification
        if (widget.book!.id.isEmpty) {
          throw Exception(
            "Erreur : Impossible de modifier un livre sans identifiant valide.",
          );
        }

        final updates = {
          'id': widget.book!.id,
          'titre': _titreController.text.trim(),
          'description': _descriptionController.text.trim(),
          'prix': prixParsed,
          'categorie_id': categorieId,
          'fichier_url': bookUrl,
          'image_couverture': coverUrl,
          'format': format,
          'statut': isDraft ? 'brouillon' : 'publie',
          'stock': widget.book!.stock,
        };
        await _bookService.updateBook(widget.book!.id, updates, token);

        if (mounted) {
          _showSuccessDialog(isModification: true, isDraft: isDraft);
        }
      } else {
        // Mode création
        final bookToCreate = BookModel(
          id: '',
          auteurId: _currentUserId!,
          titre: _titreController.text.trim(),
          description: _descriptionController.text.trim(),
          imageCouverture: coverUrl,
          fichierUrl: bookUrl,
          format: format,
          prix: prixParsed,
          stock: 999,
          categorieId: categorieId,
          statut: isDraft ? 'brouillon' : 'publie',
          auteur: null,
        );

        await _bookService.createBook(bookToCreate, token);

        if (mounted) {
          _showSuccessDialog(isModification: false, isDraft: isDraft);
        }
      }
    } catch (e) {
      if (mounted) {
        AppNotifications.showSnackBar(
          context,
          message: "Échec de l'opération : $e",
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  void _showSuccessDialog({required bool isModification, required bool isDraft}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_outline,
                  color: Colors.green,
                  size: 64,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                "Félicitations !",
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isModification
                    ? (isDraft ? "Brouillon mis à jour avec succès." : "Votre œuvre a été modifiée avec succès.")
                    : (isDraft ? "L'œuvre a été enregistrée en tant que brouillon." : "Votre œuvre a été publiée avec succès. Elle est maintenant disponible pour vos lecteurs."),
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Fermer le dialog
                    Navigator.pop(context, true); // Fermer la page d'ajout
                    // Rediriger vers l'onglet "Mes livres" et forcer le rechargement
                    HomePageAuteur.navKey.currentState?.refreshPages();
                    HomePageAuteur.navKey.currentState?.setIndex(1);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondaryVariant,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    "Continuer",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: Text(
          widget.book != null ? "Modifier une œuvre" : "Publier une œuvre",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
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
                _buildTextField(
                  controller: _titreController,
                  label: "Titre du livre",
                  icon: Icons.book,
                ),
                SizedBox(height: 16),
                _buildTextField(
                  controller: _descriptionController,
                  label: "Description/Synopsis",
                  icon: Icons.description,
                  maxLines: 4,
                ),
                SizedBox(height: 16),

                _buildTextField(
                  controller: _prixController,
                  label: "Prix (FCFA)",
                  icon: Icons.money,
                  keyboardType: TextInputType.number,
                  enabled: !_isFree,
                ),
                SizedBox(height: 8),
                CheckboxListTile(
                  value: _isFree,
                  onChanged: (val) {
                    setState(() {
                      _isFree = val ?? false;
                      if (_isFree) {
                        _prixController.text = "0";
                      }
                    });
                  },
                  activeColor: AppColors.secondaryVariant,
                  title: Text(
                    "Publier cet ouvrage gratuitement (0 FCFA)",
                    style: GoogleFonts.poppins(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    "Les lecteurs accéderont librement à l'œuvre sans payer",
                    style: GoogleFonts.poppins(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
                SizedBox(height: 16),

                // Champ de catégorie avec dropdown
                _buildCategorieField(),
                SizedBox(height: 20),

                // File Upload Area
                Text(
                  "Fichier (PDF/EPUB)",
                  style: GoogleFonts.poppins(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 8),
                _buildUploadCard(
                  title: "Fichier (PDF/EPUB)",
                  subtitle: _selectedFileName ?? "Sélectionner un fichier",
                  icon: Icons.upload_file,
                  isSelected: _selectedFileName != null,
                  onTap: _pickFile,
                  currentUrl: _selectedFilePath == null
                      ? widget.book?.fichierUrl
                      : null,
                ),

                SizedBox(height: 16),

                // Cover Upload Area
                Text(
                  "Image de couverture",
                  style: GoogleFonts.poppins(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 8),
                _buildUploadCard(
                  title: "Image de couverture",
                  subtitle: _selectedCoverName ?? "Sélectionner une image",
                  icon: Icons.image,
                  isSelected: _selectedCoverName != null,
                  onTap: _pickCover,
                  currentUrl: _selectedCoverPath == null
                      ? widget.book?.imageCouverture
                      : null,
                  localPath: _selectedCoverPath,
                  isImage: true,
                ),
                SizedBox(height: 40),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isUploading ? null : () => _publishBook(isDraft: true),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          side: BorderSide(
                            color: _isUploading ? Colors.grey : AppColors.secondaryVariant,
                          ),
                        ),
                        child: Text(
                          "Brouillon",
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _isUploading ? Colors.grey : AppColors.secondaryVariant,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isUploading ? null : () => _publishBook(isDraft: false),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondaryVariant,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 4,
                          shadowColor: AppColors.secondaryVariant.withValues(
                            alpha: 0.4,
                          ),
                        ),
                        child: _isUploading
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: AppColors.textPrimary,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                widget.book != null
                                    ? "Modifier"
                                    : "Publier",
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategorieField() {
    if (_isLoadingCategories) {
      return Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(Icons.category, color: AppColors.secondaryVariant),
            SizedBox(width: 16),
            Text(
              "Chargement des catégories...",
              style: GoogleFonts.poppins(color: AppColors.textHint),
            ),
            const Spacer(),
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ),
      );
    }

    if (_categoriesError != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red[200]!),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 16),
            Expanded(
              child: Text(
                _categoriesError!,
                style: GoogleFonts.poppins(color: Colors.red[700]),
              ),
            ),
            IconButton(
              icon: Icon(Icons.refresh, color: Colors.red),
              onPressed: _loadCategories,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(16),
          ),
          child: DropdownButtonFormField<String>(
            dropdownColor: AppColors.cardBackground,
            iconEnabledColor: AppColors.secondaryVariant,
            style: GoogleFonts.poppins(color: AppColors.textPrimary, fontSize: 14),
            value: _selectedCategorieId,
            decoration: InputDecoration(
              labelText: "Catégorie",
              labelStyle: GoogleFonts.poppins(color: AppColors.textHint),
              prefixIcon: Icon(
                Icons.category,
                color: AppColors.secondaryVariant,
              ),
              filled: true,
              fillColor: AppColors.cardBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AppColors.secondaryVariant),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
            ),
            items: [
              // Add categories from API
              ..._categories.map((Categorie categorie) {
                return DropdownMenuItem<String>(
                  value: categorie.id,
                  child: Text(
                    categorie.nom,
                    style: GoogleFonts.poppins(color: AppColors.textPrimary),
                  ),
                );
              }),
              // Add "Autre" option for custom category
              DropdownMenuItem<String>(
                value: _autreCategorieId,
                child: Text(
                  'Autre (personnalisée)',
                  style: GoogleFonts.poppins(
                    color: AppColors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
            onChanged: (String? newValue) {
              setState(() {
                _selectedCategorieId = newValue;
                _showCustomCategorie = (newValue == _autreCategorieId);
                if (!_showCustomCategorie) {
                  _categorieController.clear();
                }
              });
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Veuillez sélectionner une catégorie';
              }
              return null;
            },
          ),
        ),
        if (_showCustomCategorie) ...[
          SizedBox(height: 16),
          _buildTextField(
            controller: _categorieController,
            label: "Saisir une catégorie personnalisée",
            icon: Icons.edit,
          ),
        ],
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
    bool enabled = true,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: GoogleFonts.poppins(
        color: enabled ? AppColors.textPrimary : AppColors.textHint,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(color: AppColors.textHint),
        prefixIcon: Icon(icon, color: AppColors.secondaryVariant),
        filled: true,
        fillColor: AppColors.cardBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.secondaryVariant),
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
    String? currentUrl,
    String? localPath,
    bool isImage = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.secondaryVariant.withValues(alpha: 0.1)
              : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.secondaryVariant.withOpacity(0.5)
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            // Preview / Icon
            if (isImage && (localPath != null || currentUrl != null))
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 44,
                  height: 60,
                  child: localPath != null
                      ? (kIsWeb
                          ? Image.network(localPath, fit: BoxFit.cover)
                          : Image.file(File(localPath), fit: BoxFit.cover))
                      : Image.network(
                          currentUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, error, stack) => Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: Colors.orangeAccent,
                                size: 20,
                              ),
                              SizedBox(height: 4),
                              Text(
                                "Erreur 400\n(Vérifier bucket)",
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  fontSize: 8,
                                  color: AppColors.textHint,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              )
            else
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.secondaryVariant
                      : AppColors.textHint,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isSelected ? Icons.check : icon,
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                  size: 20,
                ),
              ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (currentUrl != null && localPath == null)
                    Text(
                      "(Fichier actuel conservé)",
                      style: GoogleFonts.poppins(
                        color: AppColors.secondaryVariant,
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),
            Icon(Icons.edit_rounded, color: AppColors.textHint, size: 16),
          ],
        ),
      ),
    );
  }
}