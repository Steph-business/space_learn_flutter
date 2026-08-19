import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Service de cache local des fichiers de livres (PDF/EPUB).
/// Permet la lecture hors-ligne en téléchargeant les fichiers
/// dans le répertoire de documents de l'application.
class BookCacheService {
  static final BookCacheService _instance = BookCacheService._internal();
  factory BookCacheService() => _instance;
  BookCacheService._internal();

  static const String _booksDirName = 'cached_books';

  /// Les aperçus, rangés à part.
  ///
  /// L'extrait et le manuscrit appartiennent au même livre, donc au même
  /// identifiant : ils s'écrasaient l'un l'autre sous `<id>.pdf`. Un lecteur
  /// qui consultait l'aperçu puis achetait l'ouvrage se voyait resservir les
  /// deux pages de l'aperçu — définitivement, puisque le cache n'expire pas.
  ///
  /// Un sous-dossier plutôt qu'un suffixe dans le nom : l'écran
  /// « Téléchargements » liste le contenu du dossier sans descendre, et un
  /// aperçu n'est pas un livre téléchargé.
  static const String _extraitsDirName = 'extraits';

  /// Plafond du cache local.
  ///
  /// Sans limite, la bibliotheque telechargee grossit indefiniment jusqu'a
  /// saturer l'appareil, et l'utilisateur n'a aucun moyen de s'en apercevoir
  /// avant d'y etre confronte.
  static const int tailleMaxCacheOctets = 500 * 1024 * 1024; // 500 Mo

  /// Retourne le répertoire de cache des livres.
  Future<Directory> _getBooksDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final booksDir = Directory('${appDir.path}/$_booksDirName');
    if (!await booksDir.exists()) {
      await booksDir.create(recursive: true);
    }
    return booksDir;
  }

  /// Génère le chemin local d'un fichier de livre.
  ///
  /// La clé est l'identifiant du livre, jamais l'adresse : celle-ci est signée
  /// pour quinze minutes et change à chaque ouverture. L'indexer dessus
  /// retéléchargerait le livre entier à chaque fois.
  Future<String> _getBookFilePath(
    String bookId,
    String url, {
    bool extrait = false,
  }) async {
    var dossier = await _getBooksDir();
    if (extrait) {
      dossier = Directory('${dossier.path}/$_extraitsDirName');
      if (!await dossier.exists()) {
        await dossier.create(recursive: true);
      }
    }
    final extension = _getExtensionFromUrl(url);
    return '${dossier.path}/$bookId$extension';
  }

  /// Extrait l'extension du fichier depuis l'URL.
  ///
  /// Sert à ÉCRIRE, jamais à retrouver : voir [_fichierDuLivre].
  String _getExtensionFromUrl(String url) {
    final uri = Uri.parse(url);
    final path = uri.path.toLowerCase();
    if (path.endsWith('.epub')) return '.epub';
    if (path.endsWith('.pdf')) return '.pdf';
    return '.pdf'; // Par défaut
  }

  /// Le fichier déjà présent pour ce livre, quelle que soit son extension.
  ///
  /// La clé est l'identifiant, et lui seul. L'extension venait de l'adresse,
  /// et l'adresse ne la porte pas toujours : le serveur signe tantôt un chemin
  /// qui finit par `.epub`, tantôt un chemin sans nom de fichier — auquel cas
  /// [_getExtensionFromUrl] rend `.pdf` par défaut. Un EPUB téléchargé sous
  /// `<id>.epub` était alors cherché sous `<id>.pdf`, jamais trouvé, et
  /// retéléchargé à chaque ouverture. Rien ne le signalait : le cache
  /// répondait simplement « absent ».
  ///
  /// Un livre n'a qu'un fichier : chercher `<id>.*` lève l'ambiguïté sans rien
  /// supposer de l'adresse.
  Future<File?> _fichierDuLivre(String bookId, {bool extrait = false}) async {
    if (bookId.isEmpty) return null;

    var dossier = await _getBooksDir();
    if (extrait) dossier = Directory('${dossier.path}/$_extraitsDirName');
    if (!await dossier.exists()) return null;

    final vus = <String>[];
    await for (final entite in dossier.list()) {
      if (entite is! File) continue;
      final nom = entite.path.split(RegExp(r'[/\\]')).last;
      final point = nom.lastIndexOf('.');
      final id = point > 0 ? nom.substring(0, point) : nom;
      vus.add(nom);
      if (id == bookId) return entite;
    }

    // Ce que le dossier contenait au moment du manque. Sans cette ligne, un
    // livre retéléchargé à chaque ouverture ne laisse aucune trace : le cache
    // se contente de répondre « absent », et on ne sait pas s'il a été effacé,
    // jamais écrit, ou rangé sous un autre nom.
    debugPrint(
      'Cache : $bookId absent de ${dossier.path} '
      '(${vus.isEmpty ? 'dossier vide' : vus.join(', ')})',
    );
    return null;
  }

  /// Le fichier du livre présent sur l'appareil, s'il y est.
  ///
  /// Exposé pour que le lecteur puisse consulter le disque AVANT de réclamer
  /// une adresse au serveur : celle-ci est signée pour quinze minutes, et un
  /// livre déjà téléchargé n'a aucune raison d'exiger du réseau pour s'ouvrir.
  Future<File?> fichierEnCache(String bookId, {bool extrait = false}) async {
    if (kIsWeb) return null;
    try {
      return await _fichierDuLivre(bookId, extrait: extrait);
    } catch (e) {
      debugPrint('Erreur vérification cache: $e');
      return null;
    }
  }

  /// Fenêtre dans laquelle la signature d'un PDF est cherchée.
  static const int _fenetreSignature = 1024;

  /// Ces octets ressemblent-ils à un PDF ou à un EPUB ?
  ///
  /// La signature était exigée au tout premier octet. Or un PDF reste valide —
  /// et s'affiche sans broncher — quand `%PDF` est précédé d'une ligne vide,
  /// d'un BOM UTF-8 ou de quelques octets laissés par l'outil qui l'a produit ;
  /// les visionneuses tolèrent cet en-tête. Le contrôle rejetait donc des
  /// fichiers que l'application venait d'afficher : le cache était effacé à la
  /// lecture suivante, le livre retéléchargé, affiché de nouveau — et ainsi à
  /// chaque ouverture, sans que rien ne le signale puisque la lecture, elle,
  /// fonctionnait.
  bool signatureValide(Uint8List octets) {
    if (octets.length < 4) return false;

    // 'PK' — un EPUB est une archive ZIP, et celle-ci commence vraiment par sa
    // signature. La chercher plus loin accepterait n'importe quel fichier
    // contenant ces deux octets.
    if (octets[0] == 0x50 && octets[1] == 0x4B) return true;

    // '%PDF', dans les premiers octets et non au premier.
    final int fin = octets.length < _fenetreSignature
        ? octets.length
        : _fenetreSignature;
    for (var i = 0; i + 3 < fin; i++) {
      if (octets[i] == 0x25 &&
          octets[i + 1] == 0x50 &&
          octets[i + 2] == 0x44 &&
          octets[i + 3] == 0x46) {
        return true;
      }
    }

    return false;
  }

  /// Vérifie si un livre est déjà en cache local.
  ///
  /// [url] n'entre pas dans la décision : elle est signée pour quinze minutes
  /// et change à chaque ouverture. Le paramètre reste pour ne pas casser les
  /// appelants.
  Future<bool> isBookCached(
    String bookId,
    String url, {
    bool extrait = false,
  }) async {
    if (kIsWeb) return false;
    return await fichierEnCache(bookId, extrait: extrait) != null;
  }

  /// Retourne les bytes du fichier depuis le cache local.
  /// Retourne null si le fichier n'existe pas.
  Future<Uint8List?> getCachedBookBytes(
    String bookId,
    String url, {
    bool extrait = false,
  }) async {
    if (kIsWeb) return null;
    try {
      final file = await _fichierDuLivre(bookId, extrait: extrait);
      if (file == null) return null;

      final fileBytes = await file.readAsBytes();

      // Ni PDF ni EPUB : un fichier tronqué, ou une page d'erreur enregistrée
      // à la place du manuscrit. On l'efface pour laisser sa chance au
      // téléchargement suivant.
      if (!signatureValide(fileBytes)) {
        debugPrint(
          'Cache : $bookId ne porte ni signature PDF ni signature EPUB '
          '(${fileBytes.length} octets) — suppression.',
        );
        await file.delete();
        return null;
      }

      // Horodatage rafraichi a chaque lecture : l'eviction supprime alors
      // les livres les moins consultes, et non les plus anciennement
      // telecharges — un livre relu regulierement doit survivre.
      try {
        await file.setLastModified(DateTime.now());
      } catch (_) {}

      return fileBytes;
    } catch (e) {
      debugPrint('Erreur lecture cache: $e');
      return null;
    }
  }

  /// Télécharge le fichier depuis le réseau, le sauvegarde en cache local,
  /// et retourne les bytes du fichier.
  /// [onProgress] est appelé avec une valeur entre 0.0 et 1.0.
  Future<Uint8List?> downloadAndCache(
    String bookId,
    String url, {
    void Function(double progress)? onProgress,
    bool extrait = false,
  }) async {
    try {
      // Téléchargement avec suivi de progression
      final request = http.Request('GET', Uri.parse(url));
      final response = await http.Client().send(request);

      if (response.statusCode != 200) {
        debugPrint('Erreur HTTP ${response.statusCode} lors du téléchargement');
        return null;
      }

      final totalBytes = response.contentLength ?? -1;
      final List<int> receivedBytes = [];
      int downloadedBytes = 0;

      await for (final chunk in response.stream) {
        receivedBytes.addAll(chunk);
        downloadedBytes += chunk.length;

        if (totalBytes > 0 && onProgress != null) {
          onProgress(downloadedBytes / totalBytes);
        }
      }

      final bytes = Uint8List.fromList(receivedBytes);

      // Ce qui est refusé à la lecture doit l'être aussi à l'écriture.
      //
      // Le contrôle de signature n'existait qu'au moment de relire le cache :
      // des octets qui n'en portaient pas étaient enregistrés, rendus au
      // lecteur — qui les affichait sans difficulté — puis effacés à
      // l'ouverture suivante. Le livre se retéléchargeait donc à chaque fois,
      // en silence, parce que les deux extrémités ne s'accordaient pas sur ce
      // qu'est un fichier valable.
      if (!signatureValide(bytes)) {
        debugPrint(
          'Téléchargement de $bookId : ni signature PDF ni signature EPUB '
          '(${bytes.length} octets). Rien n\'est mis en cache.',
        );
        return null;
      }

      if (!kIsWeb) {
        final filePath = await _getBookFilePath(bookId, url, extrait: extrait);

        // Un même livre ne doit pas laisser deux fichiers derrière lui. Une
        // version antérieure a pu l'écrire sous une autre extension ; sans
        // cela les deux cohabiteraient, et la place occupée doublerait.
        final ancien = await _fichierDuLivre(bookId, extrait: extrait);
        if (ancien != null && ancien.path != filePath) {
          try {
            await ancien.delete();
          } catch (_) {}
        }

        // Sauvegarder en cache local (en clair)
        final file = File(filePath);
        await file.writeAsBytes(bytes, flush: true);

        // Le succès de l'écriture n'était jamais vérifié. Un disque plein rend
        // la main sans avoir tout écrit, et le livre repart en téléchargement
        // à l'ouverture suivante sans que rien ne dise pourquoi.
        final ecrit = await file.length();
        if (ecrit == bytes.length) {
          debugPrint(
            'Livre $bookId mis en cache : ${(bytes.length / 1024 / 1024).toStringAsFixed(2)} Mo',
          );
        } else {
          debugPrint(
            'Cache : $bookId écrit partiellement ($ecrit / ${bytes.length} '
            'octets) — il sera retéléchargé.',
          );
        }
        await _appliquerPlafond();
      }

      return bytes;
    } catch (e) {
      debugPrint('Erreur téléchargement/cache: $e');
      return null;
    }
  }

  /// Supprime un fichier du cache local.
  Future<void> clearBookCache(
    String bookId,
    String url, {
    bool extrait = false,
  }) async {
    if (kIsWeb) return;
    try {
      final file = await _fichierDuLivre(bookId, extrait: extrait);
      if (file != null) {
        await file.delete();
        debugPrint('Cache supprimé pour le livre $bookId');
      }
    } catch (e) {
      debugPrint('Erreur suppression cache: $e');
    }
  }

  /// Supprime les livres les moins recemment lus jusqu'a repasser sous le
  /// plafond.
  Future<void> _appliquerPlafond() async {
    if (kIsWeb) return;
    try {
      final booksDir = await _getBooksDir();
      if (!await booksDir.exists()) return;

      final fichiers = <({File fichier, int taille, DateTime vu})>[];
      var total = 0;

      // Récursif : les aperçus vivent dans un sous-dossier et occupent de la
      // place eux aussi. Les ignorer laisserait le cache dépasser son plafond.
      await for (final entite in booksDir.list(recursive: true)) {
        if (entite is! File) continue;
        final stat = await entite.stat();
        total += stat.size;
        fichiers.add((fichier: entite, taille: stat.size, vu: stat.modified));
      }

      if (total <= tailleMaxCacheOctets) return;

      // Du moins recemment lu au plus recent.
      fichiers.sort((a, b) => a.vu.compareTo(b.vu));

      for (final f in fichiers) {
        if (total <= tailleMaxCacheOctets) break;
        try {
          await f.fichier.delete();
          total -= f.taille;
          debugPrint(
            'Cache : ${f.fichier.path.split('/').last} supprime '
            '(${(f.taille / 1024 / 1024).toStringAsFixed(1)} Mo liberes)',
          );
        } catch (e) {
          debugPrint('Cache : suppression impossible — $e');
        }
      }
    } catch (e) {
      debugPrint('Erreur application du plafond de cache: $e');
    }
  }

  /// Les livres réellement présents sur l'appareil.
  ///
  /// L'écran « Téléchargements » n'avait aucun moyen de savoir ce qui était
  /// stocké : il affichait trois titres écrits en dur — dont un ouvrage d'un
  /// certain « Albert E. » — et son bouton de suppression annonçait « Livre
  /// supprimé de l'appareil » sans rien effacer.
  ///
  /// Le nom du fichier porte l'identifiant du livre ; c'est lui qui permet de
  /// retrouver le titre dans la bibliothèque du lecteur.
  Future<List<LivreEnCache>> listerCache() async {
    if (kIsWeb) return const [];
    try {
      final booksDir = await _getBooksDir();
      if (!await booksDir.exists()) return const [];

      final entrees = <LivreEnCache>[];
      await for (final entity in booksDir.list()) {
        if (entity is! File) continue;
        final nom = entity.path.split(RegExp(r'[/\\]')).last;
        final point = nom.lastIndexOf('.');
        final id = point > 0 ? nom.substring(0, point) : nom;
        if (id.isEmpty) continue;

        entrees.add(
          LivreEnCache(
            livreId: id,
            chemin: entity.path,
            octets: await entity.length(),
            modifieLe: await entity.lastModified(),
          ),
        );
      }

      // Le plus récemment ouvert d'abord : c'est celui qu'on cherche.
      entrees.sort((a, b) => b.modifieLe.compareTo(a.modifieLe));
      return entrees;
    } catch (e) {
      debugPrint('Erreur listage du cache: $e');
      return const [];
    }
  }

  /// Supprime un fichier du cache par son chemin.
  ///
  /// Le pendant de [listerCache] : l'écran connaît le chemin, il n'a pas à
  /// reconstruire l'URL d'origine pour effacer.
  Future<bool> supprimerParChemin(String chemin) async {
    if (kIsWeb) return false;
    try {
      final f = File(chemin);
      if (!await f.exists()) return false;
      await f.delete();
      return true;
    } catch (e) {
      debugPrint('Erreur suppression du fichier en cache: $e');
      return false;
    }
  }

  /// Retourne la taille totale du cache en octets.
  Future<int> getCacheSize() async {
    if (kIsWeb) return 0;
    try {
      final booksDir = await _getBooksDir();
      int totalSize = 0;
      await for (final entity in booksDir.list(recursive: true)) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
      return totalSize;
    } catch (e) {
      debugPrint('Erreur calcul taille cache: $e');
      return 0;
    }
  }

  /// Vide entièrement le cache des livres.
  Future<void> clearAllCache() async {
    if (kIsWeb) return;
    try {
      final booksDir = await _getBooksDir();
      if (await booksDir.exists()) {
        await booksDir.delete(recursive: true);
        debugPrint('Cache des livres entièrement vidé');
      }
    } catch (e) {
      debugPrint('Erreur vidage cache: $e');
    }
  }
}

/// Un livre présent sur l'appareil.
///
/// Le nom du fichier porte l'identifiant du livre ; le titre, lui, vit dans la
/// bibliothèque du lecteur et se recoupe à l'affichage.
class LivreEnCache {
  const LivreEnCache({
    required this.livreId,
    required this.chemin,
    required this.octets,
    required this.modifieLe,
  });

  final String livreId;
  final String chemin;
  final int octets;
  final DateTime modifieLe;

  /// La taille, telle qu'on l'écrit à quelqu'un.
  String get taille {
    if (octets >= 1024 * 1024) {
      return '${(octets / (1024 * 1024)).toStringAsFixed(1)} Mo';
    }
    if (octets >= 1024) return '${(octets / 1024).toStringAsFixed(0)} Ko';
    return '$octets octets';
  }
}
