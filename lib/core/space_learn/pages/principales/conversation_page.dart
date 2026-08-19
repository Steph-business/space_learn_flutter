import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';

import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/themes/app_dimensions.dart';
import 'package:space_learn_flutter/core/utils/app_notifications.dart';
import 'package:space_learn_flutter/core/utils/message_erreur.dart';
import 'package:space_learn_flutter/core/utils/profile_image_helper.dart';
import 'package:space_learn_flutter/core/utils/token_storage.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/dm_service.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/conversation_model.dart';

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

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void dispose() {
    _saisie.dispose();
    _defilement.dispose();
    super.dispose();
  }

  Future<void> _charger() async {
    if (mounted) setState(() => _erreur = null);
    try {
      final token = await TokenStorage.getToken();
      if (token == null) {
        if (!mounted) return;
        setState(() {
          _chargement = false;
          _erreur = "Votre session a expiré. Reconnectez-vous.";
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
      setState(() {
        _messages = messages;
        _chargement = false;
      });
      _descendreEnBas();
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

  void _descendreEnBas() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_defilement.hasClients) return;
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
