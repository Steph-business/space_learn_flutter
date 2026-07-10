/// api_routes.dart
class ApiRoutes {
  // Change following IP to your machine's current IP
  static const String host = "192.168.1.21";
  static const String hosts = "192.168.1.21";

  // Backends fusionnés : l'authentification et les livres sont désormais servis
  // par le MÊME serveur Go (port 8082). Les chemins /auth/* et /utilisateurs/*
  // restent identiques, seule l'adresse de base change.
  static const String baseUrl = "http://$host:8083";

  // Base URL for the combined Go server on port 8082
  static const String baseUrlsGin = "http://$host:8082";

  // Auth routes
  static const String profils = "$baseUrl/auth/profils";
  static const String register = "$baseUrl/auth/register";
  static const String login = "$baseUrl/auth/login";
  static const String logout = "$baseUrl/auth/logout";
  static const String sendOtp = "$baseUrl/auth/send-otp";
  static const String verifyOtp = "$baseUrl/auth/verify-otp";
  static const String verifyRegistration = "$baseUrl/auth/verification";
  static const String forgotPassword = "$baseUrl/auth/forgot-password";
  static const String resetPassword = "$baseUrl/auth/reset-password";

  // User routes
  static const String getUser = "$baseUrl/utilisateurs/me";
  static const String updateUser = "$baseUrl/utilisateurs/update";
  static const String selectProfile = "$baseUrl/utilisateurs/me/profil";

  // Book routes
  static const String books = "$baseUrlsGin/api/books";
  static const String bookById = "$baseUrlsGin/api/books/:id";
  static const String booksByAuthor =
      "$baseUrlsGin/api/books/author/:auteur_id";
  static const String shareBook = "$baseUrlsGin/api/books/:id/share";

  // Payment routes
  static const String payments = "$baseUrlsGin/api/payments";
  static const String paymentById = "$baseUrlsGin/api/payments/:id";
  static const String momoStatus =
      "$baseUrlsGin/api/payments/momo/status/:referenceId";
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

  // Book Statistics routes
  static const String bookStats = "$baseUrlsGin/api/book-stats";
  static const String bookStatsByBook = "$baseUrlsGin/api/book-stats/:livre_id";
  static const String updateBookStats = "$baseUrlsGin/api/book-stats/:id";

  // Detailed Statistics routes
  static const String detailedStats = "$baseUrlsGin/api/detailed-stats";
  static const String detailedStatsByBook =
      "$baseUrlsGin/api/detailed-stats/:livre_id";
  static const String updateDetailedStats =
      "$baseUrlsGin/api/detailed-stats/:livre_id";

  // Reading settings routes
  static const String readingSettings =
      "$baseUrlsGin/api/user/settings/reading";

  // Reading activity routes
  static const String readingActivity = "$baseUrlsGin/api/reading/activity";
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

  // Analytics route
  static const String analytics = "$baseUrlsGin/api/analytics";

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
  static const String recentBooksByAuthor =
      "$baseUrlsGin/api/authors/:authorId/books/recent";
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

  // Category routes
  static const String categories = "$baseUrlsGin/api/categories";
  static const String categorieById = "$baseUrlsGin/api/categories/:id";

  static String? sanitizeImageUrl(String? url, {bool useGin = false}) {
    if (url == null || url.isEmpty) return null;

    // If it's a Supabase URL, keep it as is
    if (url.contains('supabase.co')) return url;

    final targetBaseUrl = useGin ? baseUrlsGin : baseUrl;

    String sanitized = url;
    if (url.startsWith('http')) {
      // It's already absolute. We check if it's pointing to localhost/IP and swap for current base.
      final List<String> oldBases = [
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
    } else {
      // Relative path - prepend target base URL
      final separator = url.startsWith('/') ? '' : '/';
      sanitized = '$targetBaseUrl$separator$url';
    }

    return sanitized;
  }
}
