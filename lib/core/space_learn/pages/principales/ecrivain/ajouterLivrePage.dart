import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/services/supabase_service.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/bookService.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/categorie_service.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/authServices.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/bookModel.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/categorie.dart';
import 'package:space_learn_flutter/core/utils/tokenStorage.dart';
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
  final _categorieController = TextEditingController();

  String? _selectedFileName;
  String? _selectedFilePath;
  String? _selectedCoverName;
  String? _selectedCoverPath;
  bool _isUploading = false;

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
      print('❌ Error loading current user: $e');
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
      print('❌ Error loading categories: $e');
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
      );

      if (result != null && mounted) {
        setState(() {
          _selectedFileName = result.files.single.name;
          _selectedFilePath = result.files.single.path;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Fichier sélectionné : $_selectedFileName")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur lors de la sélection du fichier : $e"),
          ),
        );
      }
    }
  }

  Future<void> _pickCover() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image != null && mounted) {
        setState(() {
          _selectedCoverName = image.name;
          _selectedCoverPath = image.path;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Image sélectionnée : $_selectedCoverName")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur lors de la sélection de l'image : $e"),
          ),
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

  Future<void> _publishBook() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedFileName == null || _selectedCoverName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Veuillez sélectionner le fichier et l'image de couverture.",
          ),
        ),
      );
      return;
    }

    if (_currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Erreur: Utilisateur non connecté."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final token = await TokenStorage.getToken();
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Erreur: Session expirée. Veuillez vous reconnecter."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      // 1. Upload Cover
      print('📤 Starting cover upload...');
      final coverExt = p.extension(_selectedCoverPath!);
      final coverPath = '${DateTime.now().millisecondsSinceEpoch}$coverExt';
      print('📁 Cover path: $coverPath');

      final coverUrl = await SupabaseService.uploadFile(
        bucket: 'covers',
        path: coverPath,
        file: File(_selectedCoverPath!),
      );

      print('🎯 Cover upload result: $coverUrl');
      if (coverUrl == null) {
        throw Exception("Erreur lors de l'upload de la couverture");
      }
      print('✅ Cover uploaded: $coverUrl');

      // 2. Upload Book
      print('📤 Starting book upload...');
      final bookExt = p.extension(_selectedFilePath!);
      final bookPath = '${DateTime.now().millisecondsSinceEpoch}$bookExt';
      print('📁 Book path: $bookPath');

      final bookUrl = await SupabaseService.uploadFile(
        bucket: 'books',
        path: bookPath,
        file: File(_selectedFilePath!),
      );

      print('🎯 Book upload result: $bookUrl');
      if (bookUrl == null) {
        throw Exception("Erreur lors de l'upload du livre");
      }
      print('✅ Book uploaded: $bookUrl');

      // 3. Determine category ID - CategorieID is required by the API
      String categorieId;
      if (_showCustomCategorie && _categorieController.text.isNotEmpty) {
        // Create a new category if custom
        try {
          final newCategorie = await _categorieService.createCategorie({
            'nom': _categorieController.text,
            'statut': 'actif',
          }, token);
          categorieId = newCategorie.id;
          print('✅ New category created: ${newCategorie.nom}');
        } catch (e) {
          print('⚠️ Could not create custom category: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  "Erreur: Impossible de créer la catégorie personnalisée. Veuillez sélectionner une catégorie existante.",
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
          setState(() => _isUploading = false);
          return;
        }
      } else if (_selectedCategorieId != null &&
          _selectedCategorieId != _autreCategorieId) {
        categorieId = _selectedCategorieId!;
        print('✅ Using selected category ID: $categorieId');
      } else {
        // Try to get the first available category as fallback
        try {
          final categories = await _categorieService.getCategories();
          if (categories.isNotEmpty) {
            categorieId = categories.first.id;
            print('🔄 Using first available category: ${categories.first.nom}');
          } else {
            // Create a default category
            final defaultCategorie = await _categorieService.createCategorie({
              'nom': 'Général',
              'statut': 'actif',
            }, token);
            categorieId = defaultCategorie.id;
            print('✅ Default category created: Général');
          }
        } catch (e) {
          print('❌ Could not get or create category: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  "Erreur: Impossible de déterminer une catégorie. Veuillez réessayer.",
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
          setState(() => _isUploading = false);
          return;
        }
      }

      // 4. Create book in database via API
      print('📤 Creating book in database...');
      print('📋 Final category ID being used: $categorieId');
      final book = BookModel(
        id: '', // Will be generated by the server
        auteurId: _currentUserId!,
        titre: _titreController.text.trim(),
        description: _descriptionController.text.trim(),
        imageCouverture: coverUrl,
        fichierUrl: bookUrl,
        format: _getFileFormat(_selectedFilePath),
        prix: int.tryParse(_prixController.text) ?? 0,
        stock: 999, // Default stock
        categorieId: categorieId,
        statut: 'publie',
      );

      print('📦 Book object created with category ID: ${book.categorieId}');

      final createdBook = await _bookService.createBook(book, token);
      print('✅ Book created successfully: ${createdBook.id}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Livre publié avec succès !"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      print('❌ Upload error: $e');
      if (mounted) {
        String errorMessage = "Échec de la publication : $e";
        if (e.toString().contains('Failed host lookup') ||
            e.toString().contains('No address associated with hostname')) {
          errorMessage =
              "Erreur de connexion à Supabase. Vérifiez que votre projet Supabase est actif dans le tableau de bord.";
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
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

                // Champ de catégorie avec dropdown
                _buildCategorieField(),

                const SizedBox(height: 16),
                _buildTextField(
                  controller: _prixController,
                  label: "Prix",
                  icon: Icons.euro,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 20),

                // File Upload Area
                Text(
                  "Fichier (PDF/EPUB)",
                  style: GoogleFonts.poppins(
                    color: Colors.grey[700],
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                _buildUploadCard(
                  title: "Fichier(PDF/EPUB)",
                  subtitle: _selectedFileName ?? "Sélectionner un fichier",
                  icon: Icons.upload_file,
                  isSelected: _selectedFileName != null,
                  onTap: _pickFile,
                ),

                const SizedBox(height: 16),

                // Cover Upload Area
                Text(
                  "Image de couverture",
                  style: GoogleFonts.poppins(
                    color: Colors.grey[700],
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                _buildUploadCard(
                  title: "Image de couverture",
                  subtitle: _selectedCoverName ?? "Sélectionner une image",
                  icon: Icons.image,
                  isSelected: _selectedCoverName != null,
                  onTap: _pickCover,
                ),

                const SizedBox(height: 40),

                ElevatedButton(
                  onPressed: _isUploading ? null : _publishBook,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                    shadowColor: AppColors.primary.withValues(alpha: 0.4),
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

  Widget _buildCategorieField() {
    if (_isLoadingCategories) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            const Icon(Icons.category, color: AppColors.primary),
            const SizedBox(width: 16),
            Text(
              "Chargement des catégories...",
              style: GoogleFonts.poppins(color: Colors.grey[600]),
            ),
            const Spacer(),
            const SizedBox(
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
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                _categoriesError!,
                style: GoogleFonts.poppins(color: Colors.red[700]),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.red),
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: DropdownButtonFormField<String>(
            value: _selectedCategorieId,
            decoration: InputDecoration(
              labelText: "Catégorie",
              labelStyle: GoogleFonts.poppins(color: Colors.grey[600]),
              prefixIcon: const Icon(Icons.category, color: AppColors.primary),
              filled: true,
              fillColor: Colors.white,
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
                borderSide: const BorderSide(color: AppColors.primary),
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
                    style: GoogleFonts.poppins(color: Colors.black87),
                  ),
                );
              }),
              // Add "Autre" option for custom category
              DropdownMenuItem<String>(
                value: _autreCategorieId,
                child: Text(
                  'Autre (personnalisée)',
                  style: GoogleFonts.poppins(
                    color: Colors.black87,
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
          const SizedBox(height: 16),
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
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.1)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey[200]!,
            width: 1.5,
          ),
          boxShadow: [
            if (!isSelected)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
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
              child: Text(
                subtitle,
                style: GoogleFonts.poppins(
                  color: isSelected ? AppColors.primary : Colors.grey[500],
                  fontSize: 15,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
