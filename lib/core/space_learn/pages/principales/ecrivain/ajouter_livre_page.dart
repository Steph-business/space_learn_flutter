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
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:space_learn_flutter/core/utils/message_erreur.dart';

class AjouterLivrePage extends StatefulWidget {
  final BookModel? book;
  const AjouterLivrePage({super.key, this.book});

  /// Efface les brouillons de publication en attente, tous comptes confondus.
  ///
  /// L'écran retient sur l'appareil le livre créé par une publication qui a
  /// échoué, sous « `publication_brouillon_<compte>` », pour le reprendre au
  /// lieu d'en créer un second (voir `_brouillonEnAttenteId`). Cette trace
  /// appartient au compte qui l'a laissée : elle DOIT partir avec lui.
  ///
  /// À appeler depuis SessionService.terminer, le point de nettoyage unique.
  /// Le balayage se fait par préfixe, comme BadgeService.purgerCache : il ne
  /// dépend donc pas de l'identifiant du compte, que `TokenStorage.clearToken`
  /// efface au premier pas de ce nettoyage.
  static Future<void> purgerBrouillonsEnAttente() async {
    final prefs = await SharedPreferences.getInstance();
    final cles = prefs
        .getKeys()
        .where((c) => c.startsWith(_AjouterLivrePageState._clePrefixeBrouillon))
        .toList();
    for (final cle in cles) {
      await prefs.remove(cle);
    }
  }

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

  /// L'identifiant du livre créé par un essai PRÉCÉDENT de publication.
  ///
  /// Pour un livre neuf, la fiche est créée d'abord et les fichiers partent
  /// ensuite. Quand le téléversement échouait, cet identifiant était perdu :
  /// au nouvel essai, `widget.book` était toujours nul et une SECONDE fiche
  /// naissait — le serveur autorisant l'auteur à redéposer son propre
  /// manuscrit, rien ne bloquait le doublon. Chaque échec laissait donc un
  /// brouillon fantôme de plus dans « Mes livres ». On retient le livre déjà
  /// créé pour le reprendre au lieu d'en créer un autre.
  ///
  /// Ce champ ne vaut que pour la session d'écran en cours : voir
  /// [_brouillonEnAttenteId] pour ce qui survit à la fermeture de la page.
  String? _livreCreeId;

  /// Le brouillon laissé par un essai précédent, retrouvé à l'ouverture.
  ///
  /// [_livreCreeId] est un champ d'état : il meurt avec l'écran. L'auteur dont
  /// la publication échouait, qui fermait la page — le bouton retour restait
  /// actif — puis rouvrait « Publier une œuvre », repartait donc avec un champ
  /// nul et créait un SECOND livre. Le brouillon fantôme du constat d'origine
  /// survivait ainsi à la reprise en session, et rien à l'écran ne disait
  /// qu'un brouillon attendait. La trace est maintenant écrite sur l'appareil,
  /// sous une clé suffixée par l'identifiant du compte.
  ///
  /// Elle n'est JAMAIS reprise d'office. Au rouvrir, le formulaire est vide :
  /// adopter l'identifiant en silence ferait écrire la nouvelle saisie
  /// par-dessus l'ancienne fiche — le titre d'un livre sur le manuscrit d'un
  /// autre, quand le téléversement avait réussi et que seule la publication
  /// avait échoué. C'est l'auteur qui décide, en voyant le titre en attente.
  String? _brouillonEnAttenteId;
  String? _brouillonEnAttenteTitre;

  /// Pourquoi l'identifiant du compte manque, dit avec les mots du problème.
  ///
  /// La publication répondait « Utilisateur non connecté » dès que
  /// [_currentUserId] était nul — y compris quand la session était parfaitement
  /// valide et que seul le réseau avait manqué au chargement de l'écran. Une
  /// panne se disait comme une déconnexion.
  String? _raisonCompteIndisponible;

  /// Le prix saisi avant que « gratuitement » ne soit coché.
  ///
  /// Cocher la case écrasait le champ par « 0 » ; décocher laissait ce « 0 »,
  /// que la validation refuse. L'auteur qui explorait l'option perdait son
  /// prix et devait le retrouver de mémoire.
  String? _prixAvantGratuit;

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
      // Le prix d'origine sert de repli si l'auteur coche puis décoche
      // « gratuitement » : sans lui, il ressortirait de l'aller-retour à 0.
      if (!_isFree) _prixAvantGratuit = _prixController.text;
    }
    _loadCategories();
    _loadCurrentUser();
    _chargerParametresPublication();
    // Uniquement sur une publication neuve : en modification, l'auteur a déjà
    // son livre sous les yeux, lui proposer d'en reprendre un autre n'aurait
    // aucun sens.
    if (widget.book == null) _relireBrouillonEnAttente();
  }

  // ───────────────── Le brouillon laissé par un essai raté ─────────────────

  /// Préfixe commun à tous les comptes de l'appareil.
  ///
  /// Le suffixe est l'identifiant du compte : sans lui, l'auteur suivant sur
  /// le même téléphone se verrait proposer de reprendre le brouillon du
  /// précédent — et le serveur, lui, refuserait la mise à jour d'un livre dont
  /// il n'est pas l'auteur, sur un écran incapable d'expliquer pourquoi.
  static const String _clePrefixeBrouillon = 'publication_brouillon_';

  /// La clé du compte connecté, ou `null` s'il n'y en a pas.
  ///
  /// Sans identifiant, on n'écrit RIEN : une clé commune serait exactement la
  /// fuite que le suffixe évite.
  static Future<String?> _cleBrouillonDuCompte() async {
    final compte = await TokenStorage.getUserId();
    if (compte == null || compte.isEmpty) return null;
    return '$_clePrefixeBrouillon$compte';
  }

  /// Retient le livre créé, pour le cas où la suite échouerait.
  Future<void> _memoriserBrouillon(String livreId, String titre) async {
    try {
      final cle = await _cleBrouillonDuCompte();
      if (cle == null) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        cle,
        jsonEncode({
          'id': livreId,
          'titre': titre,
          'quand': DateTime.now().toIso8601String(),
        }),
      );
    } catch (e) {
      // Mémoriser est un CONFORT : le publier ne doit jamais échouer parce que
      // le stockage local a refusé d'écrire.
      debugPrint('Brouillon en attente non mémorisé : $e');
    }
  }

  /// Oublie le brouillon retenu — à condition que ce soit bien celui-là.
  ///
  /// Le test sur l'identifiant compte : l'auteur peut très bien avoir publié
  /// un AUTRE livre entre-temps, et cette publication-là ne doit pas effacer
  /// la trace du brouillon qui attend toujours.
  Future<void> _oublierBrouillon(String livreId) async {
    try {
      final cle = await _cleBrouillonDuCompte();
      if (cle == null) return;
      final prefs = await SharedPreferences.getInstance();
      final brut = prefs.getString(cle);
      if (brut == null) return;
      final memo = jsonDecode(brut);
      if (memo is Map && memo['id'] == livreId) await prefs.remove(cle);
    } catch (e) {
      debugPrint('Brouillon en attente non effacé : $e');
    }
  }

  /// Relit la trace au démarrage de l'écran.
  Future<void> _relireBrouillonEnAttente() async {
    try {
      final cle = await _cleBrouillonDuCompte();
      if (cle == null) return;
      final prefs = await SharedPreferences.getInstance();
      final brut = prefs.getString(cle);
      if (brut == null) return;

      final memo = jsonDecode(brut);
      if (memo is! Map) return;
      final id = (memo['id'] as String?)?.trim() ?? '';
      if (id.isEmpty) return;

      // Une trace trop vieille ne rend plus service : le livre a pu être
      // publié depuis « Mes livres », ou supprimé. On l'écarte plutôt que de
      // proposer indéfiniment de reprendre un brouillon dont l'auteur ne se
      // souvient plus.
      final quand = DateTime.tryParse((memo['quand'] as String?) ?? '');
      if (quand != null && DateTime.now().difference(quand).inDays > 30) {
        await prefs.remove(cle);
        return;
      }

      if (!mounted) return;
      setState(() {
        _brouillonEnAttenteId = id;
        _brouillonEnAttenteTitre = (memo['titre'] as String?)?.trim();
      });
    } catch (e) {
      debugPrint('Brouillon en attente illisible : $e');
    }
  }

  /// Efface la trace ET, si elle était adoptée, la reprise en cours.
  Future<void> _abandonnerLeBrouillonEnAttente() async {
    final id = _brouillonEnAttenteId;
    setState(() {
      if (_livreCreeId == _brouillonEnAttenteId) _livreCreeId = null;
      _brouillonEnAttenteId = null;
      _brouillonEnAttenteTitre = null;
    });
    if (id != null) await _oublierBrouillon(id);
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

    // Sous le plancher, il n'y a rien à conseiller : le serveur refusera. On
    // le dit tout de suite, et on s'arrête là — afficher « vous percevez
    // 160 FCFA par vente » sous un prix qui ne passera pas serait un mensonge.
    if (p.sousLePlancher(prix)) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, size: 15, color: AppColors.error),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                "Prix trop bas : ${_enFrancs(p.prixMinimum)} FCFA au minimum. "
                "En dessous, la commission et les frais de l'opérateur ne "
                "laissent presque rien pour vous.",
                style: GoogleFonts.poppins(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.error,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 15,
            color: AppColors.accentInk,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              "Vous percevez ${_enFrancs(gain)} FCFA par vente",
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.accentInk,
              ),
            ),
          ),
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

  /// L'identifiant du compte, porté par la fiche du livre créé.
  ///
  /// Cet appel échouait en silence : `_currentUserId` restait nul et la
  /// publication répondait « Utilisateur non connecté » — une contre-vérité
  /// quand la session était valide et que seul le réseau avait manqué à
  /// l'ouverture de l'écran. Deux réponses à cela.
  ///
  /// 1. Un REPLI sur l'identifiant déjà rangé à la connexion : le serveur
  ///    prend de toute façon l'auteur dans le jeton et ignore `auteur_id` du
  ///    corps de la requête (livre/controller.go, CreateLivre). Une coupure
  ///    passagère n'a donc aucune raison d'interdire la publication.
  /// 2. La RAISON exacte gardée de côté, pour être dite telle quelle si même
  ///    le repli est vide.
  Future<void> _loadCurrentUser() async {
    String? raison;
    try {
      final token = await TokenStorage.getToken();
      if (token == null || token.isEmpty) {
        raison = "Votre session a expiré. Reconnectez-vous pour publier.";
      } else {
        final user = await _authService.getUser(token);
        if (user != null && user.id.isNotEmpty) {
          if (!mounted) return;
          setState(() {
            _currentUserId = user.id;
            _raisonCompteIndisponible = null;
          });
          return;
        }
        raison = "Votre compte n'a pas pu être vérifié. Réessayez.";
      }
    } catch (e) {
      debugPrint("Erreur lors du chargement de l'utilisateur courant : $e");
      raison = messageLisible(
        e,
        repli:
            "Votre compte n'a pas pu être vérifié. Vérifiez votre connexion, "
            "puis réessayez.",
      );
    }

    final replie = await TokenStorage.getUserId();
    if (!mounted) return;
    setState(() {
      _currentUserId = (replie != null && replie.isNotEmpty) ? replie : null;
      _raisonCompteIndisponible = _currentUserId == null ? raison : null;
    });
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
          // Le message du serveur — ou celui de la coupure — plutôt qu'une
          // phrase passe-partout : « Erreur lors du chargement » ne disait pas
          // s'il fallait réessayer, se reconnecter ou attendre.
          _categoriesError = messageLisible(
            e,
            repli:
                "Les catégories n'ont pas pu être chargées. Vérifiez votre "
                "connexion, puis réessayez.",
          );
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
          message: messageLisible(
            e,
            repli: "Ce fichier n'a pas pu être ouvert.",
          ),
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
        // La lecture des octets est un SECOND await : sur le web, une image de
        // plusieurs mégaoctets s'y attarde, et l'auteur a le temps de quitter
        // l'écran. Le `mounted` d'au-dessus ne dit plus rien à ce point.
        if (!mounted) return;
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
          message: messageLisible(
            e,
            repli: "Cette image n'a pas pu être ouverte.",
          ),
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

  /// Le format à enregistrer : celui du fichier CHOISI, sinon celui du livre.
  ///
  /// Il se déduisait de `widget.book.fichierUrl`, que le serveur masque pour
  /// tout le monde — l'auteur compris. L'URL arrivant nulle, `_getFileFormat`
  /// rendait « PDF », et la mise à jour l'écrivait en base : corriger la
  /// description d'un EPUB suffisait à le déclarer PDF, pour la fiche comme
  /// pour tous les consommateurs du champ. Le format déjà enregistré,
  /// disponible dans `widget.book.format`, n'était jamais utilisé.
  ///
  /// Le NOM du fichier sert de repli au chemin : sur le web, `pickFiles` ne
  /// rend pas de chemin local et un EPUB fraîchement choisi passait lui aussi
  /// pour un PDF.
  String _formatDuLivre() {
    final choisi = _selectedFilePath ?? _selectedFileName;
    if (choisi != null && choisi.isNotEmpty) return _getFileFormat(choisi);

    final existant = widget.book?.format.trim() ?? '';
    if (existant.isNotEmpty) return existant.toUpperCase();

    return 'PDF';
  }

  /// Le prix saisi, en francs entiers — ou `null` si ce n'en est pas un.
  ///
  /// La publication faisait `int.tryParse(...) ?? 0` : « 2500.5 », « 2 500 »
  /// collé ou un texte quelconque rendaient `null`, donc 0 — et le serveur
  /// accepte 0 comme livre GRATUIT. L'œuvre partait offerte pendant que
  /// l'écran annonçait « publiée avec succès ». Le contrôle est volontairement
  /// strict : `int.tryParse` tolère « +2500 » et les espaces de bordure, ce
  /// qui masquait le reste.
  int? _prixEnFrancs() {
    if (_isFree) return 0;
    final saisie = _prixController.text.trim();
    if (!RegExp(r'^\d+$').hasMatch(saisie)) return null;
    return int.tryParse(saisie);
  }

  Future<void> _publishBook({bool isDraft = false}) async {
    // Garde de reentrance. Les boutons sont bien desactives par _isUploading,
    // mais le drapeau n'etait leve qu'APRES un await (la lecture du jeton dans
    // le stockage securise, ~100 ms) : pendant cette fenetre, chaque tapotement
    // supplementaire relancait _publishBook et passait toutes les gardes —
    // deux tapotements rapides creaient deux livres, trois en creaient trois.
    if (_isUploading) return;

    // Publier depuis l'etape 2 doit quand meme controler l'etape 1 : ses
    // champs restent montes, mais l'auteur ne les voit plus. En cas d'erreur on
    // le ramene la ou se trouve le probleme.
    if (!_verifierEtapeOeuvre()) {
      if (_etape != 0) setState(() => _etape = 0);
      return;
    }

    if (_currentUserId == null) {
      // On dit CE QUI s'est passé — session expirée, réseau absent — au lieu
      // d'annoncer une déconnexion que rien ne prouve, et on relance la
      // vérification pour que le prochain appui ait une chance d'aboutir.
      // Cet appel n'est pas attendu : un await ici rouvrirait la fenêtre de
      // course que la garde de réentrance vient de fermer.
      AppNotifications.showSnackBar(
        context,
        message:
            _raisonCompteIndisponible ??
            "Votre compte n'a pas encore été vérifié. Patientez un instant, "
                "puis réessayez.",
        isError: true,
      );
      _loadCurrentUser();
      return;
    }

    // Le drapeau se leve AVANT le premier await : c'est lui qui ferme la
    // fenetre de course decrite en tete de fonction. Les validations synchrones
    // ci-dessus peuvent rester avant — aucun await ne les separe de l'entree.
    setState(() => _isUploading = true);

    final token = await TokenStorage.getToken();
    if (!mounted) return;
    if (token == null) {
      // Sortie anticipee apres la levee du drapeau : on le repose, sinon les
      // boutons resteraient gris a vie — le defaut inverse de la course.
      setState(() => _isUploading = false);
      AppNotifications.showSnackBar(
        context,
        message: "Erreur: Session expirée. Veuillez vous reconnecter.",
        isError: true,
      );
      return;
    }

    try {
      // Le format se deduit du fichier choisi, ou de celui deja en place.

      // Les fichiers ne sont plus envoyes directement a Supabase : ils
      // transitent par le backend, seul detenteur de la cle de service, qui
      // verifie que l'appelant est bien l'auteur du livre. L'envoi ne peut donc
      // avoir lieu qu'une fois le livre cree — d'ou l'ordre : creer la fiche
      // SI elle n'existe pas encore, televerser, puis publier en dernier. Un
      // livre deja en base saute la premiere etape : il n'a pas a repasser par
      // un statut « brouillon » pour recevoir un fichier.
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

      // Un prix illisible ne devient plus 0 : il ARRÊTE la publication.
      //
      // _verifierEtapeOeuvre a déjà refusé ce cas plus haut ; ce garde-fou
      // reste parce qu'une publication à 0 FCFA ne se rattrape pas — le livre
      // part gratuit, les lecteurs l'obtiennent sans payer, et l'auteur ne
      // l'apprend que par son relevé.
      final int? prixValide = _prixEnFrancs();
      if (prixValide == null) {
        throw Exception(
          "Le prix doit s'écrire en chiffres uniquement, sans espace ni "
          "virgule (exemple : 2500).",
        );
      }
      final int prixParsed = prixValide;
      final format = _formatDuLivre();

      // La charge complète des champs SAISIS : le formulaire est l'état que
      // l'auteur vient de valider, on l'envoie en entier.
      //
      // Le statut, lui, ne part QUE lorsqu'on veut le changer — d'où le
      // paramètre nullable. Le serveur applique la mise à jour champ par
      // champ, sur des pointeurs (livre/service.go, Update : « if in.Statut !=
      // nil { livre.Statut = *in.Statut } ») : une clé absente laisse la
      // valeur exactement où elle est. C'est la seule façon honnête de dire
      // « je corrige un résumé, je ne décide pas de la mise en vente », et
      // elle a un second mérite : elle ne rejoue pas `widget.book.statut`,
      // qui peut dater de la liste chargée dix minutes plus tôt.
      Map<String, dynamic> champs(String? statut) {
        return <String, dynamic>{
          'titre': _titreController.text.trim(),
          'description': _descriptionController.text.trim(),
          'argumentaire_partage': _argumentaireController.text.trim(),
          'prix': prixParsed,
          'categorie_id': categorieId,
          'format': format,
          if (statut != null) 'statut': statut,
          'stock': widget.book?.stock ?? 999,
        };
        // Aucune adresse de fichier ici, couverture comprise.
        //
        // Le serveur ne les accepte plus en entrée : c'est le téléversement,
        // et lui seul, qui les écrit — après avoir vérifié que le manuscrit
        // n'est pas déjà vendu sous un autre titre. Les envoyer quand même
        // laissait croire que le client décidait de l'emplacement des
        // fichiers, alors qu'il ne fait que répéter ce que le serveur lui a
        // dit.
        //
        // La couverture était restée en dehors de cette règle, et le prix en
        // était visible : le téléversement écrivait l'adresse publique
        // complète, puis cette mise à jour la remplaçait par le chemin brut
        // renvoyé dans la réponse. Un livre fraîchement publié se retrouvait
        // sans couverture, sans que rien ne le signale.
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

      if (widget.book != null && widget.book!.id.isEmpty) {
        throw Exception(
          "Erreur : Impossible de modifier un livre sans identifiant valide.",
        );
      }

      // On ne DÉPUBLIE plus avant de téléverser.
      //
      // En modification, la moindre nouvelle couverture déclenchait un premier
      // updateBook en « brouillon » : le serveur appliquait ce statut et
      // retirait aussitôt le livre du catalogue. Si le téléversement échouait
      // ensuite — réseau coupé, fichier trop lourd —, la mise à jour qui
      // devait republier n'arrivait jamais : le livre restait en vente nulle
      // part, sans qu'un seul mot à l'écran le dise. Un livre déjà en base n'a
      // besoin d'aucune mise à jour préalable pour recevoir un fichier : on
      // téléverse d'abord, et l'unique mise à jour, tout à la fin, porte les
      // champs ET le statut définitif. Un échec laisse donc le livre
      // exactement dans l'état où il était.
      final String? dejaEnBase = widget.book?.id ?? _livreCreeId;

      String livreId;
      if (dejaEnBase != null && dejaEnBase.isNotEmpty) {
        livreId = dejaEnBase;
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
        // Un identifiant vide ARRÊTE tout, ici et pas plus loin : les
        // téléversements partiraient vers une adresse sans livre et la mise à
        // jour finale porterait dans le vide, avec des erreurs qui ne diraient
        // rien de la cause.
        if (livreId.isEmpty) {
          throw Exception(
            "Le serveur n'a pas renvoyé l'identifiant du livre créé. "
            "Vérifiez dans « Mes livres » avant de réessayer.",
          );
        }
        // Retenu AVANT le premier téléversement : si la suite échoue, le
        // prochain essai reprendra CE livre au lieu d'en créer un second.
        _livreCreeId = livreId;
        // Et retenu sur l'appareil, pour que la reprise survive à la
        // fermeture de l'écran (voir _brouillonEnAttenteId).
        await _memoriserBrouillon(livreId, _titreController.text.trim());
      }

      // Téléversement des fichiers si modifiés/fournis.
      //
      // Le retour n'est plus conservé : c'est le serveur qui inscrit l'adresse
      // de la couverture, sous sa forme publique complète.
      if (_selectedCoverPath != null || _selectedCoverBytes != null) {
        await UploadService.envoyer(
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

      // Mise à jour / publication effective, une fois les fichiers en place.
      //
      // Le statut ne se déduit PLUS du seul bouton. « Modifier » envoyait
      // 'publie' à chaque enregistrement : un livre retiré de la vente depuis
      // la fiche (« Retirer de la vente » → 'brouillon') ou archivé depuis le
      // site ('en_revision') repartait au catalogue parce que son auteur avait
      // corrigé une coquille. Rien à l'écran ne le disait — et le serveur,
      // lui, faisait son travail : au passage vers « publié » il repose la
      // date de parution et prévient TOUS les abonnés « Nouveau livre publié »
      // (livre/service.go, Update → notifyFollowers). Une faute de frappe
      // annonçait donc une parution à toute l'audience de l'auteur.
      //
      // La règle, celle que le site tient déjà (auteur/publier/page.tsx) :
      //  - livre NEUF : le bouton décide, brouillon ou publié ;
      //  - livre DÉJÀ en base : « Modifier » ne touche pas au statut — on ne
      //    l'envoie pas du tout —, la mise en vente se demande là où elle se
      //    lit, par le menu « Publier » / « Remettre en vente » de la fiche,
      //    seule porte d'entrée de cet écran en modification ;
      //  - « Brouillon » reste explicite : il retire de la vente, et le
      //    dialogue de fin le dit.
      //
      // Le site ne protège que 'en_revision' parce qu'il n'a pas de retrait
      // vers 'brouillon' ; le mobile, si — c'est le même invariant, appliqué
      // aux statuts que le mobile sait produire.
      final bool modification = widget.book != null;
      final String? statutDemande = isDraft
          ? 'brouillon'
          : (modification ? null : 'publie');

      final livreAJour = await _bookService.updateBook(
        livreId,
        champs(statutDemande),
        token,
      );

      // Le serveur a confirmé : ce livre n'est plus « en attente ». La trace
      // part avant l'annonce, et pour CET identifiant seulement — reprendre le
      // brouillon depuis « Mes livres » passe aussi par ici et doit l'effacer.
      await _oublierBrouillon(livreId);

      if (mounted) {
        _showSuccessDialog(
          isModification: modification,
          isDraft: isDraft,
          // L'état d'arrivée vient du SERVEUR, pas du bouton : c'est lui qui
          // tranche (il peut refuser une publication, ou l'avoir déjà
          // enregistrée), et l'auteur doit l'apprendre par cet écran — pas par
          // la notification que reçoivent ses abonnés.
          statutConfirme: livreAJour.statut.trim().toLowerCase(),
        );
      }
    } catch (e) {
      if (mounted) {
        // Quand une fiche a déjà été créée, l'échec ne doit pas laisser croire
        // qu'il n'en reste rien : sans cette phrase, l'auteur recommençait
        // depuis « Publier une œuvre » et fabriquait un second livre.
        final enBrouillon = _livreCreeId != null;
        AppNotifications.showSnackBar(
          context,
          message: enBrouillon
              ? "${_lisible(e)} Votre livre est enregistré en brouillon : "
                    "réessayez ici, ou reprenez-le depuis « Mes livres ». "
                    "Il ne sera pas publié deux fois."
              : _lisible(e),
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
  /// Cette fonction ne retirait que le préfixe, et laissait passer tout le
  /// reste : une coupure réseau affichait « Failed host lookup: '144.91.101.16'
  /// (OS Error: No address associated with hostname) » à un auteur venu publier
  /// un livre. L'adresse du serveur avec.
  ///
  /// messageLisible, dans core/utils/message_erreur.dart, fait déjà ce travail
  /// pour toute l'application : il distingue une panne de transport d'un refus
  /// du serveur, et se tait dès qu'un texte sent le diagnostic. Ce fichier
  /// l'importait déjà sans l'appeler.
  static String _lisible(Object erreur) =>
      messageLisible(erreur, repli: "L'opération a échoué. Réessayez.");

  /// L'annonce de fin, qui NOMME l'état d'arrivée du livre.
  ///
  /// Elle disait « Votre œuvre a été modifiée avec succès. » et rien d'autre :
  /// l'auteur ne pouvait pas savoir si son livre était en vente, en brouillon
  /// ou archivé au sortir de l'enregistrement. Quand le formulaire republiait
  /// à son insu, l'écran restait muet et la nouvelle arrivait aux abonnés
  /// avant lui. [statutConfirme] est le statut RENVOYÉ par le serveur après la
  /// mise à jour — pas celui qu'on croyait demander.
  void _showSuccessDialog({
    required bool isModification,
    required bool isDraft,
    required String statutConfirme,
  }) {
    // Une phrase par état, écrite du point de vue de l'auteur : « en vente »
    // ou « pas en vente », le reste ne l'intéresse pas.
    final String etat = switch (statutConfirme) {
      'publie' => "Elle est en vente, disponible pour vos lecteurs.",
      'brouillon' => "Elle est en brouillon : elle n'est pas en vente.",
      'en_revision' => "Elle reste archivée : elle n'est pas en vente.",
      // Statut inconnu (serveur plus récent que l'application) : on se tait
      // plutôt que d'affirmer un état qu'on ne sait pas lire.
      _ => "",
    };

    final String message;
    if (isModification) {
      message = etat.isEmpty
          ? "Votre œuvre a été modifiée."
          : "Votre œuvre a été modifiée. $etat";
    } else if (statutConfirme == 'publie') {
      message =
          "Votre œuvre a été publiée. Elle est maintenant disponible pour "
          "vos lecteurs.";
    } else if (statutConfirme == 'brouillon' ||
        (statutConfirme.isEmpty && isDraft)) {
      message =
          "L'œuvre a été enregistrée en tant que brouillon. Elle n'est pas "
          "encore en vente.";
    } else {
      message = "Votre œuvre a été enregistrée.";
    }

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
                message,
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

  /// Demande confirmation avant de quitter un téléversement en cours.
  ///
  /// Le retour restait actif pendant l'envoi : un appui distrait emportait
  /// toute la saisie, et la fiche déjà créée finissait en brouillon fantôme.
  /// On n'INTERDIT pas de partir — le téléversement n'a pas de délai
  /// d'expiration, et un envoi bloqué enfermerait l'auteur dans l'écran — on
  /// dit ce que partir coûte.
  Future<bool> _confirmerAbandonEnCours() async {
    final dejaCree = _livreCreeId != null;
    final reponse = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: Text(
          "Publication en cours",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          dejaCree
              ? "Vos fichiers sont en train de partir. Si vous quittez "
                    "maintenant, l'envoi s'arrête et votre saisie est perdue ; "
                    "le livre vous attendra en brouillon dans « Mes livres »."
              : "Vos fichiers sont en train de partir. Si vous quittez "
                    "maintenant, l'envoi s'arrête et votre saisie est perdue.",
          style: GoogleFonts.poppins(
            fontSize: 13.5,
            height: 1.5,
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              "Rester",
              style: GoogleFonts.poppins(color: AppColors.secondaryVariant),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              "Quitter quand même",
              style: GoogleFonts.poppins(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    return reponse ?? false;
  }

  @override
  Widget build(BuildContext context) {
    AppColors.suivreLeTheme(context);
    return PopScope(
      canPop: !_isUploading,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || !_isUploading) return;
        // Le Navigator est saisi AVANT l'attente : le reprendre après coup
        // reviendrait à traverser une frontière asynchrone avec un contexte
        // qui peut ne plus être monté.
        final navigateur = Navigator.of(context);
        final quitter = await _confirmerAbandonEnCours();
        if (!mounted) return;
        if (quitter) navigateur.pop();
      },
      child: _corps(),
    );
  }

  Widget _corps() {
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
          // maybePop et non pop : c'est lui qui consulte le PopScope
          // ci-dessus. `pop()` sortait sans rien demander, même en plein
          // téléversement.
          onPressed: () => Navigator.of(context).maybePop(),
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
                      // Il se montre aux deux etapes : c'est a l'instant de
                      // publier, pas seulement en arrivant, qu'il faut savoir
                      // qu'un brouillon attend.
                      _bandeauBrouillonEnAttente(),
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

  /// Le brouillon laissé par un essai précédent, dit à l'écran.
  ///
  /// Sans ce bandeau, l'auteur revenu sur « Publier une œuvre » après un échec
  /// n'avait aucun moyen de savoir qu'une fiche existait déjà : il resaisissait
  /// tout et le serveur créait un second livre — le brouillon fantôme du
  /// constat d'origine. Reprendre est un choix EXPLICITE : le formulaire est
  /// vide au rouvrir, et adopter l'identifiant en silence écrirait la nouvelle
  /// saisie par-dessus l'ancienne fiche.
  Widget _bandeauBrouillonEnAttente() {
    final id = _brouillonEnAttenteId;
    if (id == null) return const SizedBox.shrink();

    final titre = (_brouillonEnAttenteTitre?.trim().isNotEmpty ?? false)
        ? _brouillonEnAttenteTitre!.trim()
        : "sans titre";
    final repris = _livreCreeId == id;
    final teinte = repris ? AppColors.secondaryVariant : AppColors.warning;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: teinte.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(color: teinte.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                repris ? Icons.edit_note : Icons.history_edu_outlined,
                size: 18,
                color: teinte,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  repris
                      ? "Vous complétez le brouillon « $titre ». Aucun "
                            "nouveau livre ne sera créé."
                      : "Un précédent essai de publication n'est pas allé au "
                            "bout : « $titre » vous attend en brouillon. "
                            "Reprenez-le ici, sans quoi publier maintenant "
                            "créera un second livre.",
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    height: 1.45,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Wrap et non Row : « Publier plutôt un nouveau livre » et
          // « Ignorer » côte à côte débordent sur un écran étroit ou avec un
          // corps de texte agrandi par les réglages système.
          Wrap(
            spacing: 4,
            children: [
              TextButton(
                onPressed: _isUploading
                    ? null
                    : () => setState(
                        () => _livreCreeId = repris ? null : id,
                      ),
                style: TextButton.styleFrom(foregroundColor: teinte),
                child: Text(
                  repris ? "Publier plutôt un nouveau livre" : "Reprendre",
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // « Ne plus me le proposer » : la trace disparaît de l'appareil,
              // le brouillon reste dans « Mes livres ».
              TextButton(
                onPressed: _isUploading
                    ? null
                    : _abandonnerLeBrouillonEnAttente,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                ),
                child: Text(
                  "Ignorer",
                  style: GoogleFonts.poppins(fontSize: 12.5),
                ),
              ),
            ],
          ),
        ],
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
        // Le plancher est annoncé dans l'étiquette du champ : l'auteur le lit
        // avant de saisir, et non après avoir tout rempli.
        label: _parametres != null && _parametres!.prixMinimum > 0
            ? "Prix (FCFA) — minimum ${_enFrancs(_parametres!.prixMinimum)}"
            : "Prix (FCFA)",
        icon: Icons.money,
        keyboardType: TextInputType.number,
        // Le clavier numérique n'empêche RIEN d'entrer : il ne filtre pas le
        // collage, et « 2 500 » ou « 2500.5 » arrivaient tels quels dans le
        // champ pour finir publiés à 0 FCFA. Le filtre, lui, s'applique aussi
        // au collage — et ce qui reste à l'écran est ce qui sera envoyé.
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
              // Le prix saisi est mis de côté avant d'être écrasé : décocher
              // laissait « 0 » dans un champ que la validation refuse, et
              // l'auteur devait retrouver son montant de mémoire.
              _prixAvantGratuit = _prixController.text;
              _prixController.text = "0";
            } else {
              final repris = _prixAvantGratuit ?? '';
              _prixController.text = repris == "0" ? '' : repris;
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
                        // « Modifier » reste « Modifier », et ne publie plus
                        // rien : le bouton dit ce qu'il fait. Un livre déjà en
                        // base garde son statut (voir _publishBook) ; sa mise
                        // en vente se demande depuis la fiche, où l'auteur la
                        // lit avant de l'appuyer.
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
        // Un livre déjà en base qui n'est PAS en vente : on dit où se demande
        // la mise en vente, sinon « Modifier » ressemble à une impasse. C'est
        // le prix à payer pour que ce bouton cesse de publier en douce — et il
        // vaut mieux une phrase que six cents abonnés prévenus par erreur.
        if (widget.book != null &&
            widget.book!.statut.trim().toLowerCase() != 'publie')
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              "Ce livre n'est pas en vente. « Modifier » enregistre vos "
              "corrections sans le mettre en vente : la mise en vente se "
              "demande depuis sa fiche, par « Publier ».",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
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

    // Le prix, contrôlé AVANT tout envoi.
    //
    // Ce contrôle ne dépend d'aucun réglage distant, et c'est essentiel : quand
    // le chargement des paramètres échouait, `_parametres` restait nul, la
    // garde du plancher ci-dessous était entièrement sautée, et n'importe
    // quelle saisie invalide publiait l'œuvre à 0 FCFA — c'est-à-dire
    // gratuitement — sans le moindre avertissement.
    final prix = _prixEnFrancs();
    if (prix == null) {
      AppNotifications.showSnackBar(
        context,
        message:
            "Indiquez le prix en chiffres seulement, sans espace, point ni "
            "virgule (exemple : 2500).",
        isError: true,
      );
      return false;
    }
    if (!_isFree && prix <= 0) {
      AppNotifications.showSnackBar(
        context,
        message:
            "Un prix de 0 FCFA rend l'ouvrage gratuit. Cochez « Publier cet "
            "ouvrage gratuitement » si c'est bien votre intention.",
        isError: true,
      );
      return false;
    }

    // Le prix plancher, dit ici plutôt qu'au retour du serveur.
    //
    // Le contrôle qui fait autorité est côté serveur — un formulaire ne
    // protège rien. Mais sans ce garde-fou, l'auteur remplit tout, téléverse
    // son manuscrit, et se voit refuser à la dernière étape.
    final p = _parametres;
    if (!_isFree && p != null) {
      if (p.sousLePlancher(prix.toDouble())) {
        AppNotifications.showSnackBar(
          context,
          message:
              "Le prix minimum est de ${_enFrancs(p.prixMinimum)} FCFA. "
              "Cochez « gratuitement » si vous ne souhaitez pas vendre ce livre.",
          isError: true,
        );
        return false;
      }
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
          // Fond TEINTÉ, pas plein : le message et l'icône sont peints en
          // AppColors.error sur un fond qui l'était aussi — du rouge sur du
          // rouge. L'écran affichait bien une panne, mais illisible.
          color: AppColors.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: AppColors.error),
            SizedBox(width: 16),
            Expanded(
              child: Text(
                _categoriesError!,
                style: GoogleFonts.poppins(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.refresh, color: AppColors.error),
              tooltip: "Réessayer",
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
    List<TextInputFormatter>? inputFormatters,
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
      inputFormatters: inputFormatters,
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
