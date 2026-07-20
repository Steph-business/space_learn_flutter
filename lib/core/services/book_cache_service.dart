import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
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
        final bool isPdf = fileBytes[0] == 0x25 && fileBytes[1] == 0x50 && 
                           fileBytes[2] == 0x44 && fileBytes[3] == 0x46;
        // EPUB est un fichier ZIP, qui commence par 'PK' (0x50, 0x4B)
        final bool isZip = fileBytes[0] == 0x50 && fileBytes[1] == 0x4B;

        // Si ce n'est ni un PDF ni un EPUB valide (par exemple, un ancien fichier
        // chiffré par erreur, ou une page d'erreur HTML), on le supprime.
        if (!isPdf && !isZip) {
          debugPrint('Fichier cache corrompu détecté, suppression pour forcer le retéléchargement...');
          await file.delete();
          return null; 
        }
        
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
        debugPrint('Livre $bookId mis en cache (sans DRM): ${(bytes.length / 1024 / 1024).toStringAsFixed(2)} Mo');
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