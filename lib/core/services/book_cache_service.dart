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
  Future<String> _getBookFilePath(String bookId, String url) async {
    final booksDir = await _getBooksDir();
    final extension = _getExtensionFromUrl(url);
    return '${booksDir.path}/$bookId$extension';
  }

  /// Extrait l'extension du fichier depuis l'URL.
  String _getExtensionFromUrl(String url) {
    final uri = Uri.parse(url);
    final path = uri.path.toLowerCase();
    if (path.endsWith('.epub')) return '.epub';
    if (path.endsWith('.pdf')) return '.pdf';
    return '.pdf'; // Par défaut
  }

  /// Vérifie si un livre est déjà en cache local.
  Future<bool> isBookCached(String bookId, String url) async {
    if (kIsWeb) return false;
    try {
      final filePath = await _getBookFilePath(bookId, url);
      return File(filePath).existsSync();
    } catch (e) {
      debugPrint('Erreur vérification cache: $e');
      return false;
    }
  }

  /// Retourne les bytes du fichier depuis le cache local.
  /// Retourne null si le fichier n'existe pas.
  Future<Uint8List?> getCachedBookBytes(String bookId, String url) async {
    if (kIsWeb) return null;
    try {
      final filePath = await _getBookFilePath(bookId, url);
      final file = File(filePath);
      if (await file.exists()) {
        final fileBytes = await file.readAsBytes();

        if (fileBytes.length < 4) {
          await file.delete();
          return null;
        }

        // Vérifier la signature du fichier (Magic Numbers)
        // PDF commence par '%PDF' (0x25, 0x50, 0x44, 0x46)
        final bool isPdf =
            fileBytes[0] == 0x25 &&
            fileBytes[1] == 0x50 &&
            fileBytes[2] == 0x44 &&
            fileBytes[3] == 0x46;
        // EPUB est un fichier ZIP, qui commence par 'PK' (0x50, 0x4B)
        final bool isZip = fileBytes[0] == 0x50 && fileBytes[1] == 0x4B;

        // Si ce n'est ni un PDF ni un EPUB valide (par exemple, un ancien fichier
        // chiffré par erreur, ou une page d'erreur HTML), on le supprime.
        if (!isPdf && !isZip) {
          debugPrint(
            'Fichier cache corrompu détecté, suppression pour forcer le retéléchargement...',
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
      }
      return null;
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

      if (!kIsWeb) {
        final filePath = await _getBookFilePath(bookId, url);
        // Sauvegarder en cache local (en clair)
        final file = File(filePath);
        await file.writeAsBytes(bytes);
        debugPrint(
          'Livre $bookId mis en cache : ${(bytes.length / 1024 / 1024).toStringAsFixed(2)} Mo',
        );
        await _appliquerPlafond();
      }

      return bytes;
    } catch (e) {
      debugPrint('Erreur téléchargement/cache: $e');
      return null;
    }
  }

  /// Supprime un fichier du cache local.
  Future<void> clearBookCache(String bookId, String url) async {
    if (kIsWeb) return;
    try {
      final filePath = await _getBookFilePath(bookId, url);
      final file = File(filePath);
      if (await file.exists()) {
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

      await for (final entite in booksDir.list()) {
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

        entrees.add(LivreEnCache(
          livreId: id,
          chemin: entity.path,
          octets: await entity.length(),
          modifieLe: await entity.lastModified(),
        ));
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
      await for (final entity in booksDir.list()) {
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
