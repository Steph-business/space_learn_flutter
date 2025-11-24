/// api_routes.dart
class ApiRoutes {
  // Base URL (dev ou prod)
  static const String baseUrl = "http://192.168.1.18:8083";

  // Auth routes
  static const String profils  =    "$baseUrl/auth/profils";
  static const String register =   "$baseUrl/auth/register";
  static const String login    =      "$baseUrl/auth/login";
  static const String logout   =     "$baseUrl/auth/logout";
  static const String sendOtp  =    "$baseUrl/auth/send-otp";
  static const String verifyOtp =  "$baseUrl/auth/verify-otp";
  static const String forgotPassword = "$baseUrl/auth/forgot-password";
  static const String resetPassword = "$baseUrl/auth/reset-password";

  // Exemple pour User (si tu as un contrôleur user)
  static const String getUser =    "$baseUrl/utilisateurs/me";
  static const String updateUser = "$baseUrl/utilisateurs/update";
  static const String selectProfile =
      "$baseUrl/utilisateurs/me/profil"; // Ajout de la route

  // Autres routes (cours, vidéos, etc.) peuvent être ajoutées ici

  // New base URL for Gin server on port 8082
  static const String baseUrlsGin = "http://192.168.1.18:8082";

  // Book routes
  static const String books = "$baseUrlsGin/api/books";
  static const String bookById = "$baseUrlsGin/api/books/:id";
  static const String booksByAuthor = "$baseUrlsGin/api/books/author/:auteur_id";

  // Chapter routes
  static const String createChapter = "$baseUrlsGin/api/chapters";
  static const String chaptersByBook = "$baseUrlsGin/api/chapters/book/:livre_id";
  static const String chapterById = "$baseUrlsGin/api/chapters/:id";

  // Payment routes
  static const String createPayment = "$baseUrlsGin/api/payments";
  static const String paymentsByUser = "$baseUrlsGin/api/payments";
  static const String paymentById = "$baseUrlsGin/api/payments/:id";

  // Library routes
  static const String addToLibrary = "$baseUrlsGin/api/library";
  static const String getLibrary = "$baseUrlsGin/api/library";
  static const String removeFromLibrary = "$baseUrlsGin/api/library/:livre_id";

  // Relations routes
  static const String followUser = "$baseUrlsGin/api/relations/follow/:suit_id";
  static const String unfollowUser = "$baseUrlsGin/api/relations/unfollow/:suit_id";
  static const String getFollowers = "$baseUrlsGin/api/relations/followers/:utilisateur_id";
  static const String getFollowing = "$baseUrlsGin/api/relations/following/:utilisateur_id";

  // Favorites routes
  static const String addFavorite = "$baseUrlsGin/api/favorites";
  static const String getFavorites = "$baseUrlsGin/api/favorites";
  static const String removeFavorite = "$baseUrlsGin/api/favorites/:livre_id";

  // Book Statistics routes
  static const String createBookStats = "$baseUrlsGin/api/book-stats";
  static const String bookStatsByBook = "$baseUrlsGin/api/book-stats/:livre_id";
  static const String updateBookStats = "$baseUrlsGin/api/book-stats/:id";

  // Detailed Statistics routes
  static const String createDetailedStats = "$baseUrlsGin/api/detailed-stats";
  static const String detailedStatsByBook = "$baseUrlsGin/api/detailed-stats/:livre_id";
  static const String updateDetailedStats = "$baseUrlsGin/api/detailed-stats/:livre_id";

  // Reading activity routes
  static const String logReadingActivity = "$baseUrlsGin/api/reading/activity";
  static const String getReadingActivities = "$baseUrlsGin/api/reading/activities";
  static const String updateReadingProgress = "$baseUrlsGin/api/reading/progress";
  static const String getReadingProgress = "$baseUrlsGin/api/reading/progress";

  // Recommendation routes
  static const String createRecommendation = "$baseUrlsGin/api/recommendations";
  static const String getRecommendations = "$baseUrlsGin/api/recommendations";
  static const String deleteRecommendation = "$baseUrlsGin/api/recommendations/:id";

  // Notification routes
  static const String getNotifications = "$baseUrlsGin/api/notifications";
  static const String markNotificationAsRead = "$baseUrlsGin/api/notifications/:id/read";
  static const String markAllNotificationsAsRead = "$baseUrlsGin/api/notifications/read-all";
  static const String deleteNotification = "$baseUrlsGin/api/notifications/:id";

  // Community events route
  static const String communityEvents = "$baseUrlsGin/api/community/events";

  // Author related routes
  static const String recentBooksByAuthor = "$baseUrlsGin/api/authors/:authorId/books/recent";
  static const String authorRevenue = "$baseUrlsGin/api/authors/:authorId/revenue";

  // Review routes
  static const String createReview = "$baseUrlsGin/api/reviews";
  static const String reviewsByBook = "$baseUrlsGin/api/reviews/book/:livre_id";
  static const String reviewsByUser = "$baseUrlsGin/api/reviews/user";
  static const String updateReview = "$baseUrlsGin/api/reviews/:id";
  static const String deleteReview = "$baseUrlsGin/api/reviews/:id";

  // Discussion routes
  static const String createDiscussion = "$baseUrlsGin/api/discussions";
  static const String discussionsByUser = "$baseUrlsGin/api/discussions";
  static const String discussionById = "$baseUrlsGin/api/discussions/:id";
  static const String updateDiscussion = "$baseUrlsGin/api/discussions/:id";
  static const String deleteDiscussion = "$baseUrlsGin/api/discussions/:id";

  // Message routes
  static const String createMessage = "$baseUrlsGin/api/messages";
  static const String messagesByDiscussion = "$baseUrlsGin/api/messages/discussion/:discussion_id";
  static const String updateMessage = "$baseUrlsGin/api/messages/:id";
  static const String deleteMessage = "$baseUrlsGin/api/messages/:id";
}
