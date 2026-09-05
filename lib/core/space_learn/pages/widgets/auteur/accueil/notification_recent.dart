import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:space_learn_flutter/core/themes/app_dimensions.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/notificationService.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/notification_provider.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/notificationModel.dart';
import 'package:space_learn_flutter/core/utils/token_storage.dart';
import 'package:space_learn_flutter/core/utils/app_notifications.dart';

/// Le type, en francais.
///
/// Il s'affichait brut : « RAPPEL_LECTURE », « COMMUNAUTE », « VENTE ». Ce
/// sont des valeurs de base de donnees, pas des mots qu'on lit.
String libelleTypeNotification(String type) {
  switch (type.toLowerCase().trim()) {
    case 'rappel_lecture':
      return 'REPRENDRE LA LECTURE';
    case 'communaute':
      return 'COMMUNAUTÉ';
    case 'avis':
      return 'NOUVEL AVIS';
    case 'nouvel_abonne':
      return 'NOUVEL ABONNÉ';
    case 'vente':
      return 'VENTE';
    case 'achat':
      return 'ACHAT';
    case 'paiement':
      return 'PAIEMENT';
    // Sans ce cas, « paiement_echoue » tombait dans le repli et s'affichait
    // « PAIEMENT ECHOUE », sans accents.
    case 'paiement_echoue':
      return 'PAIEMENT ÉCHOUÉ';
    case 'annonce':
      return 'ANNONCE';
    case 'evenement':
      return 'ÉVÉNEMENT';
    case 'message':
    case 'reponse':
      return 'MESSAGE';
    default:
      // Un type inconnu reste lisible : les tirets bas s'effacent.
      return type.replaceAll('_', ' ').toUpperCase();
  }
}

IconData iconeDuTypeDeNotification(String type) {
  final t = type.toLowerCase();
  // L'echec se teste AVANT le cas general : « paiement_echoue » contient
  // « paiement », et l'ordre des conditions decide donc de tout.
  if (notificationEstUnEchec(t)) {
    return Iconsax.close_circle;
  }
  if (t.contains('payment') ||
      t.contains('paiement') ||
      t.contains('vente') ||
      t.contains('achat')) {
    return Iconsax.wallet_3;
  }
  if (t.contains('review') || t.contains('avis')) {
    return Iconsax.star;
  }
  if (t.contains('message') || t.contains('reponse')) {
    return Iconsax.message_2;
  }
  if (t.contains('chapitre') || t.contains('livre') || t.contains('lecture')) {
    return Iconsax.book;
  }
  if (t.contains('abonné') || t.contains('follow')) {
    return Iconsax.user_add;
  }
  return Iconsax.notification;
}

/// Un type qui annonce que quelque chose n'a PAS abouti.
///
/// Le test vit a part parce que deux fonctions en dependent — la couleur et
/// l'icone — et qu'elles doivent dire la meme chose. Une pastille verte au-
/// dessus d'une icone d'echec serait pire que le defaut d'origine.
bool notificationEstUnEchec(String t) =>
    t.contains('echoue') ||
    t.contains('echec') ||
    t.contains('annule') ||
    t.contains('refuse') ||
    t.contains('failed');

Color couleurDuTypeDeNotification(String type) {
  final t = type.toLowerCase();
  // « paiement_echoue » CONTIENT « paiement » : sans ce test place en
  // premier, l'echec heritait du vert du succes. Le lecteur voyait donc
  // « votre commande a ete annulee » en vert, la meme couleur que
  // « paiement valide » juste en dessous — la couleur disait le contraire
  // du texte, et c'est la couleur qu'on lit en premier.
  if (notificationEstUnEchec(t)) {
    return AppColors.error;
  }
  if (t.contains('payment') ||
      t.contains('paiement') ||
      t.contains('vente') ||
      t.contains('achat')) {
    return AppColors.success;
  }
  if (t.contains('review') || t.contains('avis')) {
    return AppColors.warning;
  }
  if (t.contains('message') || t.contains('reponse')) {
    return AppColors.secondary;
  }
  if (t.contains('chapitre') || t.contains('livre')) {
    return AppColors.violet;
  }
  if (t.contains('lecture')) {
    return AppColors.primary;
  }
  if (t.contains('abonné') || t.contains('follow')) {
    return AppColors.pinkVivid;
  }
  return AppColors.primary;
}

class RecentNotificationsPage extends StatefulWidget {
  final VoidCallback? onTapOpenNotifications;
  final List<NotificationModel>? customNotifications;
  final String? title;

  /// Ce qu'on affiche quand il n'y a rien.
  ///
  /// « Aucune notification » est faux des qu'un filtre est actif : la liste
  /// peut etre vide parce que tout a ete lu, ce qui est une bonne nouvelle et
  /// non une absence.
  final String? messageVide;

  /// Icône affichée dans l'état vide (optionnel, sinon icone cloche par défaut).
  final IconData? emptyIcon;

  /// Animation de fondu pour l'état vide (optionnel).
  final Animation<double>? emptyFadeAnimation;

  /// Animation de glissement pour l'état vide (optionnel).
  final Animation<Offset>? emptySlideAnimation;

  const RecentNotificationsPage({
    super.key,
    this.onTapOpenNotifications,
    this.customNotifications,
    this.title,
    this.messageVide,
    this.emptyIcon,
    this.emptyFadeAnimation,
    this.emptySlideAnimation,
  });

  @override
  State<RecentNotificationsPage> createState() =>
      _RecentNotificationsPageState();
}

class _RecentNotificationsPageState extends State<RecentNotificationsPage> {
  String _formatTimeAgo(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes}m';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
    return 'Il y a ${diff.inDays}j';
  }

  /// Retire la notification, et ne laisse la ligne partir QUE si le serveur
  /// a accepté.
  ///
  /// Elle était branchée sur `onDismissed`, c'est-à-dire APRÈS que la ligne
  /// ait quitté l'écran : un refus du serveur — ou un jeton absent — la
  /// remettait dans la liste alors que son `Dismissible` venait d'être
  /// dissous. Flutter refuse ce cas (« A dismissed Dismissible widget is still
  /// part of the tree ») : écran rouge en débogage, et en production une ligne
  /// de hauteur nulle — la notification existait encore, mais plus personne ne
  /// pouvait la voir ni la rouvrir.
  ///
  /// Branchée sur `confirmDismiss`, la ligne revient à sa place d'elle-même
  /// quand la réponse est non. Aucun succès sans confirmation du serveur.
  ///
  /// Le contexte employé est celui de CET état, pas celui de la ligne : le
  /// provider retire la notification de la liste avant d'appeler le serveur,
  /// ce qui démonte l'élément de la ligne — dont le `context.mounted` passait
  /// alors à faux, et le message d'échec ne s'affichait jamais, précisément
  /// dans le seul cas où il fallait le voir.
  Future<bool> _supprimer(NotificationModel notif) async {
    final provider = context.read<NotificationProvider>();
    final token = await TokenStorage.getToken();
    if (!mounted) return false;
    if (token == null) {
      // Session expirée : le dire, plutôt que d'avaler le geste en silence et
      // de laisser croire que le retrait a échoué tout seul.
      AppNotifications.showSnackBar(
        context,
        message: "Votre session a expiré. Reconnectez-vous pour continuer.",
        isError: true,
      );
      return false;
    }

    final retire = await provider.supprimer(notif.id, token);
    if (!retire && mounted) {
      // Elle est revenue a sa place : il faut le dire, sinon on croit l'avoir
      // ecartee et on la retrouve au prochain affichage sans comprendre.
      AppNotifications.showSnackBar(
        context,
        message: "La notification n'a pas pu être retirée.",
        isError: true,
      );
    }
    return retire;
  }

  /// Ouvrir la notification, PUIS la marquer lue.
  ///
  /// L'ordre était inverse, et il se voyait : le filtre par défaut de l'écran
  /// est « non lues ». Marquer d'abord faisait sortir la notification de la
  /// liste à l'instant du doigt — elle disparaissait sous les yeux — et la
  /// navigation ne partait qu'ensuite. Quand elle échouait, il ne restait rien
  /// du tout : ni la notification, ni l'écran promis.
  ///
  /// Naviguer d'abord garde la ligne en place jusqu'à ce que l'écran suivant
  /// soit poussé. Et si la navigation ne mène nulle part, la notification
  /// reste là, non lue : on peut réessayer, au lieu de perdre la trace de ce
  /// qu'on n'a jamais vu.
  ///
  /// Même remarque que pour [_supprimer] sur le contexte : marquer lue fait
  /// sortir la ligne de la liste quand le filtre « non lues » est actif, et
  /// le contexte de la ligne ne serait plus monté pour porter le message.
  Future<void> _handleNotificationTap(NotificationModel notif) async {
    final notifProvider = context.read<NotificationProvider>();

    final ouverte = NotificationService.handleNotificationTap(notif);
    if (!ouverte) return;

    final token = await TokenStorage.getToken();
    if (token == null || notif.lu) return;

    // On ATTEND le verdict du serveur.
    //
    // L'appel partait sans être attendu et son résultat était jeté : le
    // provider rend pourtant `false` quand le PUT a échoué. La notification
    // s'affichait donc lue — pastille éteinte, texte grisé — alors que le
    // serveur la tenait toujours pour non lue ; au rechargement suivant elle
    // redevenait non lue sans que rien ne l'explique, et le compteur de
    // l'accueil sautait d'un cran dans l'autre sens. Aucun succès ne
    // s'annonce sans réponse du serveur : on le dit, comme le fait
    // `_supprimer` juste au-dessus.
    final marquee = await notifProvider.markAsRead(notif.id, token);
    if (!marquee && mounted) {
      AppNotifications.showSnackBar(
        context,
        message: "La notification n'a pas pu être marquée comme lue.",
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    AppColors.suivreLeTheme(context);
    final notificationProvider = context.watch<NotificationProvider>();
    final notifications =
        widget.customNotifications ?? notificationProvider.notifications;
    final loading = notificationProvider.isLoading;

    if (loading && notifications.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryLight),
          ),
        ),
      );
    }

    if (notifications.isEmpty) {
      Widget emptyContent = Padding(
        padding: const EdgeInsets.symmetric(vertical: 80),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: Icon(
                widget.emptyIcon ?? Iconsax.notification_bing,
                size: 40,
                color: AppColors.textPrimary.withOpacity(0.25),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.messageVide ?? 'Aucune notification.',
              style: GoogleFonts.poppins(
                color: AppColors.textPrimary.withOpacity(0.5),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );

      if (widget.emptyFadeAnimation != null) {
        emptyContent = FadeTransition(
          opacity: widget.emptyFadeAnimation!,
          child: widget.emptySlideAnimation != null
              ? SlideTransition(
                  position: widget.emptySlideAnimation!,
                  child: emptyContent,
                )
              : emptyContent,
        );
      }

      return Center(child: emptyContent);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.title != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 20),
            child: Text(
              widget.title!,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary.withOpacity(0.9),
                letterSpacing: 0.5,
              ),
            ),
          ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: notifications.length,
          itemBuilder: (context, index) {
            final notif = notifications[index];
            // Ecarter sans ouvrir.
            //
            // La seule facon de se debarrasser d'une notification etait de la
            // lire : pour dix rappels sur le meme livre, dix ouvertures. Le
            // glissement lateral est le geste attendu partout, et la route de
            // suppression existait deja cote serveur.
            return Dismissible(
              key: ValueKey(notif.id),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 24),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
                ),
                child: Icon(Iconsax.trash, color: AppColors.error, size: 20),
              ),
              // `confirmDismiss` et non `onDismissed` : la ligne ne quitte la
              // liste que si le serveur a dit oui. Voir [_supprimer].
              confirmDismiss: (_) => _supprimer(notif),
              child: _NotificationCardFromModel(
                model: notif,
                icon: iconeDuTypeDeNotification(notif.type),
                accentColor: couleurDuTypeDeNotification(notif.type),
                timeAgo: _formatTimeAgo(notif.creeLe),
                onTap: () => _handleNotificationTap(notif),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _NotificationCardFromModel extends StatelessWidget {
  final NotificationModel model;
  final IconData icon;
  final Color accentColor;
  final String timeAgo;
  final VoidCallback onTap;

  const _NotificationCardFromModel({
    required this.model,
    required this.icon,
    required this.accentColor,
    required this.timeAgo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    AppColors.suivreLeTheme(context);
    final isUnread = !model.lu;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
              border: Border.all(
                color: isUnread
                    ? accentColor.withOpacity(0.3)
                    : AppColors.border,
                width: 1,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: accentColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(
                                AppDimensions.radiusInner,
                              ),
                            ),
                            child: Icon(icon, color: accentColor, size: 20),
                          ),
                          if (isUnread)
                            Positioned(
                              top: 0,
                              right: 0,
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: accentColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.scaffoldBackground,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  libelleTypeNotification(model.type),
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: accentColor,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                                Text(
                                  timeAgo,
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    color: AppColors.textPrimary.withOpacity(
                                      0.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 4),
                            Text(
                              model.contenu,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                height: 1.3,
                                color: isUnread
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                                fontWeight: isUnread
                                    ? FontWeight.w500
                                    : FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(top: 12, left: 4),
                        child: Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.textHint,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
