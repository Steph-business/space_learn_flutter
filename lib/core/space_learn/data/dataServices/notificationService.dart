import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../services/api_client.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:space_learn_flutter/main.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/notificationModel.dart';
import 'package:space_learn_flutter/core/themes/layout/nav_bar_lecteur.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/ecrivain/livres_page.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/lecteur/bibliotheque_page.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/lecteur/communaute/forum_discussion_page.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/lecteur/communaute/forum_messages_page.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/discussionService.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/ecrivain/communaute_page.dart'
    as ecrivainTeams;
import 'package:space_learn_flutter/core/utils/api_routes.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/bookService.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/details/reading_page.dart';
import 'package:space_learn_flutter/core/utils/token_storage.dart';
import 'package:space_learn_flutter/core/utils/message_erreur.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/evenementService.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/communaute/evenement_apercu.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/details/book_detail_page.dart';

class NotificationService {
  final http.Client client;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  NotificationService({http.Client? client})
    : client = client ?? ApiClient.instance;

  static void initializeLocalNotifications() {
    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );

    _localNotifications.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null) {
          try {
            final Map<String, dynamic> data = jsonDecode(response.payload!);
            final notif = NotificationModel.fromJson(data);
            handleNotificationTap(notif);
          } catch (e) {}
        }
      },
    );
  }

  /// Ouvre l'ecran que la notification designe.
  ///
  /// Rend `false` quand aucune destination n'a pu etre ouverte. L'appelant s'en
  /// sert pour ne PAS marquer la notification comme lue : une notification
  /// qu'on n'a pas pu suivre doit rester la, non lue, pour qu'on puisse
  /// reessayer — plutot que de disparaitre en emportant ce qu'on n'a jamais vu.
  static bool handleNotificationTap(NotificationModel notif) {
    final context = navigatorKey.currentContext;
    if (context == null) {
      return false;
    }

    final type = notif.type.toLowerCase();

    // Helper to clear nav stack until root shell
    void popToRoot() {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }

    // Role check (normalization)
    final isLecteur = (notif.role == 'lecteur' || notif.role == null);

    if (type.contains('message') ||
        type.contains('reponse') ||
        type.contains('communaute')) {
      // On ouvre le salon dont il est question, pas « un » salon.
      //
      // Le serveur joint l'identifiant de la discussion a la notification
      // depuis toujours ; le routage l'ignorait et poussait le salon global,
      // meme quand le message venait du club d'un livre. Et « communaute » —
      // le type reellement emis pour « Nouveau message dans votre salon » —
      // n'etait reconnu par aucune branche : il tombait dans le cas par
      // defaut, qui renvoie a la bibliotheque.
      _ouvrirLeSalon(context, notif.referenceId, popToRoot);
    } else if (type.contains('annonce') || type.contains('evenement')) {
      // On ouvre LA publication, pas « la communaute ».
      //
      // La notification dit « Nouvelle annonce de l'auteur : … » et deposait le
      // lecteur sur l'onglet Communaute, a lui de retrouver de quoi on lui
      // parlait — alors que son identifiant voyage dans la notification.
      _ouvrirLaPublication(context, notif.referenceId, isLecteur, popToRoot);
    } else if (type.contains('nouveau_livre')) {
      // « Nouveau livre publie » doit montrer LE livre.
      //
      // Le lecteur ne le possede pas encore : l'envoyer dans sa bibliotheque
      // lui fait chercher un ouvrage qui n'y est pas. C'est la fiche qu'il
      // faut ouvrir — celle ou l'on peut justement l'acquerir.
      _ouvrirLaFicheDuLivre(context, notif.referenceId, isLecteur, popToRoot);
    } else if (type.contains('rappel_lecture')) {
      // « Vous n'avez pas lu X depuis plus de 24h » doit rouvrir X.
      //
      // Le rappel menait a la bibliotheque : au lecteur de retrouver lui-meme
      // l'ouvrage dont on venait de lui parler, alors que la notification en
      // porte l'identifiant. C'est un geste de plus a chaque fois, et le
      // rappel perd ce qui le rendait utile.
      _ouvrirLeLivre(context, notif.referenceId, popToRoot);
    } else if (type.contains('paiement') ||
        type.contains('achat') ||
        type.contains('vente') ||
        type.contains('livre') ||
        type.contains('chapitre')) {
      if (isLecteur) {
        popToRoot();
        MainNavBar.mainNavBarKey.currentState?.navigateToBibliotheque();
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                LivresPage(onBackPressed: () => Navigator.of(context).pop()),
          ),
        );
      }
    } else {
      // Default fallback
      if (isLecteur) {
        popToRoot();
        MainNavBar.mainNavBarKey.currentState?.navigateToBibliotheque();
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const BibliothequePage()),
        );
      }
    }
    return true;
  }

  /// Ouvre la fiche d'un livre qu'on ne possede pas encore.
  static Future<void> _ouvrirLaFicheDuLivre(
    BuildContext context,
    String? livreId,
    bool isLecteur,
    VoidCallback popToRoot,
  ) async {
    if (livreId == null || livreId.trim().isEmpty) {
      popToRoot();
      MainNavBar.mainNavBarKey.currentState?.navigateToBibliotheque();
      return;
    }

    try {
      final token = await TokenStorage.getToken();
      final livre = await BookService().getBookById(livreId, authToken: token);
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BookDetailPage(book: livre, isOwned: false),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      popToRoot();
      MainNavBar.mainNavBarKey.currentState?.navigateToBibliotheque();
    }
  }

  /// Ouvre l'annonce ou l'evenement designe par la notification.
  ///
  /// Sans identifiant exploitable, on retombe sur la communaute plutot que de
  /// ne rien faire — mais c'est le repli, plus la regle.
  static Future<void> _ouvrirLaPublication(
    BuildContext context,
    String? evenementId,
    bool isLecteur,
    VoidCallback popToRoot,
  ) async {
    Future<void> repli() async {
      if (!context.mounted) return;
      if (isLecteur) {
        popToRoot();
        MainNavBar.mainNavBarKey.currentState?.navigateToCommunaute();
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ecrivainTeams.TeamsPage(),
          ),
        );
      }
    }

    if (evenementId == null || evenementId.trim().isEmpty) return repli();

    try {
      final token = await TokenStorage.getToken();
      if (token == null) return repli();
      final publication = await EvenementService().getEvenementById(
        evenementId,
        token,
      );
      if (!context.mounted) return;
      await afficherEvenement(context, publication);
    } catch (_) {
      // La publication a pu etre retiree depuis l'envoi de la notification.
      await repli();
    }
  }

  /// Ouvre le livre designe par la notification, la ou la lecture s'etait
  /// arretee.
  ///
  /// Sans identifiant exploitable, on retombe sur la bibliotheque plutot que
  /// de ne rien faire.
  static Future<void> _ouvrirLeLivre(
    BuildContext context,
    String? livreId,
    VoidCallback popToRoot,
  ) async {
    if (livreId == null || livreId.trim().isEmpty) {
      popToRoot();
      MainNavBar.mainNavBarKey.currentState?.navigateToBibliotheque();
      return;
    }

    try {
      final token = await TokenStorage.getToken();
      final livre = await BookService().getBookById(livreId, authToken: token);
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ReadingPage(book: livre.toJson()),
        ),
      );
    } catch (_) {
      // Le livre a pu etre retire du catalogue depuis l'envoi du rappel.
      if (!context.mounted) return;
      popToRoot();
      MainNavBar.mainNavBarKey.currentState?.navigateToBibliotheque();
    }
  }

  /// Ouvre la discussion designee par la notification.
  ///
  /// Faute d'identifiant exploitable — vieille notification, reference
  /// manquante — on retombe sur le salon commun plutot que de ne rien faire.
  static Future<void> _ouvrirLeSalon(
    BuildContext context,
    String? discussionId,
    VoidCallback popToRoot,
  ) async {
    if (discussionId == null || discussionId.trim().isEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ForumDiscussionPage()),
      );
      return;
    }

    try {
      final discussion = await DiscussionService().getDiscussionById(
        discussionId,
      );
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ForumMessagesPage(discussion: discussion),
        ),
      );
    } catch (_) {
      // La discussion a pu etre supprimee entre-temps.
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ForumDiscussionPage()),
      );
    }
  }

  static Future<void> showLocalNotification({
    required String id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'high_importance_channel',
        'Notifications Importantes',
        channelDescription: 'Canal pour les notifications de l\'application',
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );

    await _localNotifications.show(
      id: id.hashCode,
      title: title.toUpperCase(),
      body: body,
      notificationDetails: notificationDetails,
      payload: payload,
    );
  }

  Future<dynamic> getNotifications(
    String authToken, {
    bool onlyUnread = false,
    bool groupByRole = false,
  }) async {
    String url = ApiRoutes.notifications;
    List<String> queryParams = [];
    if (onlyUnread) queryParams.add("lu=false");
    if (groupByRole) queryParams.add("group_by_role=true");

    if (queryParams.isNotEmpty) {
      url += "?${queryParams.join("&")}";
    }

    final response = await client.get(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $authToken'},
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      final rawData = data['data'] ?? data;

      if (groupByRole && rawData is Map<String, dynamic>) {
        final Map<String, List<NotificationModel>> grouped = {};
        rawData.forEach((key, value) {
          if (value is List) {
            grouped[key] = value
                .map((json) => NotificationModel.fromJson(json, role: key))
                .toList();
          }
        });
        return grouped;
      } else if (rawData is List) {
        return rawData.map((json) => NotificationModel.fromJson(json)).toList();
      }
      return <NotificationModel>[];
    } else {
      throw Exception(
        messageDeLaReponse(
          response,
          repli: "Impossible de charger vos notifications.",
        ),
      );
    }
  }

  Future<NotificationModel> createNotification(
    Map<String, dynamic> notificationData,
    String authToken,
  ) async {
    final response = await client.post(
      Uri.parse(ApiRoutes.notifications),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $authToken',
      },
      body: jsonEncode(notificationData),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      return NotificationModel.fromJson(data['data'] ?? data);
    } else {
      throw Exception(
        messageDeLaReponse(
          response,
          repli: "Cette notification n'a pas pu être créée.",
        ),
      );
    }
  }

  Future<void> markAsRead(String id, String authToken) async {
    final url = ApiRoutes.markNotificationAsRead.replaceFirst(':id', id);
    final response = await client.put(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $authToken'},
    );

    if (response.statusCode != 200) {
      throw Exception(
        messageDeLaReponse(
          response,
          repli: "Cette notification n'a pas pu être marquée comme lue.",
        ),
      );
    }
  }

  Future<void> markAllAsRead(String authToken) async {
    final response = await client.put(
      Uri.parse(ApiRoutes.markAllNotificationsAsRead),
      headers: {'Authorization': 'Bearer $authToken'},
    );

    if (response.statusCode != 200) {
      throw Exception(
        messageDeLaReponse(
          response,
          repli: "Vos notifications n'ont pas pu être marquées comme lues.",
        ),
      );
    }
  }

  Future<void> deleteNotification(String id, String authToken) async {
    final url = ApiRoutes.notificationById.replaceFirst(':id', id);
    final response = await client.delete(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $authToken'},
    );

    if (response.statusCode != 200) {
      throw Exception(
        messageDeLaReponse(
          response,
          repli: "Cette notification n'a pas pu être supprimée.",
        ),
      );
    }
  }

  /// Le flux des notifications, en direct.
  ///
  /// [authToken] n'est plus utilisé pour ouvrir la connexion : il ne sert qu'à
  /// ne pas casser les appelants existants. Le jeton est relu à CHAQUE
  /// tentative, et c'est tout l'objet du correctif.
  ///
  /// Il était capturé une fois, à l'ouverture, et la boucle de reconnexion
  /// réutilisait indéfiniment le même. Tant qu'un jeton valait vingt-quatre
  /// heures, cela ne se voyait pas : l'application était relancée avant. Depuis
  /// qu'il ne vaut qu'une heure, les notifications s'arrêtaient au bout d'une
  /// heure — définitivement, avec une reconnexion toutes les trente secondes
  /// présentant chaque fois le même jeton mort. Silence côté écran, et une
  /// requête inutile toutes les demi-minutes sur des forfaits data comptés.
  Stream<NotificationModel> streamNotifications(String authToken) {
    final controller = StreamController<NotificationModel>.broadcast();

    bool cancelled = false;
    controller.onCancel = () {
      cancelled = true;
    };

    () async {
      int attempt = 0;

      while (!cancelled) {
        HttpClient? httpClient;
        HttpClientRequest? request;
        try {
          final jeton = await TokenStorage.getToken();
          if (jeton == null || jeton.isEmpty) {
            // Plus de session : inutile d'insister vite.
            await Future.delayed(const Duration(seconds: 30));
            continue;
          }

          final uri = Uri.parse(ApiRoutes.notificationsStream);
          httpClient = HttpClient();
          request = await httpClient.getUrl(uri);
          request.headers.set('Authorization', 'Bearer $jeton');
          request.headers.set('Accept', 'text/event-stream');
          request.headers.set('Cache-Control', 'no-cache');

          final response = await request.close();
          if (response.statusCode != 200) {
            // Un 401 se répare, et lui seul : on demande un jeton neuf avant
            // de réessayer. L'intercepteur d'ApiClient ne peut rien ici — une
            // connexion longue n'est pas une requête qu'on rejoue.
            if (response.statusCode == 401) {
              final verdict = await ApiClient.instance.renouvelerSession();
              // Session réellement finie : on cesse d'insister. La boucle
              // rouvrait sinon une connexion toutes les trente secondes, pour
              // toujours, avec un jeton dont on savait qu'il était mort — sur
              // des forfaits data comptés.
              if (verdict == Renouvellement.refuse) break;
            }
            attempt = math.min(attempt + 1, 6);
            final wait = math.min(30, 1 << attempt);
            await Future.delayed(Duration(seconds: wait));
            continue;
          }

          attempt = 0;

          final utf8Stream = response.transform(utf8.decoder);
          final lineStream = utf8Stream.transform(const LineSplitter());

          StringBuffer buffer = StringBuffer();

          await for (final rawLine in lineStream) {
            if (cancelled) break;
            final line = rawLine.trim();
            if (line.isEmpty) {
              if (buffer.isNotEmpty) {
                final dataStr = buffer.toString();
                try {
                  final decoded = jsonDecode(dataStr);
                  Map<String, dynamic>? payload;

                  if (decoded is Map<String, dynamic>) {
                    if (decoded.containsKey('data')) {
                      final d = decoded['data'];
                      if (d is Map) {
                        payload = Map<String, dynamic>.from(d);
                      } else if (d is String) {
                        try {
                          final inner = jsonDecode(d);
                          if (inner is Map) {
                            payload = Map<String, dynamic>.from(inner);
                          }
                        } catch (_) {}
                      }
                    } else {
                      payload = decoded;
                    }
                  }

                  if (payload != null) {
                    final model = NotificationModel.fromJson(payload);
                    if (!controller.isClosed) controller.add(model);
                  }
                } catch (e) {}
                buffer.clear();
              }
            } else if (line.startsWith('data:')) {
              buffer.write(line.substring(5).trim());
            } else if (!line.startsWith(':') && !line.startsWith('event:')) {
              buffer.write(line);
            }
          }
        } catch (e) {
          if (e is! SocketException && e is! HttpException) {}
        } finally {
          try {
            request?.abort();
          } catch (_) {}
          try {
            httpClient?.close(force: true);
          } catch (_) {}
        }

        if (!cancelled) {
          attempt = math.min(attempt + 1, 6);
          final wait = math.min(10, 1 << attempt);
          await Future.delayed(Duration(seconds: wait));
        }
      }

      if (!controller.isClosed) await controller.close();
    }();

    return controller.stream;
  }
}
