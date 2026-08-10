import 'package:flutter/foundation.dart';

import 'book_cache_service.dart';
import '../utils/profile_storage.dart';
import '../utils/token_storage.dart';

/// Fin de session.
///
/// Point unique de nettoyage : jeton, profil sélectionné et livres téléchargés.
/// Les trois chemins de déconnexion effaçaient auparavant le seul jeton, ce qui
/// laissait sur l'appareil la bibliothèque complète de l'utilisateur — lisible
/// hors ligne par la personne suivante à s'y connecter, ou par l'acheteur d'un
/// téléphone d'occasion.
class SessionService {
  /// Efface toute trace locale de la session.
  ///
  /// Chaque étape est indépendante : l'échec de l'une ne doit pas empêcher les
  /// autres. Une déconnexion qui laisse des données derrière elle est pire
  /// qu'une déconnexion partiellement en erreur.
  static Future<void> terminer() async {
    for (final etape in <(String, Future<void> Function())>[
      ('jeton', TokenStorage.clearToken),
      ('profil', ProfileStorage.clearSelectedProfile),
      ('rôle', ProfileStorage.clearSelectedProfileRole),
      ('livres téléchargés', BookCacheService().clearAllCache),
    ]) {
      try {
        await etape.$2();
      } catch (e) {
        debugPrint('SessionService: échec du nettoyage (${etape.$1}) — $e');
      }
    }
  }
}
