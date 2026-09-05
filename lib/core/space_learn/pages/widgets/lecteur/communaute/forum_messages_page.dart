import 'dart:async';

import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/utils/app_notifications.dart';
import 'package:space_learn_flutter/core/themes/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:space_learn_flutter/core/themes/app_dimensions.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/discussionModel.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/messageModel.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/notificationModel.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/messageService.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/discussionService.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/notification_provider.dart';
import 'package:space_learn_flutter/core/utils/token_storage.dart';
import 'temps_relatif.dart';
import 'package:space_learn_flutter/core/utils/message_erreur.dart';

class ForumMessagesPage extends StatefulWidget {
  final Discussion discussion;

  const ForumMessagesPage({super.key, required this.discussion});

  @override
  State<ForumMessagesPage> createState() => _ForumMessagesPageState();
}

class _ForumMessagesPageState extends State<ForumMessagesPage> {
  final MessageService _messageService = MessageService();
  final DiscussionService _discussionService = DiscussionService();
  final TextEditingController _msgController = TextEditingController();
  List<Message> _messages = [];
  bool _isLoading = true;

  /// Le salon tel qu'il est maintenant.
  ///
  /// Distinct de `widget.discussion`, qui reste figé sur ce que la page
  /// précédente connaissait : renommer le sujet doit se voir sans revenir en
  /// arrière et rouvrir le salon.
  late Discussion _salon = widget.discussion;

  /// Ce qui a empeche le chargement, s'il a echoue.
  ///
  /// Jeton absent, la fonction sortait avant de toucher a _isLoading : la roue
  /// tournait sans fin. Reseau coupe, la liste restait vide et le fil paraissait
  /// n'avoir jamais rien contenu. Deux pannes muettes, indiscernables l'une de
  /// l'autre et d'un salon reellement neuf.
  String? _erreur;

  /// Pour amener le fil sur le dernier message.
  final ScrollController _defilement = ScrollController();

  /// Le flux temps reel auquel ce salon est branche.
  ///
  /// Le fil n'ouvre pas sa propre connexion : il ecoute celle des
  /// notifications, deja ouverte pour toute l'application. La reference est
  /// gardee ici parce que `dispose` ne peut plus interroger l'arbre des
  /// fournisseurs — s'y desabonner par `context.read` y leve une exception.
  NotificationProvider? _flux;

  /// La derniere notification de ce salon deja prise en compte.
  ///
  /// Le fournisseur previent a chaque changement, y compris pour des
  /// notifications qui ne nous regardent pas ou pour une simple mise a jour
  /// de « lu ». Sans ce reperage, la moindre notification de l'application
  /// rechargerait le fil.
  String? _derniereNotificationVue;

  /// Delai de garde entre deux rechargements declenches par le flux.
  ///
  /// Cinq messages envoyes en rafale dans un salon anime valent cinq
  /// notifications : sans ce delai, cinq requetes partaient coup sur coup pour
  /// ramener presque exactement la meme liste.
  static const Duration _delaiDeGarde = Duration(seconds: 3);

  Timer? _rechargementDiffere;
  DateTime? _dernierRechargement;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _ecouterLeFlux();
  }

  @override
  void dispose() {
    _rechargementDiffere?.cancel();
    _flux?.removeListener(_surNotification);
    _defilement.dispose();
    _msgController.dispose();
    super.dispose();
  }

  /// Branche le fil sur le flux des notifications.
  ///
  /// Le salon ne se chargeait qu'une fois, a l'ouverture : deux personnes
  /// pouvaient rester une heure face a face sans jamais se voir ecrire, il
  /// fallait sortir et revenir. Le serveur previent maintenant chaque
  /// participant d'un nouveau message, avec l'identifiant du salon en
  /// reference — il suffit d'ecouter ce qui arrive deja.
  void _ecouterLeFlux() {
    NotificationProvider flux;
    try {
      flux = context.read<NotificationProvider>();
    } on ProviderNotFoundException {
      // Hors de l'arbre de l'application — un ecran isole, un test — le fil
      // reste consultable, simplement sans mise a jour spontanee. Mieux vaut
      // ca qu'une page qui refuse de s'afficher.
      return;
    }
    _flux = flux;
    // Ce qui est deja arrive avant l'ouverture n'est pas une nouveaute : sans
    // cette prise de repere, entrer dans un salon dont on avait une
    // notification en attente declenchait aussitot un second chargement.
    _derniereNotificationVue = _derniereDuSalon(flux);
    flux.addListener(_surNotification);
  }

  /// L'identifiant de la notification la plus recente portant sur ce salon.
  String? _derniereDuSalon(NotificationProvider flux) {
    for (final n in flux.notifications) {
      if (_concerneCeSalon(n)) return n.id;
    }
    return null;
  }

  /// Cette notification parle-t-elle du salon ouvert ?
  bool _concerneCeSalon(NotificationModel n) {
    if (n.referenceId?.trim() != widget.discussion.id) return false;
    // Le type sert de garde-fou : la reference dit de quoi on parle, le type
    // dit a quel titre. On ne recharge pas un fil de discussion parce qu'une
    // notification d'une autre nature cite le meme identifiant.
    final type = n.type.toLowerCase();
    return type.contains('communaut') ||
        type.contains('message') ||
        type.contains('discussion') ||
        type.contains('salon');
  }

  void _surNotification() {
    final flux = _flux;
    if (flux == null || !mounted) return;

    final derniere = _derniereDuSalon(flux);
    if (derniere == null || derniere == _derniereNotificationVue) return;

    _derniereNotificationVue = derniere;
    _programmerRechargement();
  }

  /// Recharge le fil, sans jamais plus d'une requete par delai de garde.
  void _programmerRechargement() {
    if (_rechargementDiffere?.isActive ?? false) return;

    final dernier = _dernierRechargement;
    final ecoule = dernier == null
        ? _delaiDeGarde
        : DateTime.now().difference(dernier);

    if (ecoule >= _delaiDeGarde) {
      _loadMessages(enArrierePlan: true);
      return;
    }
    _rechargementDiffere = Timer(_delaiDeGarde - ecoule, () {
      if (!mounted) return;
      _loadMessages(enArrierePlan: true);
    });
  }

  /// Charge le fil depuis le serveur.
  ///
  /// `enArrierePlan` distingue le rechargement que personne n'a demande — le
  /// flux, un envoi — du chargement que l'on attend. Le premier ne parle que
  /// s'il a quelque chose de mieux a montrer.
  Future<void> _loadMessages({bool enArrierePlan = false}) async {
    _dernierRechargement = DateTime.now();
    try {
      final token = await TokenStorage.getToken();
      if (token == null) {
        _signalerEchec(
          "Votre session a expiré. Reconnectez-vous pour "
          "revenir dans la discussion.",
          enArrierePlan: enArrierePlan,
        );
        return;
      }
      final messages = await _messageService.getMessagesByDiscussion(
        widget.discussion.id,
        token,
      );
      if (!mounted) return;

      // Qui lisait la fin du fil doit continuer a la lire : un message qui
      // arrive pendant qu'on remonte l'historique ne doit pas nous y ramener
      // de force, mais s'il arrive alors qu'on est en bas, il doit se voir.
      final etaitEnBas = _estEnBasDuFil();
      final combienAvant = _messages.length;

      setState(() {
        _messages = messages;
        _isLoading = false;
        _erreur = null;
      });

      if (etaitEnBas && messages.length > combienAvant) _descendreEnBas();

      // La visite se note ici, et non a la sortie du salon.
      //
      // Elle etait enregistree au retour vers la liste des sujets : un message
      // arrive pendant qu'on etait dans le salon passait donc pour lu alors
      // qu'il n'avait jamais ete affiche, et la pastille « nouveau » ne
      // s'allumait jamais. Ce que l'on vient de recevoir du serveur est,
      // celui-la, reellement sous les yeux.
      await TokenStorage.saveDiscussionLastViewed(widget.discussion.id);
    } catch (e) {
      _signalerEchec(
        "Les messages n'ont pas pu être chargés. "
        "Vérifiez votre connexion.",
        enArrierePlan: enArrierePlan,
      );
    }
  }

  /// Rend compte d'un chargement rate, sans effacer ce qui est lisible.
  ///
  /// Une coupure reseau d'une seconde apres un envoi remplacait TOUT le fil
  /// par un ecran d'erreur — alors que le message etait bien parti et que la
  /// conversation entiere etait a l'ecran une demi-seconde plus tot. Un echec
  /// ne detruit plus rien : il ne prend la place du fil que lorsqu'il n'y a
  /// rien a prendre.
  void _signalerEchec(String message, {required bool enArrierePlan}) {
    if (!mounted) return;

    if (_messages.isNotEmpty) {
      setState(() => _isLoading = false);
      if (!enArrierePlan) {
        AppNotifications.showSnackBar(context, message: message, isError: true);
      }
      return;
    }

    setState(() {
      _isLoading = false;
      _erreur = message;
    });
  }

  /// Lit-on la fin du fil ?
  bool _estEnBasDuFil() {
    if (!_defilement.hasClients) return true;
    final position = _defilement.position;
    return position.pixels >= position.maxScrollExtent - 80;
  }

  /// Amene le fil sur le dernier message.
  ///
  /// Apres envoi, le message partait bien mais restait sous la ligne de
  /// flottaison : on ecrivait sans voir ce qu'on venait de dire.
  ///
  /// Le test `hasClients` d'entree a ete retire : quand le premier message
  /// d'un salon vide venait d'etre ajoute, la liste n'existait pas encore et
  /// la fonction sortait avant meme de programmer le defilement. Seul compte
  /// l'etat au moment ou l'image est peinte, teste dans le rappel.
  void _descendreEnBas() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_defilement.hasClients) return;
      _defilement.animateTo(
        _defilement.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  /// Un envoi à la fois.
  ///
  /// Sans ce verrou, un double appui — ou un appui répété quand le réseau
  /// traîne — publiait deux fois le même message dans un salon partagé. Ce
  /// défaut-là écrit un état faux en base, visible de tous, qu'aucun
  /// rechargement ne rattrape. Le motif existait déjà dans le même module, sur
  /// le bouton j'aime.
  bool _envoiEnCours = false;

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty || _envoiEnCours) return;
    setState(() => _envoiEnCours = true);

    try {
      final token = await TokenStorage.getToken();
      if (token == null) {
        if (!mounted) return;
        AppNotifications.showSnackBar(
          context,
          message: "Votre session a expiré. Reconnectez-vous.",
          isError: true,
        );
        return;
      }

      // Le champ n'est vide qu'une fois le message parti. Il etait efface
      // avant l'appel : un envoi qui echouait — reseau, session — emportait
      // avec lui ce que la personne venait d'ecrire.
      final newMessage = await _messageService.createMessage(
        widget.discussion.id,
        text,
        token,
      );

      if (mounted) {
        String? nom;
        String? photo;
        String? rang;
        bool auteur = false;

        // On récupère le nom/photo/rang d'un message précédent si possible (même utilisateur)
        for (var m in _messages) {
          if (m.utilisateurId == newMessage.utilisateurId) {
            if (m.nomUtilisateur != null) nom = m.nomUtilisateur;
            if (m.photoProfil != null) photo = m.photoProfil;
            if (m.rangUtilisateur != null) rang = m.rangUtilisateur;
            if (m.estAuteurDuLivre) auteur = true;
            if (nom != null && photo != null && rang != null) break;
          }
        }

        final msgToAdd = Message(
          id: newMessage.id,
          discussionId: newMessage.discussionId,
          utilisateurId: newMessage.utilisateurId,
          contenu: newMessage.contenu,
          creeLe: newMessage.creeLe,
          discussion: newMessage.discussion,
          nomUtilisateur: nom ?? newMessage.nomUtilisateur,
          photoProfil: photo ?? newMessage.photoProfil,
          rangUtilisateur: rang ?? newMessage.rangUtilisateur,
          // Le serveur ne renvoie pas ces deux-la sur la creation ; le
          // rechargement qui suit les remettra d'aplomb, mais entre-temps on
          // peut au moins retirer son propre message.
          peutSupprimer: true,
          estAuteurDuLivre: auteur,
        );

        _msgController.clear();
        setState(() {
          _messages.add(msgToAdd);
        });

        // Le fil se remet d'aplomb AVANT qu'on descende le voir.
        //
        // Le defilement partait en premier, sur une liste qui allait etre
        // remplacee un instant plus tard par celle du serveur : plus le salon
        // etait actif, plus la liste rechargee etait longue, et moins on
        // voyait ce qu'on venait d'ecrire. On atterrissait quelques messages
        // trop haut. Le rechargement echoue en silence — le message, lui, est
        // parti — et l'on descend de toute facon sur ce qui est affiche.
        await _loadMessages(enArrierePlan: true);
        if (!mounted) return;
        _descendreEnBas();
      }
    } catch (e) {
      if (!mounted) return;
      AppNotifications.showSnackBar(
        context,
        message: messageLisible(e, repli: "Ce message n'a pas pu être envoyé."),
        isError: true,
      );
    } finally {
      // Le verrou se lève dans tous les cas : un échec ne doit pas empêcher de
      // réessayer.
      if (mounted) setState(() => _envoiEnCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    AppColors.suivreLeTheme(context);
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.scaffoldBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Iconsax.arrow_left_2,
            color: AppColors.textPrimary,
            size: 20,
          ),
          // Un simple retour.
          //
          // Le bouton forcait l'onglet Communaute de la barre du lecteur avant
          // de fermer la page. Ces deux pages sont partagees : pour un auteur,
          // dont la barre est une autre, la cle etait nulle et l'appel ne
          // faisait rien ; pour un lecteur venu d'ailleurs — de l'accueil,
          // d'une notification — il le deposait sur un onglet qu'il n'avait pas
          // demande. Fermer la page ramene deja la ou l'on etait.
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _salon.titre,
          style: AppTextStyles.button14,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          // Le menu n'apparaît qu'à qui répond du salon : celui qui a ouvert le
          // sujet, ou l'auteur du livre autour duquel le club s'est formé. Le
          // serveur tranche via `peut_gerer` — ce second titre n'existait pas,
          // un écrivain ne pouvait pas fermer un club portant le nom de son
          // propre ouvrage.
          if (_salon.peutGerer)
            PopupMenuButton<String>(
              icon: Icon(Iconsax.more, color: AppColors.textPrimary, size: 20),
              color: AppColors.cardBackground,
              onSelected: (choix) {
                if (choix == 'modifier') _modifierLeSalon();
                if (choix == 'fermer') _confirmerFermeture();
              },
              itemBuilder: (context) => [
                // Renommer est plus étroit que fermer, et c'est délibéré : le
                // titre est l'ouvrage de celui qui a ouvert la salle. Offrir ce
                // geste à l'auteur du livre lui valait un « accès interdit »,
                // alors que le même menu le laissait FERMER le salon — le plus
                // lourd passait, le plus bénin échouait.
                if (_salon.peutModifier)
                  PopupMenuItem(
                    value: 'modifier',
                    child: Text(
                      "Modifier le sujet",
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                PopupMenuItem(
                  value: 'fermer',
                  child: Text(
                    "Fermer le salon",
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: AppColors.error,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                // Tirer pour rafraichir, sur les trois etats.
                //
                // Le geste est le premier reflexe de qui attend une reponse ;
                // il n'existait pas, et le seul moyen de revoir le fil etait
                // d'y ecrire. Il vaut aussi sur un salon vide et sur un ecran
                // d'erreur — ce sont justement les moments ou l'on insiste.
                : RefreshIndicator(
                    onRefresh: () => _loadMessages(),
                    color: AppColors.primary,
                    backgroundColor: AppColors.cardBackground,
                    child: _erreur != null
                        ? _pleineHauteurDefilable(
                            Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Iconsax.warning_2,
                                    color: AppColors.textSecondary,
                                    size: 32,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _erreur!,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.poppins(
                                      color: AppColors.textSecondary,
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: () {
                                      setState(() => _isLoading = true);
                                      _loadMessages();
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: AppColors.onAccent,
                                    ),
                                    child: const Text("Réessayer"),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : _messages.isEmpty
                        ? _pleineHauteurDefilable(
                            Text(
                              "Aucun message pour le moment.\nSoyez le premier !",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                color: AppColors.textHint,
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: _defilement,
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(16),
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              final msg = _messages[index];
                              return _buildMessageItem(msg);
                            },
                          ),
                  ),
          ),
          // La couleur est posée sur ce Container ENGLOBANT la SafeArea :
          // c'est elle qui doit peindre aussi la zone sûre, sinon une bande
          // de la couleur du fond d'écran apparaît sous le champ de saisie.
          Container(
            color: AppColors.cardBackground,
            // Sans cette SafeArea, le champ de saisie glissait sous la barre
            // de gestes d'Android et la poignée d'iOS — le compositeur était
            // « trop rentré en bas du téléphone ». Le haut est déjà géré par
            // l'AppBar, d'où top: false ; et SafeArea ne pousse que du
            // montant réel de l'appareil, donc rien ne change sur un
            // téléphone à boutons.
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _msgController,
                        style: TextStyle(color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          hintText: "Écrire un message...",
                          hintStyle: TextStyle(
                            color: AppColors.textPrimary.withValues(alpha: 0.4),
                          ),
                          filled: true,
                          fillColor: AppColors.scaffoldBackground,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppDimensions.radiusPill,
                            ),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    GestureDetector(
                      onTap: _sendMessage,
                      child: Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.secondaryVariant,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Iconsax.send_1,
                          color: AppColors.onAccent,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Centre un contenu court tout en le laissant tirer vers le bas.
  ///
  /// Un message d'erreur ou un salon vide ne remplissent pas l'ecran, donc
  /// rien ne defile, donc le geste de rafraichissement n'a rien a quoi
  /// s'accrocher. On lui donne une zone qui occupe toute la hauteur.
  Widget _pleineHauteurDefilable(Widget enfant) {
    return LayoutBuilder(
      builder: (context, contraintes) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: contraintes.maxHeight),
            child: Center(child: enfant),
          ),
        );
      },
    );
  }

  Widget _getUserRankBadge(String username, {String? rank}) {
    String rankTitle;
    Color color;

    if (rank != null) {
      rankTitle = rank;
      switch (rank.toLowerCase()) {
        case 'maître':
        case 'maitre':
          color = AppColors.yellow;
          break;
        case 'érudit':
        case 'erudit':
          color = AppColors.violetLight;
          break;
        case 'explorateur':
          color = AppColors.primaryLight;
          break;
        case 'novice':
          color = AppColors.textSecondary;
          break;
        default:
          color = AppColors.primary;
      }
    } else {
      // Pas de rang transmis, pas de rang affiché.
      //
      // Il était ici deviné sur `username.hashCode % 100` : un participant se
      // voyait sacrer « Maître » ou « Érudit » selon l'orthographe de son nom,
      // publiquement, dans un salon partagé. Une absence vaut mieux qu'une
      // distinction inventée.
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
        border: Border.all(color: color.withOpacity(0.3), width: 0.5),
      ),
      child: Text(
        rankTitle,
        style: GoogleFonts.poppins(
          color: color,
          fontSize: 7,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildMessageItem(Message msg) {
    final String username = msg.nomUtilisateur ?? 'Utilisateur';

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppDimensions.radiusInner),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: AppColors.scaffoldBackground,
                backgroundImage:
                    (msg.photoProfil != null && msg.photoProfil!.isNotEmpty)
                    ? NetworkImage(msg.photoProfil!)
                    : null,
                child: (msg.photoProfil == null || msg.photoProfil!.isEmpty)
                    ? Icon(Icons.person, color: AppColors.textHint, size: 16)
                    : null,
              ),
              SizedBox(width: 8),
              Text(
                username,
                style: GoogleFonts.poppins(
                  color: AppColors.accentInk,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              // Le seul badge qui compte vraiment dans un club de lecture :
              // celui qui dit que la reponse vient de qui a ecrit le livre.
              if (msg.estAuteurDuLivre) ...[
                SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
                  ),
                  child: Text(
                    "Auteur",
                    style: GoogleFonts.poppins(
                      color: AppColors.onAccent,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              SizedBox(width: 6),
              _getUserRankBadge(username, rank: msg.rangUtilisateur),
              Spacer(),
              Text(
                tempsRelatif(msg.creeLe),
                style: GoogleFonts.poppins(
                  color: AppColors.textHint,
                  fontSize: 10,
                ),
              ),
              // Réécrire est réservé à l'auteur du propos, et pour un temps :
              // c'est le serveur qui décide, l'écran ne fait qu'obéir.
              // Modérer, c'est retirer — jamais réécrire au nom d'un autre,
              // donc ce geste-ci n'apparaît jamais au responsable du salon.
              if (msg.peutModifier) ...[
                SizedBox(width: 4),
                InkWell(
                  onTap: () => _modifier(msg),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Iconsax.edit_2,
                      size: 14,
                      color: AppColors.textHint,
                    ),
                  ),
                ),
              ],
              // Le geste n'apparait qu'a qui en a le droit, et c'est le
              // serveur qui le dit : l'auteur du propos, celui qui a ouvert le
              // sujet, ou l'auteur du livre dont c'est le club.
              if (msg.peutSupprimer) ...[
                SizedBox(width: 4),
                InkWell(
                  onTap: () => _confirmerSuppression(msg),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Iconsax.trash,
                      size: 14,
                      color: AppColors.textHint,
                    ),
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: 8),
          // Un message retiré garde sa place dans le fil, sans ses mots.
          //
          // La suppression était sèche : le propos disparaissait, et les
          // réponses qu'il avait suscitées restaient suspendues dans le vide.
          if (msg.supprime)
            Row(
              children: [
                Icon(Iconsax.slash, size: 13, color: AppColors.textHint),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    msg.texteAffiche,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: AppColors.textHint,
                    ),
                  ),
                ),
              ],
            )
          else ...[
            Text(msg.contenu, style: AppTextStyles.body),
            // Sans cette marque, on pourrait réécrire un propos après qu'on y
            // a répondu, et faire dire au fil autre chose que ce qui s'y est
            // passé.
            if (msg.modifie) ...[
              SizedBox(height: 4),
              Text(
                "modifié",
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                  color: AppColors.textHint,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  /// Renommer le salon, ou corriger sa description.
  ///
  /// Aucune fenêtre de temps ici, contrairement aux messages : un salon est un
  /// lieu, pas une déclaration. On renomme une salle aussi longtemps qu'elle
  /// vit — personne ne « répond » à un titre.
  Future<void> _modifierLeSalon() async {
    final titre = TextEditingController(text: _salon.titre);
    final description = TextEditingController(text: _salon.description ?? '');

    final valide = await showDialog<bool>(
      context: context,
      builder: (context) {
        AppColors.suivreLeTheme(context);
        return AlertDialog(
          backgroundColor: AppColors.cardBackground,
          title: Text(
            "Modifier le sujet",
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titre,
                autofocus: true,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  labelText: "Titre",
                  labelStyle: GoogleFonts.poppins(color: AppColors.textHint),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: description,
                maxLines: 4,
                minLines: 1,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  labelText: "Description",
                  labelStyle: GoogleFonts.poppins(color: AppColors.textHint),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                "Annuler",
                style: GoogleFonts.poppins(color: AppColors.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Enregistrer"),
            ),
          ],
        );
      },
    );

    if (valide != true || !mounted) return;

    final nouveauTitre = titre.text.trim();
    if (nouveauTitre.isEmpty) {
      AppNotifications.showSnackBar(
        context,
        message: "Le titre ne peut pas être vide.",
        isError: true,
      );
      return;
    }

    try {
      final token = await TokenStorage.getToken();
      if (token == null) {
        if (!mounted) return;
        AppNotifications.showSnackBar(
          context,
          message: "Votre session a expiré. Reconnectez-vous.",
          isError: true,
        );
        return;
      }

      await _discussionService.updateDiscussion(
        _salon.id,
        token,
        titre: nouveauTitre,
        description: description.text.trim(),
      );
      if (!mounted) return;

      setState(() {
        _salon = _salon.copyWith(
          titre: nouveauTitre,
          description: description.text.trim(),
        );
      });
    } catch (e) {
      if (!mounted) return;
      AppNotifications.showSnackBar(
        context,
        message: messageLisible(e, repli: "Ce sujet n'a pas pu être modifié."),
        isError: true,
      );
    }
  }

  /// Fermer le salon, et la conversation qui s'y tient.
  ///
  /// Le geste est plus lourd que retirer un message : il emporte les propos de
  /// tous les participants. La confirmation le dit explicitement plutôt que de
  /// demander un « êtes-vous sûr ? » sans contenu.
  Future<void> _confirmerFermeture() async {
    final combien = _messages.where((m) => !m.supprime).length;

    final accepte = await showDialog<bool>(
      context: context,
      builder: (context) {
        AppColors.suivreLeTheme(context);
        return AlertDialog(
          backgroundColor: AppColors.cardBackground,
          title: Text(
            "Fermer ce salon ?",
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          content: Text(
            combien > 0
                ? "Le salon et les $combien message(s) qu'il contient seront "
                      "retirés. C'est définitif."
                : "Le salon sera retiré. C'est définitif.",
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                "Annuler",
                style: GoogleFonts.poppins(color: AppColors.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: AppColors.onAccent,
              ),
              child: const Text("Fermer le salon"),
            ),
          ],
        );
      },
    );

    if (accepte != true || !mounted) return;

    try {
      final token = await TokenStorage.getToken();
      if (token == null) {
        if (!mounted) return;
        AppNotifications.showSnackBar(
          context,
          message: "Votre session a expiré. Reconnectez-vous.",
          isError: true,
        );
        return;
      }

      await _discussionService.deleteDiscussion(_salon.id, token);
      if (!mounted) return;

      // La page n'a plus de sujet : on revient au forum.
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      AppNotifications.showSnackBar(
        context,
        message: messageLisible(e, repli: "Ce salon n'a pas pu être fermé."),
        isError: true,
      );
    }
  }

  /// Réécrire son propre message.
  ///
  /// Le texte actuel est proposé tel quel : on corrige une faute, on ne
  /// réécrit pas de mémoire.
  Future<void> _modifier(Message msg) async {
    final controleur = TextEditingController(text: msg.contenu);

    final nouveau = await showDialog<String>(
      context: context,
      builder: (context) {
        AppColors.suivreLeTheme(context);
        return AlertDialog(
          backgroundColor: AppColors.cardBackground,
          title: Text(
            "Modifier votre message",
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          content: TextField(
            controller: controleur,
            autofocus: true,
            maxLines: 5,
            minLines: 1,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: "Votre message",
              hintStyle: GoogleFonts.poppins(color: AppColors.textHint),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "Annuler",
                style: GoogleFonts.poppins(color: AppColors.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controleur.text.trim()),
              child: const Text("Enregistrer"),
            ),
          ],
        );
      },
    );

    // Rien saisi, ou rien changé : on ne marque pas « modifié » pour rien.
    if (nouveau == null || nouveau.isEmpty || nouveau == msg.contenu) return;
    if (!mounted) return;

    try {
      final token = await TokenStorage.getToken();
      if (token == null) {
        if (!mounted) return;
        AppNotifications.showSnackBar(
          context,
          message: "Votre session a expiré. Reconnectez-vous.",
          isError: true,
        );
        return;
      }

      await _messageService.updateMessage(msg.id, nouveau, token);
      if (!mounted) return;

      // On garde l'objet local et on n'y change que le texte.
      //
      // La réponse du serveur est le message relu brut : ni nom, ni avatar, ni
      // rang, ni badge « Auteur », et `peut_supprimer` à false — ces champs-là
      // sont calculés à la LECTURE d'un fil, pas au retour d'une écriture.
      // L'écraser par-dessus la version complète faisait qu'après avoir corrigé
      // une faute, on voyait son propre nom devenir « Utilisateur », son avatar
      // redevenir une silhouette grise et la corbeille disparaître : on ne
      // pouvait plus supprimer le message qu'on venait d'éditer.
      setState(() {
        final i = _messages.indexWhere((m) => m.id == msg.id);
        if (i != -1) {
          _messages[i] = msg.copyWith(contenu: nouveau, modifie: true);
        }
      });
    } catch (e) {
      if (!mounted) return;
      // Le serveur refuse au-delà de vingt-quatre heures ; son message le dit,
      // et il vaut mieux que n'importe quelle phrase écrite ici.
      AppNotifications.showSnackBar(
        context,
        message: messageLisible(
          e,
          repli: "Ce message n'a pas pu être modifié.",
        ),
        isError: true,
      );
    }
  }

  /// Retirer un message se confirme.
  ///
  /// Le geste est definitif et peut porter sur les propos de quelqu'un
  /// d'autre : il ne doit pas partir d'une touche mal placee.
  Future<void> _confirmerSuppression(Message msg) async {
    final accepte = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: Text(
          "Retirer ce message ?",
          style: GoogleFonts.poppins(color: AppColors.textPrimary),
        ),
        content: Text(
          "Il disparaîtra de la discussion pour tout le monde.",
          style: GoogleFonts.poppins(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              "Annuler",
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.onAccent,
            ),
            child: const Text("Retirer"),
          ),
        ],
      ),
    );

    if (accepte != true || !mounted) return;

    try {
      final token = await TokenStorage.getToken();
      if (token == null) {
        if (!mounted) return;
        AppNotifications.showSnackBar(
          context,
          message: "Votre session a expiré. Reconnectez-vous.",
          isError: true,
        );
        return;
      }
      await _messageService.deleteMessage(msg.id, token);
      if (!mounted) return;

      // Le message ne quitte plus la liste : il y reste, vidé de ses mots.
      // Le retirer entièrement laissait les réponses qu'il avait suscitées
      // suspendues dans le vide, et le fil devenait illisible.
      setState(() {
        final i = _messages.indexWhere((m) => m.id == msg.id);
        if (i != -1) _messages[i] = _messages[i].retire();
      });
    } catch (e) {
      if (!mounted) return;
      AppNotifications.showSnackBar(
        context,
        message: "Le message n'a pas pu être retiré.",
        isError: true,
      );
    }
  }
}
