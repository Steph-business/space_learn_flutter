import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';

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

/// Un échange privé avec quelqu'un.
///
/// Ni cet écran ni son service n'existaient : la messagerie privée était écrite
/// côté serveur mais n'avait aucun client, et le bouton « Messages » présent sur
/// sept écrans menait invariablement à « Aucun message ».
class ConversationPage extends StatefulWidget {
  const ConversationPage({super.key, required this.conversation});

  final Conversation conversation;

  @override
  State<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends State<ConversationPage> {
  final DmService _service = DmService();
  final TextEditingController _saisie = TextEditingController();
  final ScrollController _defilement = ScrollController();

  List<MessagePrive> _messages = [];
  bool _chargement = true;
  String? _erreur;

  /// Un envoi à la fois.
  ///
  /// Le même verrou que dans les salons : un double appui, ou un appui répété
  /// quand le réseau traîne, publierait deux fois le même message.
  bool _envoiEnCours = false;

  /// Le flux temps réel auquel ce fil est branché.
  ///
  /// Le fil n'ouvre pas sa propre connexion : il écoute celle des
  /// notifications, déjà ouverte pour toute l'application. La référence est
  /// gardée ici parce que `dispose` ne peut plus interroger l'arbre des
  /// fournisseurs — s'y désabonner par `context.read` y lève une exception.
  NotificationProvider? _flux;

  /// La dernière notification de ce fil déjà prise en compte.
  ///
  /// Le fournisseur prévient à chaque changement, y compris pour des
  /// notifications étrangères à cette conversation ou pour une simple mise à
  /// jour de « lu ». Sans ce repérage, la moindre notification de
  /// l'application rechargerait le fil — et ouvrir une conversation dont la
  /// notification était en attente déclencherait aussitôt un second
  /// chargement.
  String? _derniereNotificationVue;

  /// Délai de garde entre deux rechargements déclenchés par le flux.
  ///
  /// Cinq messages envoyés coup sur coup valent cinq notifications SSE :
  /// sans ce délai, cinq requêtes partiraient pour ramener presque exactement
  /// la même liste.
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
    _saisie.dispose();
    _defilement.dispose();
    super.dispose();
  }

  /// Branche le fil sur le flux des notifications.
  ///
  /// Le fil ne se chargeait qu'une fois, à l'ouverture : deux personnes
  /// pouvaient s'écrire sans rien voir arriver tant qu'on ne tirait pas vers
  /// le bas — et rien n'invitait à le faire, puisque le serveur marque les
  /// messages reçus comme lus dès l'ouverture du fil (DmService.getMessages)
  /// et qu'aucune pastille ne se rallume tant qu'on y reste. C'est le défaut
  /// déjà corrigé dans les salons de forum (ForumMessagesPage), laissé intact
  /// sur le seul écran où l'échange est à deux, donc où l'on attend le plus
  /// d'immédiateté.
  ///
  /// Rien à ajouter côté serveur : à chaque message privé, il crée déjà une
  /// notification « message_prive » portant l'identifiant de la conversation
  /// en référence (space_learn_livres/modules/direct_message/service.go), et
  /// ce flux arrive en direct par le SSE de NotificationProvider.
  void _ecouterLeFlux() {
    NotificationProvider flux;
    try {
      flux = context.read<NotificationProvider>();
    } on ProviderNotFoundException {
      // Hors de l'arbre de l'application — un écran isolé, un test — le fil
      // reste consultable, simplement sans mise à jour spontanée. Mieux vaut
      // ça qu'une page qui refuse de s'afficher.
      return;
    }
    _flux = flux;
    // Ce qui est déjà arrivé avant l'ouverture n'est pas une nouveauté.
    _derniereNotificationVue = _derniereDuFil(flux);
    flux.addListener(_surNotification);
  }

  /// L'identifiant de la notification la plus récente portant sur ce fil.
  String? _derniereDuFil(NotificationProvider flux) {
    for (final n in flux.notifications) {
      if (_concerneCeFil(n)) return n.id;
    }
    return null;
  }

  /// Cette notification parle-t-elle de la conversation ouverte ?
  ///
  /// La référence dit de quoi on parle, le type dit à quel titre — et le type
  /// se compare EXACTEMENT, jamais par `contains('message')` : c'est la règle
  /// déjà posée par `concerneLesDeuxProfils`, qu'on appelle ici plutôt que de
  /// réécrire la comparaison, pour n'avoir qu'un seul endroit à corriger le
  /// jour où le serveur renommerait ce type (elle tolère au passage la
  /// variante accentuée qu'une vieille ligne en base pourrait encore porter).
  /// Un fragment aurait fait recharger ce fil sur les messages de salon.
  bool _concerneCeFil(NotificationModel n) {
    if (n.referenceId?.trim() != widget.conversation.id) return false;
    return NotificationProvider.concerneLesDeuxProfils(n.type);
  }

  void _surNotification() {
    final flux = _flux;
    if (flux == null || !mounted) return;

    final derniere = _derniereDuFil(flux);
    if (derniere == null || derniere == _derniereNotificationVue) return;

    _derniereNotificationVue = derniere;
    _programmerRechargement();
  }

  /// Recharge le fil, sans jamais plus d'une requête par délai de garde.
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

  /// Charge le fil depuis le serveur.
  ///
  /// `enArrierePlan` distingue le rechargement que personne n'a demandé — le
  /// flux temps réel — du chargement que l'on attend. Le premier ne prend
  /// jamais la place de ce qui est lisible à l'écran.
  Future<void> _charger({bool enArrierePlan = false}) async {
    _dernierRechargement = DateTime.now();
    if (mounted) {
      setState(() {
        // On repart de l'INCONNU, pas du vide. Depuis l'état d'erreur,
        // `_chargement` valait déjà false et la liste était vide : effacer
        // `_erreur` faisait donc tomber le build sur « Écrivez le premier
        // message » — un fil qu'on n'a pas pu lire présenté comme un fil
        // neuf — pendant toute la durée de la requête. Même correctif que la
        // liste des conversations. Un fil réellement vide, lui, garde son
        // message : rien ne le remplace par une roue qui tourne.
        if (_erreur != null) _chargement = true;
        _erreur = null;
      });
    }
    try {
      final token = await TokenStorage.getToken();
      if (token == null) {
        if (!mounted) return;
        setState(() {
          _chargement = false;
          // Même garde que le `catch` plus bas : un rechargement que personne
          // n'a demandé ne remplace pas la conversation affichée par un écran
          // d'erreur. La session finie se dira à l'envoi, qui est le moment
          // où elle empêche vraiment quelque chose.
          if (!enArrierePlan || _messages.isEmpty) {
            _erreur = "Votre session a expiré. Reconnectez-vous.";
          }
        });
        return;
      }

      final moi = await TokenStorage.getUserId();
      final messages = await _service.getMessages(
        widget.conversation.id,
        token,
        moiId: moi,
      );
      if (!mounted) return;

      // Qui remonte l'historique doit pouvoir continuer : un message qui
      // arrive pendant ce temps ne doit pas nous ramener de force en bas. Le
      // défilement était INCONDITIONNEL — sans conséquence tant que seule
      // l'ouverture du fil rechargeait, arrachant l'écran à chaque message
      // reçu maintenant que le flux recharge tout seul. À l'ouverture, la
      // liste n'a pas encore de client : on est donc « en bas » et l'on
      // descend bien sur le dernier message, comme avant.
      final etaitEnBas = _estEnBasDuFil();
      final combienAvant = _messages.length;

      setState(() {
        _messages = messages;
        _chargement = false;
      });
      if (etaitEnBas && messages.length > combienAvant) _descendreEnBas();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chargement = false;
        // Un rechargement qui échoue ne doit pas effacer ce qui est déjà à
        // l'écran : on ne signale l'erreur que si l'on n'a rien à montrer.
        if (_messages.isEmpty) {
          _erreur = messageLisible(
            e,
            repli: "Cette conversation n'a pas pu être chargée.",
          );
        }
      });
    }
  }

  /// Lit-on la fin du fil ?
  ///
  /// Tant que la liste n'a pas de client — à l'ouverture, ou sur un fil trop
  /// court pour défiler — il n'y a pas d'historique à préserver : on répond
  /// oui, et le fil descend comme il l'a toujours fait.
  bool _estEnBasDuFil() {
    if (!_defilement.hasClients) return true;
    final position = _defilement.position;
    return position.pixels >= position.maxScrollExtent - 80;
  }

  void _descendreEnBas() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // `mounted` en plus du test de client : le rappel est différé d'une
      // image, et le fil peut avoir été quitté entre-temps.
      if (!mounted || !_defilement.hasClients) return;
      _defilement.jumpTo(_defilement.position.maxScrollExtent);
    });
  }

  Future<void> _envoyer() async {
    final texte = _saisie.text.trim();
    if (texte.isEmpty || _envoiEnCours) return;
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

      final moi = await TokenStorage.getUserId();
      // Le champ n'est vidé qu'une fois le message parti : un envoi qui échoue
      // ne doit pas emporter ce qu'on venait d'écrire.
      final envoye = await _service.envoyerMessage(
        widget.conversation.id,
        texte,
        token,
        moiId: moi,
      );

      if (!mounted) return;
      _saisie.clear();
      setState(() => _messages = [..._messages, envoye]);
      _descendreEnBas();
    } catch (e) {
      if (!mounted) return;
      AppNotifications.showSnackBar(
        context,
        message: messageLisible(e, repli: "Ce message n'a pas pu être envoyé."),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _envoiEnCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    AppColors.suivreLeTheme(context);
    final correspondant = widget.conversation.correspondant;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.cardBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Iconsax.arrow_left_2,
            color: AppColors.textPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            ClipOval(
              child: ProfileImageHelper.buildProfileImage(
                correspondant.photo,
                fallbackInitial: correspondant.nom.isNotEmpty
                    ? correspondant.nom.substring(0, 1).toUpperCase()
                    : "?",
                textStyle: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: AppColors.accentInk,
                ),
                width: 32,
                height: 32,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                correspondant.nom.isNotEmpty
                    ? correspondant.nom
                    : "Conversation",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _corps()),
          _barreDeSaisie(),
        ],
      ),
    );
  }

  Widget _corps() {
    if (_chargement) {
      return Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_erreur != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Iconsax.warning_2, size: 40, color: AppColors.textHint),
              const SizedBox(height: 12),
              Text(
                _erreur!,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _charger,
                child: const Text("Réessayer"),
              ),
            ],
          ),
        ),
      );
    }
    if (_messages.isEmpty) {
      return Center(
        child: Text(
          "Écrivez le premier message.",
          style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textHint),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _charger,
      color: AppColors.primary,
      child: ListView.builder(
        controller: _defilement,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: _messages.length,
        itemBuilder: (context, i) => _bulle(_messages[i]),
      ),
    );
  }

  /// Une bulle, du côté de celui qui l'a écrite.
  Widget _bulle(MessagePrive message) {
    final deMoi = message.deMoi;

    return Align(
      alignment: deMoi ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: deMoi ? AppColors.primary : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.contenu,
              style: GoogleFonts.poppins(
                fontSize: 14,
                // Sur l'aplat coloré de mes propres bulles, `onAccent` est la
                // seule couleur qui garantisse le contraste dans les deux
                // thèmes.
                color: deMoi ? AppColors.onAccent : AppColors.textPrimary,
              ),
            ),
            if (message.creeLe != null) ...[
              const SizedBox(height: 4),
              Text(
                heureCourte(message.creeLe!),
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: deMoi
                      ? AppColors.onAccent.withOpacity(0.7)
                      : AppColors.textHint,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _barreDeSaisie() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      color: AppColors.cardBackground,
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _saisie,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: "Votre message",
                  hintStyle: GoogleFonts.poppins(color: AppColors.textHint),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusPill,
                    ),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: AppColors.scaffoldBackground,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                onSubmitted: (_) => _envoyer(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _envoiEnCours ? null : _envoyer,
              icon: _envoiEnCours
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    )
                  : Icon(Iconsax.send_1, color: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}
