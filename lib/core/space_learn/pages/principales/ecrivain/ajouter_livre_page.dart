import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/themes/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:space_learn_flutter/core/themes/app_dimensions.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

import 'package:space_learn_flutter/core/space_learn/data/dataServices/bookService.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/publication_settings_service.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/uploadService.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/categorie_service.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/authServices.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/book_model.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/categorie.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/ecrivain/accueil_auteur_page.dart';
import 'package:space_learn_flutter/core/utils/token_storage.dart';
import 'package:space_learn_flutter/core/utils/app_notifications.dart';
import 'dart:io';
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
  final _argumentaireController = TextEditingController();
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

  /// Un manuscrit est déjà déposé côté serveur, et sera conservé tant que
  /// l'auteur n'en choisit pas un autre.
  bool _manuscritDejaEnPlace = false;

  // Le formulaire est decoupe en deux temps : decrire l'œuvre, puis rediger
  // l'argumentaire de recommandation. L'auteur ne voit ainsi qu'une intention
  // a la fois, et l'argumentaire arrive une fois le livre deja renseigne.
  static const List<String> _titresEtapes = ["L'œuvre", "La recommandation"];
  int _etape = 0;
  final ScrollController _scrollController = ScrollController();

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

  /// Part de l'auteur et fourchette conseillée, lues au serveur.
  ParametresPublication? _parametres;

  @override
  void initState() {
    super.initState();
    if (widget.book != null) {
      _titreController.text = widget.book!.titre;
      _descriptionController.text = widget.book!.description;
      _argumentaireController.text = widget.book!.argumentairePartage;
      _prixController.text = widget.book!.prix.toString();
      _isFree = widget.book!.prix == 0;
      _selectedCategorieId = widget.book!.categorieId;
      // Le nom se déduisait de fichierUrl. Le serveur masque cette URL pour
      // tout le monde, l'auteur compris : le formulaire concluait qu'aucun
      // manuscrit n'était en place et proposait d'en choisir un, sur un livre
      // qui en avait déjà un. Le drapeau a_un_fichier répond à la seule
      // question utile.
      _manuscritDejaEnPlace = widget.book!.aUnFichier;
      _selectedCoverName = widget.book!.imageCouverture?.split('/').last;
    }
    _loadCategories();
    _loadCurrentUser();
    _chargerParametresPublication();
  }

  /// Ce que le prix saisi rapporte, dit en francs.
  ///
  /// L'auteur ne voyait qu'un pourcentage, dans un autre écran. « 80 % » ne se
  /// convertit pas de tête au moment où l'on hésite entre deux prix ; « vous
  /// percevez 2 400 FCFA par vente », si.
  ///
  /// La fourchette conseillée vient du serveur. Elle ne bloque rien — l'auteur
  /// reste maître de son prix — mais elle situe. Le catalogue portait des
  /// livres à 89 876 FCFA, soit plus qu'un mois de SMIG ivoirien : personne
  /// n'avait jamais eu de repère.
  Widget _conseilDePrix() {
    if (_isFree || _parametres == null) return const SizedBox.shrink();

    final prix = double.tryParse(_prixController.text.trim()) ?? 0;
    if (prix <= 0) return const SizedBox.shrink();

    final p = _parametres!;
    final gain = p.gainPour(prix);
    final dansLaFourchette = p.dansLaFourchette(prix);

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                size: 15,
                color: AppColors.accentInk,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  "Vous percevez ${_enFrancs(gain)} FCFA par vente "
                  "(${p.partAuteurPourcent.toStringAsFixed(0)} %)",
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accentInk,
                  ),
                ),
              ),
            ],
          ),
          if (!dansLaFourchette) ...[
            const SizedBox(height: 6),
            Text(
              prix > p.prixConseilleMax
                  ? "Au-dessus de la fourchette conseillée "
                        "(${_enFrancs(p.prixConseilleMin)} à "
                        "${_enFrancs(p.prixConseilleMax)} FCFA). Un prix élevé "
                        "se vend rarement sur ce marché."
                  : "En dessous de la fourchette conseillée "
                        "(${_enFrancs(p.prixConseilleMin)} à "
                        "${_enFrancs(p.prixConseilleMax)} FCFA).",
              style: GoogleFonts.poppins(
                fontSize: 11.5,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Un montant avec ses milliers séparés : 89876 se lit mal, 89 876 se lit.
  static String _enFrancs(double montant) {
    final entier = montant.round().toString();
    final tampon = StringBuffer();
    for (var i = 0; i < entier.length; i++) {
      if (i > 0 && (entier.length - i) % 3 == 0) tampon.write(' ');
      tampon.write(entier[i]);
    }
    return tampon.toString();
  }

  Future<void> _chargerParametresPublication() async {
    try {
      final token = await TokenStorage.getToken();
      if (token == null || token.isEmpty) return;
      final p = await PublicationSettingsService().lire(token);
      if (mounted) setState(() => _parametres = p);
    } catch (e) {
      // Sans ces réglages le formulaire fonctionne : il n'affiche simplement
      // pas le gain. Bloquer la publication pour un conseil serait absurde.
      debugPrint("Conseil de prix indisponible : $e");
    }
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
      debugPrint("Erreur lors du chargement de l'utilisateur courant : $e");
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
    _argumentaireController.dispose();
    _prixController.dispose();
    _categorieController.dispose();
    _scrollController.dispose();
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
    // Publier depuis l'etape 2 doit quand meme controler l'etape 1 : ses
    // champs restent montes, mais l'auteur ne les voit plus. En cas d'erreur on
    // le ramene la ou se trouve le probleme.
    if (!_verifierEtapeOeuvre()) {
      if (_etape != 0) setState(() => _etape = 0);
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
      // Le format se deduit du fichier choisi, ou de celui deja en place.

      // Les fichiers ne sont plus envoyes directement a Supabase : ils
      // transitent par le backend, seul detenteur de la cle de service, qui
      // verifie que l'appelant est bien l'auteur du livre. L'envoi ne peut donc
      // avoir lieu qu'une fois le livre cree — d'ou l'ordre : enregistrer
      // d'abord, televerser ensuite, publier en dernier.
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

      final int prixParsed = _isFree
          ? 0
          : (int.tryParse(_prixController.text) ?? 0);
      final format = _getFileFormat(
        _selectedFilePath ?? widget.book?.fichierUrl,
      );

      // Le serveur remplace l'intégralité des champs à chaque mise à jour :
      // un envoi partiel effacerait ceux qu'on omet. On compose donc toujours
      // la charge complète, en y injectant les fichiers téléversés.
      Map<String, dynamic> champs(String statut, {String? cover}) {
        final data = <String, dynamic>{
          'titre': _titreController.text.trim(),
          'description': _descriptionController.text.trim(),
          'argumentaire_partage': _argumentaireController.text.trim(),
          'prix': prixParsed,
          'categorie_id': categorieId,
          'format': format,
          'statut': statut,
          'stock': widget.book?.stock ?? 999,
        };
        final c = cover ?? widget.book?.imageCouverture;
        if (c != null && c.isNotEmpty) data['image_couverture'] = c;
        // Aucune adresse de fichier ici.
        //
        // Le serveur ne les accepte plus en entrée : c'est le téléversement,
        // et lui seul, qui les écrit — après avoir vérifié que le manuscrit
        // n'est pas déjà vendu sous un autre titre. Les envoyer quand même
        // laissait croire que le client décidait de l'emplacement des
        // fichiers, alors qu'il ne fait que répéter ce que le serveur lui a
        // dit.
        return data;
      }

      final bool fichiersAEnvoyer =
          _selectedFilePath != null ||
          _selectedFileBytes != null ||
          _selectedCoverPath != null ||
          _selectedCoverBytes != null;

      // Tant que les fichiers ne sont pas en place, le livre reste brouillon :
      // un livre publié sans manuscrit apparaîtrait au catalogue et serait
      // achetable pour rien.
      final statutInitial = (isDraft || fichiersAEnvoyer)
          ? 'brouillon'
          : 'publie';

      String livreId;
      if (widget.book != null) {
        if (widget.book!.id.isEmpty) {
          throw Exception(
            "Erreur : Impossible de modifier un livre sans identifiant valide.",
          );
        }
        livreId = widget.book!.id;
        await _bookService.updateBook(livreId, champs(statutInitial), token);
      } else {
        final cree = await _bookService.createBook(
          BookModel(
            id: '',
            auteurId: _currentUserId!,
            titre: _titreController.text.trim(),
            description: _descriptionController.text.trim(),
            argumentairePartage: _argumentaireController.text.trim(),
            format: format,
            prix: prixParsed,
            stock: 999,
            categorieId: categorieId,
            statut: statutInitial,
            auteur: null,
          ),
          token,
        );
        livreId = cree.id;
      }

      String? uploadedCoverPath;

      // Téléversement des fichiers si modifiés/fournis
      if (_selectedCoverPath != null || _selectedCoverBytes != null) {
        uploadedCoverPath = await UploadService.envoyer(
          authToken: token,
          livreId: livreId,
          type: TypeFichier.couverture,
          cheminFichier: _selectedCoverPath,
          octets: _selectedCoverBytes,
          nomFichier: _selectedCoverName,
        );
      }

      if (_selectedFilePath != null || _selectedFileBytes != null) {
        await UploadService.envoyer(
          authToken: token,
          livreId: livreId,
          type: TypeFichier.manuscrit,
          cheminFichier: _selectedFilePath,
          octets: _selectedFileBytes,
          nomFichier: _selectedFileName,
        );

        // L'extrait est fabriqué par le serveur, dans la foulée de ce
        // téléversement. L'application en produisait un second et l'écrasait
        // par-dessus : le même PDF était analysé deux fois, deux fichiers
        // occupaient le stockage, et la taille de l'aperçu dépendait de la
        // version de l'application installée sur le téléphone de l'auteur.
      }

      // Mise à jour / publication effective avec les chemins de fichiers définitifs
      await _bookService.updateBook(
        livreId,
        champs(isDraft ? 'brouillon' : 'publie', cover: uploadedCoverPath),
        token,
      );

      if (mounted) {
        _showSuccessDialog(
          isModification: widget.book != null,
          isDraft: isDraft,
        );
      }
    } catch (e) {
      if (mounted) {
        AppNotifications.showSnackBar(
          context,
          message: _lisible(e),
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  /// Le message d'une erreur, débarrassé de sa tuyauterie.
  ///
  /// `"$e"` sur une Exception rend « Exception: ... » : l'auteur lisait donc
  /// « Échec de l'opération : Exception: ce manuscrit est trop court ». Le
  /// serveur écrit maintenant des phrases utilisables — trop court, déjà
  /// publié sous un autre titre — et elles doivent arriver telles quelles.
  static String _lisible(Object erreur) {
    var texte = erreur.toString();
    for (final prefixe in ['Exception: ', 'HttpException: ', 'FormatException: ']) {
      if (texte.startsWith(prefixe)) {
        texte = texte.substring(prefixe.length);
        break;
      }
    }
    texte = texte.trim();
    if (texte.isEmpty) return "L'opération a échoué. Réessayez.";
    return texte[0].toUpperCase() + texte.substring(1);
  }

  void _showSuccessDialog({
    required bool isModification,
    required bool isDraft,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_outline,
                  color: AppColors.success,
                  size: 64,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                "Félicitations !",
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isModification
                    ? (isDraft
                          ? "Brouillon mis à jour avec succès."
                          : "Votre œuvre a été modifiée avec succès.")
                    : (isDraft
                          ? "L'œuvre a été enregistrée en tant que brouillon."
                          : "Votre œuvre a été publiée avec succès. Elle est maintenant disponible pour vos lecteurs."),
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
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusInner,
                      ),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    "Continuer",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: AppColors.onAccent,
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
    AppColors.suivreLeTheme(context);
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
        child: Column(
          children: [
            _indicateurEtapes(),
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Les deux etapes restent montees en permanence :
                      // Offstage masque sans demonter. La validation du Form
                      // couvre ainsi tous les champs, quelle que soit l'etape
                      // affichee, et rien n'est reconstruit en changeant de vue.
                      Offstage(
                        offstage: _etape != 0,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: _etapeOeuvre(),
                        ),
                      ),
                      Offstage(
                        offstage: _etape != 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: _etapeRecommandation(),
                        ),
                      ),
                      const SizedBox(height: 32),
                      _barreActions(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────── Etape 1 : l'œuvre ───────────────────────────

  List<Widget> _etapeOeuvre() {
    return [
      _enteteSection(
        "Votre œuvre",
        "Les informations qui apparaîtront sur la fiche du livre.",
      ),
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
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 16),
      _buildCategorieField(),
      const SizedBox(height: 24),

      _sousTitre("Prix"),
      const SizedBox(height: 12),
      _buildTextField(
        controller: _prixController,
        label: "Prix (FCFA)",
        icon: Icons.money,
        keyboardType: TextInputType.number,
        enabled: !_isFree,
        onChanged: (_) => setState(() {}),
      ),
      _conseilDePrix(),
      const SizedBox(height: 8),
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
      const SizedBox(height: 24),

      _sousTitre("Fichiers"),
      const SizedBox(height: 12),
      _buildUploadCard(
        title: "Fichier (PDF/EPUB)",
        subtitle:
            _selectedFileName ??
            (_manuscritDejaEnPlace
                ? "Manuscrit déjà en place — appuyez pour le remplacer"
                : "Sélectionner un fichier"),
        icon: Icons.upload_file,
        isSelected: _selectedFileName != null || _manuscritDejaEnPlace,
        onTap: _pickFile,
        currentUrl: _selectedFilePath == null ? widget.book?.fichierUrl : null,
      ),
      const SizedBox(height: 12),
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
    ];
  }

  // ───────────────────── Etape 2 : la recommandation ──────────────────────

  List<Widget> _etapeRecommandation() {
    return [
      _enteteSection(
        "Votre argumentaire",
        "Ce texte circulera à votre place quand un lecteur recommandera "
            "l'ouvrage. Adressez-vous directement à lui, comme dans une "
            "conversation.",
      ),
      _buildTextField(
        controller: _argumentaireController,
        label: "Argumentaire de recommandation (facultatif)",
        icon: Icons.campaign_outlined,
        maxLines: 6,
        obligatoire: false,
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 16),
      _apercuPartage(),
    ];
  }

  // ──────────────────────────── Navigation ────────────────────────────────

  Widget _indicateurEtapes() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
      child: Row(
        children: List.generate(_titresEtapes.length, (i) {
          final atteinte = i <= _etape;
          return Expanded(
            child: GestureDetector(
              // Revenir en arriere par l'indicateur est naturel ; avancer par
              // ce biais passe par la meme validation que le bouton.
              onTap: _isUploading ? null : () => _allerAEtape(i),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: EdgeInsets.only(
                  right: i == _titresEtapes.length - 1 ? 0 : 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      height: 4,
                      decoration: BoxDecoration(
                        color: atteinte
                            ? AppColors.secondaryVariant
                            : AppColors.textSecondary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusXs,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Étape ${i + 1}",
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: atteinte
                            ? AppColors.secondaryVariant
                            : AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      _titresEtapes[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: atteinte
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _barreActions() {
    if (_etape == 0) {
      return ElevatedButton(
        onPressed: _isUploading ? null : () => _allerAEtape(1),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.secondaryVariant,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          ),
          elevation: 4,
          shadowColor: AppColors.secondaryVariant.withValues(alpha: 0.4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Continuer",
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.onAccent,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_forward,
              size: 18,
              color: AppColors.onAccent,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isUploading
                    ? null
                    : () => _publishBook(isDraft: true),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusCard,
                    ),
                  ),
                  side: BorderSide(
                    color: _isUploading
                        ? Colors.grey
                        : AppColors.secondaryVariant,
                  ),
                ),
                child: Text(
                  "Brouillon",
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _isUploading
                        ? Colors.grey
                        : AppColors.secondaryVariant,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: _isUploading
                    ? null
                    : () => _publishBook(isDraft: false),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondaryVariant,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusCard,
                    ),
                  ),
                  elevation: 4,
                  shadowColor: AppColors.secondaryVariant.withValues(
                    alpha: 0.4,
                  ),
                ),
                child: _isUploading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: AppColors.onAccent,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Text(
                        widget.book != null ? "Modifier" : "Publier",
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.onAccent,
                        ),
                      ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _isUploading ? null : () => _allerAEtape(0),
          icon: const Icon(Icons.arrow_back, size: 16),
          label: Text(
            "Revenir à l'œuvre",
            style: GoogleFonts.poppins(fontSize: 13),
          ),
          style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
        ),
      ],
    );
  }

  /// Change d'etape. Avancer exige que l'etape courante soit complete ;
  /// reculer est toujours possible.
  void _allerAEtape(int cible) {
    if (cible == _etape) return;
    if (cible > _etape && !_verifierEtapeOeuvre()) return;
    setState(() => _etape = cible);
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  /// Controle complet de l'etape 1. Utilise aussi bien par « Continuer » que
  /// par la publication, pour qu'il n'existe qu'une seule definition de ce
  /// qu'est un livre valide.
  bool _verifierEtapeOeuvre() {
    if (!_formKey.currentState!.validate()) {
      // Sans ce message, un champ invalide hors de l'écran donne un bouton
      // qui ne réagit pas — l'utilisateur n'a aucun moyen de savoir pourquoi.
      AppNotifications.showSnackBar(
        context,
        message: 'Certains champs sont incomplets. Vérifiez le formulaire.',
        isError: true,
      );
      return false;
    }

    if (widget.book == null &&
        (_selectedFileName == null || _selectedCoverName == null)) {
      AppNotifications.showSnackBar(
        context,
        message: "Veuillez sélectionner le fichier et l'image de couverture.",
        isError: true,
      );
      return false;
    }
    return true;
  }

  Widget _enteteSection(String titre, String sousTitre) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titre,
            style: GoogleFonts.poppins(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            sousTitre,
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sousTitre(String texte) {
    return Text(
      texte.toUpperCase(),
      style: GoogleFonts.poppins(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: AppColors.textSecondary,
      ),
    );
  }

  Widget _buildCategorieField() {
    if (_isLoadingCategories) {
      return Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        ),
        child: Row(
          children: [
            Icon(Icons.category, color: AppColors.secondaryVariant),
            SizedBox(width: 16),
            // Sans Expanded, ce libellé impose sa largeur naturelle au Row et
            // déborde dès que la place manque — écran étroit, corps de texte
            // agrandi par les réglages système, ou traduction plus longue.
            Expanded(
              child: Text(
                "Chargement des catégories...",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(color: AppColors.textHint),
              ),
            ),
            const SizedBox(width: 8),
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
          color: AppColors.error,
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          border: Border.all(color: AppColors.error),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: AppColors.error),
            SizedBox(width: 16),
            Expanded(
              child: Text(
                _categoriesError!,
                style: GoogleFonts.poppins(color: AppColors.error),
              ),
            ),
            IconButton(
              icon: Icon(Icons.refresh, color: AppColors.error),
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
            borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          ),
          child: DropdownButtonFormField<String>(
            dropdownColor: AppColors.cardBackground,
            iconEnabledColor: AppColors.secondaryVariant,
            style: GoogleFonts.poppins(
              color: AppColors.textPrimary,
              fontSize: 14,
            ),
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
                borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
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

  /// Aperçu du message que recevront les lecteurs.
  ///
  /// L'auteur doit voir ce qu'il écrit tel qu'il circulera : un argumentaire
  /// rédigé à l'aveugle est rarement le bon. Le rendu final est composé par le
  /// serveur, qui y ajoute le prix et le lien.
  Widget _apercuPartage() {
    final argumentaire = _argumentaireController.text.trim();
    final corps = argumentaire.isNotEmpty
        ? argumentaire
        : _descriptionController.text.trim();

    if (corps.isEmpty) {
      return Text(
        "Ce texte accompagnera votre livre quand un lecteur le recommandera. "
        "À défaut, votre description sera utilisée.",
        style: AppTextStyles.greyMedium12,
      );
    }

    final titre = _titreController.text.trim().toUpperCase();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppDimensions.radiusInner),
        border: Border.all(color: AppColors.accentInk.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.visibility_outlined,
                size: 15,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text("Aperçu du partage", style: AppTextStyles.greyMedium12),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            [
              '📘 ${titre.isEmpty ? 'TITRE DU LIVRE' : titre}',
              '',
              corps,
              '',
              "👉🏽 Clique ici pour l'obtenir : …",
            ].join('\n'),
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              height: 1.5,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
    bool enabled = true,
    ValueChanged<String>? onChanged,
    // Tous les champs portaient le même validateur « Ce champ est requis »,
    // y compris l'argumentaire, pourtant annoncé facultatif. Comme les deux
    // étapes restent montées, valider le formulaire échouait sur ce champ vide
    // — et son message s'affichait sur une étape masquée. « Continuer » ne
    // faisait donc rien, sans rien dire.
    bool obligatoire = true,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      maxLines: maxLines,
      keyboardType: keyboardType,
      onChanged: onChanged,
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
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          borderSide: BorderSide(color: AppColors.secondaryVariant),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
      ),
      validator: obligatoire
          ? (value) {
              if (value == null || value.isEmpty) {
                return 'Ce champ est requis';
              }
              return null;
            }
          : null,
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
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          border: Border.all(
            color: isSelected
                ? AppColors.secondaryVariant.withValues(alpha: 0.5)
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            // Preview / Icon
            if (isImage && (localPath != null || currentUrl != null))
              ClipRRect(
                borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
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
                                color: AppColors.warning,
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
                  color: isSelected
                      ? AppColors.onAccent
                      : AppColors.textPrimary,
                  size: 20,
                ),
              ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      color: AppColors.textPrimary,
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
