/// api_routes.dart
///
/// SI L'APPLICATION NE JOINT AUCUN SERVEUR, C'EST ICI QUE ÇA SE JOUE.
///
/// L'adresse du serveur n'est plus écrite dans ce fichier. Ce dépôt est
/// PUBLIC : une adresse figée dans les sources oblige à modifier — et à
/// republier — du code le jour où l'on passe à un nom de domaine. Elle vit
/// donc dans `dart_define.json`, ignoré par Git, fourni à la compilation :
///
///   flutter run   --dart-define-from-file=dart_define.json
///   flutter build apk --release --dart-define-from-file=dart_define.json
///
/// Sans ce fichier, on retombe sur `localhost` : l'application cherche le
/// serveur sur l'appareil lui-même et ne trouve rien. C'est voulu — un repli
/// qui échoue tout de suite vaut mieux qu'un repli qui parle en douce à une
/// machine de production. Le modèle à recopier est `dart_define.example.json`
/// (il porte aussi l'identifiant client Google, lu ailleurs dans l'app ; les
/// clés Supabase en ont disparu, l'application ne parle plus à Supabase).
///
/// ── LES DEUX PORTS DIRECTS, ET LE JOUR OÙ ILS DEVRONT DISPARAÎTRE ────────
///
/// L'adresse en service aujourd'hui vise les ports 8083 et 8084 en http. Ce
/// n'est pas le chemin public prévu : les deux proxys du projet ne parlent
/// qu'à la boucle locale (Stepace_learn_web/deploiement/space-learn.conf,
/// space_learn_livres/deploy/Caddyfile → 127.0.0.1:8083 et :8084). Si
/// l'application les joint quand même, c'est que le pare-feu laisse ces deux
/// ports ouverts sur Internet — et alors tout ce que le proxy porte lui est
/// facultatif : plafond de téléversement, limitation de débit, et surtout TLS.
///
/// LA BASCULE EST UN CHANGEMENT DE CONFIGURATION, PAS DE CODE. Chaque constante
/// ci-dessous s'écrit « origine + chemin », et les deux proxys routent déjà
/// TOUS les chemins que cette application appelle :
///
///   /auth/*, /utilisateurs/*        → 8083 (serveur d'authentification)
///   /api/*                          → 8084 (serveur métier)
///   /upload                         → 8084 (uploadService.dart — le seul
///                                     chemin hors /api/, et il a son bloc
///                                     dans les deux proxys : vérifié)
///
/// Il suffit donc d'écrire la même origine sans port dans les deux variables :
///
///   "API_BASE_URL":     "https://api.mondomaine.tld",
///   "API_BASE_URL_GIN": "https://api.mondomaine.tld"
///
/// Les deux valeurs restent distinctes dans le code — elles désignent deux
/// services, et rien ne dit qu'ils resteront toujours derrière la même porte.
///
/// L'ORDRE COMPTE. Un certificat posé sur le 443 ne rattrape pas un APK déjà
/// installé : il continuera d'appeler 8083/8084 en clair jusqu'à ce que sa
/// version soit remplacée. La reconstruction et la publication de l'APK
/// viennent AVANT l'annonce du passage en HTTPS, sinon le site aura l'air
/// corrigé pendant que la majorité du trafic sera restée en clair. `main.dart`
/// (`_avertirSiTraficEnClair`) le rappelle au lancement en débogage, et
/// `run.ps1` (action `release`) le redemande — en bloquant — juste avant de
/// construire l'APK que l'on distribue.
class ApiRoutes {
  /// Hôte du serveur. Voir l'en-tête du fichier : la vraie valeur arrive par
  /// `--dart-define-from-file`, jamais par ce défaut.
  static const String host = String.fromEnvironment(
    'API_HOST',
    defaultValue: 'localhost',
  );
  static const String hosts = host;

  // Serveur d'authentification (Go, port 8083).
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://$host:8083',
  );

  // Serveur métier (Go/Gin, port 8084).
  static const String baseUrlsGin = String.fromEnvironment(
    'API_BASE_URL_GIN',
    defaultValue: 'http://$host:8084',
  );

  // Auth routes
  static const String profils = "$baseUrl/auth/profils";
  static const String register = "$baseUrl/auth/register";
  static const String login = "$baseUrl/auth/login";

  /// Connexion **et** inscription par Google : une seule route, car on
  /// appuie sur « Continuer avec Google » sans savoir si un compte existe.
  static const String google = "$baseUrl/auth/google";
  static const String logout = "$baseUrl/auth/logout";

  /// Prolonge la session sans redemander le mot de passe.
  ///
  /// Le jeton d'accès ne vit qu'une heure ; celui-ci le renouvelle pendant
  /// trente jours. `ApiClient` l'appelle tout seul quand une requête revient
  /// en 401 — aucun écran n'a à s'en occuper.
  static const String refresh = "$baseUrl/auth/refresh";
  static const String sendOtp = "$baseUrl/auth/send-otp";
  static const String verifyOtp = "$baseUrl/auth/verify-otp";
  static const String verifyRegistration = "$baseUrl/auth/verification";
  static const String forgotPassword = "$baseUrl/auth/forgot-password";
  static const String resetPassword = "$baseUrl/auth/reset-password";

  // User routes
  static const String getUser = "$baseUrl/utilisateurs/me";
  //
  // `updateUser = "$baseUrl/utilisateurs/update"` est retirée : c'était un
  // piège. Le serveur d'authentification n'expose pas `/utilisateurs/update` ;
  // il expose `PUT /utilisateurs/:id`. Cette constante serait donc tombée sur
  // cette route-là avec `id = "update"` — un « Identifiant invalide », comme
  // pour l'ancienne constante de changement de mot de passe juste en dessous.
  // Aucun appelant ne s'en servait ; mieux vaut qu'elle ne tente personne.
  static const String selectProfile = "$baseUrl/utilisateurs/me/profil";

  /// Changement de mot de passe : POST, et l'identifiant du compte dans le
  /// chemin. Une constante sans identifiant tombait sur `PUT /:id`, la route
  /// de modification de profil, qui répondait « Identifiant invalide ».
  static String changePassword(String userId) =>
      "$baseUrl/utilisateurs/$userId/change-password";

  // Book routes
  static const String books = "$baseUrlsGin/api/books";
  static const String bookById = "$baseUrlsGin/api/books/:id";
  static const String booksByAuthor =
      "$baseUrlsGin/api/books/author/:auteur_id";
  static const String shareBook = "$baseUrlsGin/api/books/:id/share";

  // Payment routes
  static const String payments = "$baseUrlsGin/api/payments";
  static const String paymentById = "$baseUrlsGin/api/payments/:id";
  static const String cinetpayStatus =
      "$baseUrlsGin/api/payments/cinetpay/status/:transactionId";
  static const String cinetpayWebhook =
      "$baseUrlsGin/api/payments/cinetpay/webhook";

  // Library routes
  static const String library = "$baseUrlsGin/api/library";
  static const String removeFromLibrary = "$baseUrlsGin/api/library/:livre_id";

  // Relations routes
  static const String relations = "$baseUrlsGin/api/relations";
  static const String followUser = "$baseUrlsGin/api/relations/follow/:suit_id";
  static const String unfollowUser =
      "$baseUrlsGin/api/relations/unfollow/:suit_id";
  static const String getFollowers =
      "$baseUrlsGin/api/relations/followers/:utilisateur_id";
  static const String getFollowing =
      "$baseUrlsGin/api/relations/following/:utilisateur_id";

  // Favorites routes
  static const String favorites = "$baseUrlsGin/api/favorites";
  static const String removeFavorite = "$baseUrlsGin/api/favorites/:livre_id";

  // AUCUNE ROUTE DE STATISTIQUES PAR LIVRE N'EST NOMMÉE ICI. C'est délibéré.
  //
  // Six constantes ont été retirées avec les services morts qui les portaient :
  // `bookStats`, `bookStatsByBook`, `detailedStats`, `detailedStatsByBook`,
  // puis `updateBookStats` et `updateDetailedStats`. Aucun écran ne les lisait
  // — un `grep` sur lib/ et test/ ne rendait plus que leur propre déclaration.
  //
  // Ce ne sont pourtant pas les routes qui manquent : elles existent sur le
  // serveur (`modules/statistiques/routes.go`, réservées à l'AUTEUR du livre).
  // Ce sont les ÉCRITURES qui sont indésirables. `BookStatsService` savait
  // écrire vues, revenus et note moyenne — des chiffres que le serveur calcule
  // lui-même —, et `PUT /api/detailed-stats/:livre_id` est exactement la route
  // dont l'écriture partielle remettait à zéro les six statistiques d'un livre,
  // le défaut refermé dans `recordReadingTime`. Une constante toute prête, avec
  // un nom qui commence par « update », c'est le chemin tracé d'avance vers un
  // raccordement pressé qui rouvrirait ce trou-là.
  //
  // Si un écran a un jour besoin de LIRE ces statistiques, la constante se
  // réécrit en deux lignes — mais on la nommera pour la lecture, pas pour
  // l'écriture.

  // Reading settings routes
  static const String readingSettings =
      "$baseUrlsGin/api/user/settings/reading";

  /// Préférences de publication d'un auteur : visibilité, licence, devise.
  /// La réponse porte aussi sa part réelle sur chaque vente, calculée par le
  /// serveur — l'écran l'affichait auparavant dans un champ libre.
  static const String publicationSettings =
      "$baseUrlsGin/api/user/settings/publication";

  // Reading activity routes
  static const String readingActivity = "$baseUrlsGin/api/reading/activity";

  /// Temps de lecture du LECTEUR, par journée — distinct de detailed-stats,
  /// qui compte par livre pour l'auteur. C'est ce qui fait vivre le temps
  /// cumulé et la série de jours hors du téléphone.
  static const String readingTemps = "$baseUrlsGin/api/reading/temps";
  static const String readingBilan = "$baseUrlsGin/api/reading/bilan";

  /// Créneaux de lecture. Le RÉGLAGE suit le compte ; la notification, elle,
  /// reste programmée sur l'appareil — c'est sa nature.
  static const String readingCreneaux = "$baseUrlsGin/api/reading/creneaux";
  static const String readingActivities = "$baseUrlsGin/api/reading/activities";
  static const String readingProgress =
      "$baseUrlsGin/api/library/progress/:livre_id";

  // Bookmarks routes
  static const String bookmarks = "$baseUrlsGin/api/reading/bookmarks";
  static const String bookmarksByLivre =
      "$baseUrlsGin/api/reading/bookmarks/livre/:livre_id";
  static const String bookmarkDetail = "$baseUrlsGin/api/reading/bookmarks/:id";
  static const String bookmarksClearAll =
      "$baseUrlsGin/api/reading/bookmarks/all/:livre_id";

  // Recommendations routes
  static const String recommendations = "$baseUrlsGin/api/recommendations";
  static const String recommendationById =
      "$baseUrlsGin/api/recommendations/:id";
  static const String recommendationFeedback =
      "$baseUrlsGin/api/recommendations/:id/feedback";

  // Notifications routes
  static const String notifications = "$baseUrlsGin/api/notifications";
  // Server-Sent Events (SSE) endpoint for streaming notifications in real-time
  static const String notificationsStream =
      "$baseUrlsGin/api/notifications/stream";
  static const String markNotificationAsRead =
      "$baseUrlsGin/api/notifications/:id/read";
  static const String markAllNotificationsAsRead =
      "$baseUrlsGin/api/notifications/read-all";
  static const String notificationById = "$baseUrlsGin/api/notifications/:id";

  // `analytics` a été retirée : plus personne ne la lisait. Les deux écrans qui
  // s'en servaient interrogeaient `GET /api/analytics/reader/:livre_id`, une
  // route dont la réponse mélangeait les chiffres de tous les lecteurs (voir
  // readerStatsService.dart et accueil_lecteur_page.dart) ; ils ont été
  // débranchés, et la constante n'avait plus d'objet.

  // Gamification & Badges routes
  static const String gamificationBadges =
      "$baseUrlsGin/api/gamification/badges";
  static const String gamificationGoals =
      "$baseUrlsGin/api/gamification/objectifs";
  static const String updateGoal =
      "$baseUrlsGin/api/gamification/objectifs/:id";

  // Community routes
  static const String communityEvents = "$baseUrlsGin/api/community/events";

  // Author routes
  //
  // `recentBooksByAuthor` a été retirée avec la carte qui devait la servir :
  // le widget « Livres récents » de l'accueil auteur n'était instancié par
  // aucun écran, et le tableau de bord tient déjà cette liste par
  // `booksByAuthor` (voir TopLivresSection).

  /// L'annuaire des auteurs, pagine.
  ///
  /// L'ecran « Tous les auteurs » les deduisait des livres qu'il chargeait :
  /// le decompte affiche ne comptait que les livres recus, et la liste ne
  /// pouvait pas etre paginee puisqu'elle derivait d'une autre.
  static const String auteurs = "$baseUrlsGin/api/authors";
  static const String authorRevenue =
      "$baseUrlsGin/api/authors/:authorId/revenue";
  static const String authorStats = "$baseUrlsGin/api/authors/:authorId/stats";

  // Review routes
  static const String reviews = "$baseUrlsGin/api/reviews";
  static const String reviewsByBook = "$baseUrlsGin/api/reviews/book/:livre_id";
  static const String reviewsByUser = "$baseUrlsGin/api/reviews/user";
  static const String reviewById = "$baseUrlsGin/api/reviews/:id";

  // Discussion routes
  static const String discussions = "$baseUrlsGin/api/discussions";
  static const String discussionById = "$baseUrlsGin/api/discussions/:id";
  static const String discussionsGlobal = "$baseUrlsGin/api/discussions/global";
  static const String discussionsByAuthor =
      "$baseUrlsGin/api/discussions/author/:auteur_id";
  static const String discussionsByBook =
      "$baseUrlsGin/api/discussions/book/:livre_id";

  // Evenements routes
  static const String evenements = "$baseUrlsGin/api/evenements";
  static const String evenementsGlobal = "$baseUrlsGin/api/evenements/global";
  static const String evenementsByAuthor =
      "$baseUrlsGin/api/evenements/author/:auteur_id";
  static const String evenementById = "$baseUrlsGin/api/evenements/:id";

  // Message routes
  static const String messages = "$baseUrlsGin/api/messages";
  static const String messagesByDiscussion =
      "$baseUrlsGin/api/messages/discussion/:discussion_id";
  static const String messageById = "$baseUrlsGin/api/messages/:id";

  // Messagerie privée
  //
  // Le tête-à-tête, distinct du forum : `messages` ci-dessus vit dans un salon
  // public, ces routes-ci dans une conversation à deux. Elles sont sur le
  // backend métier (8084) comme le reste, et non sur l'authentification.
  static const String dmConversations = "$baseUrlsGin/api/dm/conversations";

  /// Ouvre — ou retrouve — la conversation avec quelqu'un. Le serveur la crée
  /// si elle n'existe pas : le client n'a donc jamais d'identifiant à inventer.
  static const String dmConversationAvecUtilisateur =
      "$baseUrlsGin/api/dm/conversations/user/:user_id";

  /// Lire un fil marque au passage comme lus les messages reçus : c'est la
  /// même requête, il n'y a rien d'autre à appeler pour éteindre la pastille.
  static const String dmMessagesDeConversation =
      "$baseUrlsGin/api/dm/conversations/:id/messages";
  static const String dmMessages = "$baseUrlsGin/api/dm/messages";

  // Category routes
  static const String categories = "$baseUrlsGin/api/categories";
  static const String categorieById = "$baseUrlsGin/api/categories/:id";

  // Citation routes
  static const String citationsDaily = "$baseUrlsGin/api/citations/daily";

  static String? sanitizeImageUrl(String? url, {bool useGin = false}) {
    if (url == null || url.isEmpty) return null;

    // If it's a Supabase URL or Base64 data, keep it as is
    //
    // Ce test RESTE alors que l'application ne parle plus à Supabase : les
    // photos et couvertures déjà enregistrées portent des adresses
    // supabase.co, et elles doivent continuer de s'afficher. C'est une simple
    // comparaison de chaîne, elle ne dépend d'aucun paquet.
    if (url.contains('supabase.co') || url.startsWith('data:image')) return url;

    final targetBaseUrl = useGin ? baseUrlsGin : baseUrl;

    String sanitized = url;
    if (url.startsWith('http')) {
      // It's already absolute. We check if it's pointing to localhost/IP and swap for current base.
      final List<String> oldBases = [
        '192.168.1.29',
        '192.168.1.14',
        '192.168.252.193',
        '192.168.252.224',
        'localhost',
        '127.0.0.1',
      ];
      for (final oldBase in oldBases) {
        if (url.contains(oldBase)) {
          try {
            final uri = Uri.parse(url);
            final path = uri.path + (uri.hasQuery ? '?${uri.query}' : '');
            sanitized = '$targetBaseUrl$path';
            break;
          } catch (_) {}
        }
      }
    } else if (useGin) {
      // Un chemin relatif ne se devine pas.
      //
      // On construisait ici une URL vers un seau nomme « books ». Ce seau
      // n'existe pas : les couvertures vivent dans « book_covers » et
      // « covers ». Chaque chemin relatif produisait donc une adresse en
      // « Bucket not found », une requete reseau inutile et une exception dans
      // la console — pour un fichier qu'on n'aurait de toute facon pas trouve.
      //
      // Le client ne peut pas savoir ou le serveur a range un fichier. Ce
      // n'est pas a lui de l'inventer : sans URL exploitable, il n'y a pas
      // d'image, et l'ecran affiche son repli sans rien tenter.
      return null;
    } else {
      final separator = url.startsWith('/') ? '' : '/';
      sanitized = '$targetBaseUrl$separator$url';
    }

    return sanitized;
  }
}
