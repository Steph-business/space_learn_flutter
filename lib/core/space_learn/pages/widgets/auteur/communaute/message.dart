import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';

import 'package:space_learn_flutter/core/services/session_service.dart';
import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/themes/app_dimensions.dart';
import 'package:space_learn_flutter/core/utils/app_notifications.dart';
import 'package:space_learn_flutter/core/utils/message_erreur.dart';
import 'package:space_learn_flutter/core/utils/profile_image_helper.dart';
import 'package:space_learn_flutter/core/utils/token_storage.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/dm_service.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/notification_provider.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/conversation_model.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/notificationModel.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/auth/login.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/conversation_page.dart';

/// La liste des conversations privées.
///
/// Cet écran était un état vide écrit en dur : il affichait « Aucun message »
/// sans jamais rien demander au serveur, et son geste de rafraîchissement
/// attendait une seconde avant de réafficher le même vide — de quoi croire
/// qu'on avait bien interrogé le serveur et qu'il n'y avait rien.
///
/// Le mensonge tenait à une distinction qui n'était pas faite : « le serveur a
/// répondu une liste vide » et « on n'a pas pu le joindre » se ressemblent à
/// l'écran, et ne veulent pas dire la même chose.
class Messages extends StatefulWidget {
  const Messages({super.key});

  @override
  State<Messages> createState() => _MessagesState();
}

class _MessagesState extends State<Messages> {
  final DmService _service = DmService();

  List<Conversation> _conversations = [];
  bool _chargement = true;
  String? _erreur;

  /// La panne vient-elle d'une session finie, ou d'un incident passager ?
  ///
  /// Les deux n'appellent pas le même geste. L'écran disait bien « Votre
  /// session a expiré », mais n'offrait que « Réessayer » : un bouton qui, par
  /// construction, relance les mêmes requêtes avec le même jeton mort et
  /// échoue à l'identique aussi longtemps que la personne insiste. Même
  /// distinction — et même geste de sortie — que l'accueil du lecteur.
  bool _sessionExpiree = false;

  /// Le flux temps réel auquel la liste est branchée.
  ///
  /// Même mécanisme que le fil qu'elle ouvre : la référence est gardée ici
  /// parce que `dispose` ne peut plus interroger l'arbre des fournisseurs.
  NotificationProvider? _flux;

  /// La dernière notification de message privé déjà prise en compte.
  String? _derniereNotificationVue;

  /// Délai de garde entre deux rechargements déclenchés par le flux.
  static const Duration _delaiDeGarde = Duration(seconds: 3);

  Timer? _rechargementDiffere;
  DateTime? _dernierRechargement;

  @override
  void initState() {
    super.initState();
    _charger();
    _ecouterLeFlux();
  }

  @override
  void dispose() {
    _rechargementDiffere?.cancel();
    _flux?.removeListener(_surNotification);
    super.dispose();
  }

  /// Branche la liste sur le flux des notifications.
  ///
  /// La liste ne se rechargeait qu'à l'ouverture et au retour d'un fil : qui
  /// restait sur cet écran ne voyait aucune pastille s'allumer, même quand un
  /// message venait d'arriver — il fallait en sortir et y revenir. Le serveur
  /// prévient pourtant le destinataire de chaque message privé, et ce flux
  /// arrive en direct par le SSE de NotificationProvider.
  ///
  /// Aucun filtrage sur la référence, contrairement au fil : ici TOUTE
  /// conversation qui reçoit quelque chose change la liste — l'aperçu, la
  /// pastille, et l'ordre, puisque le serveur remonte le fil en tête.
  void _ecouterLeFlux() {
    NotificationProvider flux;
    try {
      flux = context.read<NotificationProvider>();
    } on ProviderNotFoundException {
      // Hors de l'arbre de l'application — un écran isolé, un test — la liste
      // reste consultable, simplement sans mise à jour spontanée.
      return;
    }
    _flux = flux;
    // Ce qui est déjà arrivé avant l'ouverture n'est pas une nouveauté : sans
    // cette prise de repère, arriver sur l'écran avec une notification en
    // attente déclencherait aussitôt un second chargement.
    _derniereNotificationVue = _derniereMessagePrive(flux);
    flux.addListener(_surNotification);
  }

  /// L'identifiant de la notification de message privé la plus récente.
  ///
  /// Le type se compare EXACTEMENT via `concerneLesDeuxProfils`, jamais par
  /// `contains('message')` : les messages de salon en contiennent aussi et
  /// n'ont rien à faire dans cette liste-ci.
  String? _derniereMessagePrive(NotificationProvider flux) {
    for (final NotificationModel n in flux.notifications) {
      if (NotificationProvider.concerneLesDeuxProfils(n.type)) return n.id;
    }
    return null;
  }

  void _surNotification() {
    final flux = _flux;
    if (flux == null || !mounted) return;

    final derniere = _derniereMessagePrive(flux);
    if (derniere == null || derniere == _derniereNotificationVue) return;

    _derniereNotificationVue = derniere;
    _programmerRechargement();
  }

  /// Recharge la liste, sans jamais plus d'une requête par délai de garde.
  ///
  /// Plusieurs messages reçus coup sur coup valent autant de notifications :
  /// sans ce délai, autant de requêtes partiraient pour ramener presque
  /// exactement la même liste.
  void _programmerRechargement() {
    if (_rechargementDiffere?.isActive ?? false) return;

    final dernier = _dernierRechargement;
    final ecoule = dernier == null
        ? _delaiDeGarde
        : DateTime.now().difference(dernier);

    if (ecoule >= _delaiDeGarde) {
      _charger(enArrierePlan: true);
      return;
    }
    _rechargementDiffere = Timer(_delaiDeGarde - ecoule, () {
      if (!mounted) return;
      _charger(enArrierePlan: true);
    });
  }

  /// Charge la liste des conversations.
  ///
  /// `enArrierePlan` distingue le rechargement que personne n'a demandé — le
  /// flux temps réel — de celui que l'on attend : le premier échoue en
  /// silence, sans interrompre par un bandeau une panne passagère dont on ne
  /// pouvait rien faire.
  Future<void> _charger({bool enArrierePlan = false}) async {
    _dernierRechargement = DateTime.now();
    // On repart de l'INCONNU, pas du vide.
    //
    // « Réessayer » n'effaçait que l'erreur. Depuis l'état d'erreur,
    // `_chargement` valait déjà false et la liste était vide : le build
    // tombait donc sur la branche « Aucune conversation — vos échanges
    // apparaîtront ici », affichée pendant toute la durée de la requête.
    // C'est exactement le mensonge que cet écran ferme par ailleurs, remis
    // à l'écran pour une seconde.
    //
    // La reprise du chargement est conditionnée à une liste vide : un
    // rafraîchissement sur une liste déjà remplie continue de la montrer,
    // comme le veut la garde du `catch` plus bas.
    if (mounted) {
      setState(() {
        _erreur = null;
        _sessionExpiree = false;
        if (_conversations.isEmpty) _chargement = true;
      });
    }
    try {
      final token = await TokenStorage.getToken();
      if (token == null) {
        if (!mounted) return;
        setState(() {
          _chargement = false;
          _sessionExpiree = true;
          _erreur = "Votre session a expiré. Reconnectez-vous.";
        });
        return;
      }

      final conversations = await _service.getConversations(token);
      if (!mounted) return;
      setState(() {
        _conversations = conversations;
        _chargement = false;
      });
    } catch (e) {
      if (!mounted) return;
      final message = messageLisible(
        e,
        repli: "Vos conversations n'ont pas pu être chargées.",
      );
      // Un rafraîchissement raté ne remplace pas une liste déjà chargée par
      // l'écran d'erreur : on revenait d'un fil, ou on tirait pour rafraîchir
      // pendant une micro-coupure, et toutes les conversations — pourtant en
      // mémoire — disparaissaient derrière « Conversations indisponibles ».
      // Même garde que ConversationPage : l'erreur ne prend la place de la
      // liste que lorsqu'il n'y a rien à montrer ; sinon on garde l'affichage
      // et on signale discrètement.
      setState(() {
        _chargement = false;
        if (_conversations.isEmpty) {
          _erreur = message;
          // La cause, pour choisir le bouton : réessayer, ou se reconnecter.
          _sessionExpiree = estSessionExpiree(e);
        }
      });
      // Le bandeau ne s'affiche que pour un geste que l'on a fait : un
      // rechargement déclenché par le flux qui échoue n'a rien à interrompre,
      // la liste affichée reste juste — simplement un peu en retard.
      if (_conversations.isNotEmpty && !enArrierePlan) {
        AppNotifications.showSnackBar(context, message: message, isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    AppColors.suivreLeTheme(context);

    if (_chargement) {
      return Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    return RefreshIndicator(
      onRefresh: _charger,
      color: AppColors.primary,
      child: _erreur != null
          ? _messageCentre(
              // Une session finie n'est pas une panne du service : elle a sa
              // cause, son titre et son geste propres.
              icone: _sessionExpiree ? Iconsax.lock : Iconsax.warning_2,
              titre: _sessionExpiree
                  ? "Session expirée"
                  : "Conversations indisponibles",
              detail: _erreur!,
              action: true,
            )
          : _conversations.isEmpty
          ? _messageCentre(
              icone: Iconsax.message,
              titre: "Aucune conversation",
              detail:
                  "Vos échanges avec les lecteurs et les autres auteurs "
                  "apparaîtront ici.",
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _conversations.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                indent: 76,
                color: AppColors.textPrimary.withOpacity(0.05),
              ),
              itemBuilder: (context, i) => _ligne(_conversations[i]),
            ),
    );
  }

  /// Un état centré, qui reste tirable pour rafraîchir.
  ///
  /// Le `ListView` sous-jacent n'est pas décoratif : sans lui, le geste de
  /// rafraîchissement ne prend pas sur un écran vide — précisément le moment où
  /// l'on veut réessayer.
  Widget _messageCentre({
    required IconData icone,
    required String titre,
    required String detail,
    bool action = false,
  }) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.18),
        Icon(icone, size: 72, color: AppColors.textHint),
        const SizedBox(height: 20),
        Text(
          titre,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            detail,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        if (action) ...[
          const SizedBox(height: 20),
          Center(
            // Un bouton qui peut aboutir, ou pas ce bouton-là. « Réessayer »
            // sur un jeton mort ne peut par construction jamais réussir.
            child: _sessionExpiree
                ? ElevatedButton(
                    onPressed: _seReconnecter,
                    child: const Text("Se reconnecter"),
                  )
                : ElevatedButton(
                    onPressed: _charger,
                    child: const Text("Réessayer"),
                  ),
          ),
        ],
      ],
    );
  }

  /// Termine la session et ramène à l'écran de connexion.
  ///
  /// Le nettoyage passe par [SessionService] : effacer le seul jeton laisserait
  /// sur l'appareil la bibliothèque téléchargée et le profil choisi. C'est le
  /// point de nettoyage unique qu'empruntent tous les autres chemins de
  /// déconnexion.
  Future<void> _seReconnecter() async {
    await SessionService.terminer();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  Widget _ligne(Conversation conversation) {
    final correspondant = conversation.correspondant;
    final apercu = conversation.dernierMessage;
    final nonLus = conversation.nonLus;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: ClipOval(
        child: ProfileImageHelper.buildProfileImage(
          correspondant.photo,
          fallbackInitial: correspondant.nom.isNotEmpty
              ? correspondant.nom.substring(0, 1).toUpperCase()
              : "?",
          textStyle: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.accentInk,
          ),
          width: 48,
          height: 48,
          fit: BoxFit.cover,
        ),
      ),
      title: Text(
        correspondant.nom.isNotEmpty ? correspondant.nom : "Utilisateur",
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.poppins(
          fontSize: 14,
          // Un fil non lu s'annonce aussi par son poids, pas seulement par la
          // pastille : elle est petite, et se manque d'un coup d'œil.
          fontWeight: nonLus > 0 ? FontWeight.w700 : FontWeight.w500,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: apercu == null
          ? Text(
              "Aucun message",
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: AppColors.textHint,
              ),
            )
          : Text(
              apercu.deMoi ? "Vous : ${apercu.contenu}" : apercu.contenu,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: nonLus > 0
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
            ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (apercu?.creeLe != null)
            Text(
              heureCourte(apercu!.creeLe!),
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: AppColors.textHint,
              ),
            ),
          if (nonLus > 0) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
              ),
              child: Text(
                nonLus > 99 ? "99+" : "$nonLus",
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.onAccent,
                ),
              ),
            ),
          ],
        ],
      ),
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ConversationPage(conversation: conversation),
          ),
        );
        // Au retour, la pastille de non-lus a changé : le serveur a marqué les
        // messages comme lus à l'ouverture du fil.
        if (mounted) _charger();
      },
    );
  }
}
