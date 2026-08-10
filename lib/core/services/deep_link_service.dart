import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

/// Ouverture de l'application depuis un lien partagé.
///
/// Un lien de recommandation pointe sur `https://<domaine>/book/<id>`. Sans ce
/// service, ce lien ouvrait un navigateur : le destinataire voyait la page web
/// du livre mais ne pouvait pas le lire, alors même qu'il avait l'application.
///
/// Deux cas à traiter, et le second est celui qu'on oublie :
///   - l'application tourne déjà : le lien arrive dans le flux `uriLinkStream` ;
///   - elle était fermée : le lien qui l'a lancée n'est disponible qu'une fois,
///     via `getInitialLink`.
class DeepLinkService {
  DeepLinkService._();
  static final DeepLinkService instance = DeepLinkService._();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _abonnement;

  /// Appelé avec l'identifiant du livre à ouvrir.
  void Function(String livreId)? onLivreDemande;

  bool _demarre = false;

  /// Démarre l'écoute. Idempotent : un second appel ne crée pas de doublon.
  Future<void> demarrer() async {
    if (_demarre) return;
    _demarre = true;

    _abonnement = _appLinks.uriLinkStream.listen(
      _traiter,
      onError: (Object e) => debugPrint('DeepLinkService: $e'),
    );

    // Lien ayant lancé l'application depuis un état fermé.
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) _traiter(initial);
    } catch (e) {
      debugPrint('DeepLinkService: lien initial illisible — $e');
    }
  }

  Future<void> arreter() async {
    await _abonnement?.cancel();
    _abonnement = null;
    _demarre = false;
  }

  void _traiter(Uri uri) {
    final id = extraireLivreID(uri);
    if (id == null) {
      debugPrint('DeepLinkService: lien non reconnu — $uri');
      return;
    }
    onLivreDemande?.call(id);
  }

  /// Extrait l'identifiant du livre d'un lien.
  ///
  /// Accepte `https://domaine/book/<id>` comme le schéma applicatif
  /// `spacelearn://book/<id>`, et tolère une barre oblique finale ou des
  /// paramètres de campagne ajoutés au lien.
  @visibleForTesting
  static String? extraireLivreID(Uri uri) {
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();

    // Schéma applicatif : l'hôte porte le nom de la ressource.
    if (uri.scheme == 'spacelearn' && uri.host == 'book' && segments.isNotEmpty) {
      return segments.first;
    }

    final i = segments.indexOf('book');
    if (i >= 0 && i + 1 < segments.length) {
      return segments[i + 1];
    }
    return null;
  }
}
