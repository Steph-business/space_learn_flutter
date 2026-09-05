import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stockage de la session.
///
/// Le JWT est conservé dans le coffre chiffré de la plateforme (Keystore sur
/// Android, Keychain sur iOS) et non dans SharedPreferences, qui est lisible en
/// clair sur un appareil rooté ou jailbreaké.
///
/// Les données non sensibles (nom affiché, dates de dernière consultation)
/// restent dans SharedPreferences : le coffre est nettement plus lent et n'a
/// aucun intérêt pour elles.
class TokenStorage {
  static const String _tokenKey = "auth_token";
  static const String _userNameKey = "user_name";

  /// Le jeton qui permet d'en obtenir un neuf sans redemander le mot de passe.
  ///
  /// Il vaut trente jours quand le jeton d'accès n'en vaut qu'une heure : c'est
  /// donc lui, désormais, le vrai secret de la session. Il va au coffre, pas
  /// dans les préférences.
  static const String _refreshKey = "refresh_token";

  /// Identifiant du compte connecté.
  ///
  /// Les statistiques de lecture sont rangées par utilisateur, et chaque écran
  /// les rangeait sous une clé différente : la page de lecture sous une chaîne
  /// vide, la page d'accueil sous l'identifiant du compte, les badges sous
  /// celui du *profil* — c'est-à-dire la même valeur pour tous les lecteurs de
  /// l'application. Ce qu'on écrivait, personne ne le relisait.
  ///
  /// Une seule source, ici, à côté du jeton dont il est issu.
  static const String _userIdKey = "user_id";

  // Chiffrement par défaut de la plateforme : Keystore sur Android,
  // Keychain sur iOS.
  static const FlutterSecureStorage _secure = FlutterSecureStorage();

  /// Sauvegarder le token
  static Future<void> saveToken(String token) async {
    await _secure.write(key: _tokenKey, value: token);
  }

  /// Récupérer le token
  ///
  /// Migre de façon transparente un token laissé par une version précédente
  /// dans SharedPreferences, puis l'y supprime.
  static Future<String?> getToken() async {
    final token = await _secure.read(key: _tokenKey);
    if (token != null && token.isNotEmpty) return token;

    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString(_tokenKey);
    if (legacy != null && legacy.isNotEmpty) {
      await _secure.write(key: _tokenKey, value: legacy);
      await prefs.remove(_tokenKey);
      return legacy;
    }
    return null;
  }

  /// Sauvegarder le jeton de rafraîchissement.
  ///
  /// Une chaîne vide n'écrase pas ce qui est déjà là : un serveur d'une version
  /// antérieure ne renvoie pas ce champ, et sa réponse ne doit pas effacer une
  /// session valide.
  static Future<void> saveRefreshToken(String? refresh) async {
    if (refresh == null || refresh.isEmpty) return;
    await _secure.write(key: _refreshKey, value: refresh);
  }

  static Future<String?> getRefreshToken() async {
    return _secure.read(key: _refreshKey);
  }

  /// Supprimer le token (logout)
  static Future<void> clearToken() async {
    await _secure.delete(key: _tokenKey);
    await _secure.delete(key: _refreshKey);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey); // résidu d'une version antérieure
    await prefs.remove(_userNameKey);

    // Les transactions CinetPay encore ouvertes de CE compte partent avec la
    // session, et AVANT l'identifiant qui sert à les retrouver.
    //
    // TransactionEnCoursStore range chaque paiement en cours sous
    // « paiement_en_cours_<compte>_<livre> » et l'écarte au bout de 24 h. Ces
    // entrées survivaient à la déconnexion : elles ne servaient plus à
    // personne — leur porteur ne peut plus être sondé sans son jeton — et
    // restaient sur l'appareil avec un montant et une référence de
    // transaction. Lire l'identifiant après l'avoir effacé n'aurait rien
    // trouvé : d'où cet ordre.
    final userId = prefs.getString(_userIdKey)?.trim() ?? '';
    if (userId.isNotEmpty) {
      final prefixe = 'paiement_en_cours_${userId}_';
      final cles = prefs
          .getKeys()
          .where((c) => c.startsWith(prefixe))
          .toList();
      for (final cle in cles) {
        await prefs.remove(cle);
      }
    }

    // Sans cela, le lecteur suivant sur le même téléphone héritait du temps de
    // lecture, de la série de jours et des titres lus par le précédent.
    await prefs.remove(_userIdKey);
  }

  /// Sauvegarder l'identifiant du compte connecté.
  static Future<void> saveUserId(String id) async {
    if (id.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userIdKey, id.trim());
  }

  /// Récupérer l'identifiant du compte connecté.
  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_userIdKey);
    if (id == null || id.trim().isEmpty) return null;
    return id.trim();
  }

  /// Vérifier si connecté
  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// Sauvegarder le nom de l'utilisateur
  static Future<void> saveUserName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userNameKey, name);
  }

  /// Récupérer le nom de l'utilisateur
  static Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userNameKey);
  }

  static const String _discussionViewedPrefix = "discussion_viewed_";

  /// `discussion_viewed_<compte>_<discussion>` : rattachée au compte.
  ///
  /// La clé ne portait que l'identifiant de la discussion : les marqueurs
  /// « vu le » du compte A survivaient à sa déconnexion, et le compte B, sur
  /// le même téléphone, voyait des discussions jamais ouvertes présentées
  /// comme déjà lues — les pastilles de non-lus s'éteignaient à tort.
  static Future<String> _cleDiscussionVue(String discussionId) async {
    final compte = await getUserId() ?? '';
    return "$_discussionViewedPrefix${compte}_$discussionId";
  }

  /// Sauvegarder la date de dernière vue d'une discussion
  static Future<void> saveDiscussionLastViewed(String discussionId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      await _cleDiscussionVue(discussionId),
      DateTime.now().toIso8601String(),
    );
  }

  /// Récupérer la date de dernière vue d'une discussion
  static Future<DateTime?> getDiscussionLastViewed(String discussionId) async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getString(await _cleDiscussionVue(discussionId));
    if (val != null) return DateTime.tryParse(val);
    return null;
  }

  /// Efface tous les marqueurs « discussion vue le », anciens formats compris.
  ///
  /// Appelée à la fin de session (SessionService.terminer) : ces dates sont un
  /// état de lecture personnel et ne doivent pas être héritées par le compte
  /// suivant. Les clés d'avant le suffixe (`discussion_viewed_<id>`)
  /// partagent le même préfixe et partent avec.
  static Future<void> clearDiscussionMarkers() async {
    final prefs = await SharedPreferences.getInstance();
    final cles = prefs
        .getKeys()
        .where((c) => c.startsWith(_discussionViewedPrefix))
        .toList();
    for (final cle in cles) {
      await prefs.remove(cle);
    }
  }
}
