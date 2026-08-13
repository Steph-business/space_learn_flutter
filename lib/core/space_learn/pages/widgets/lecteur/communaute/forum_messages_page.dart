import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/utils/app_notifications.dart';
import 'package:space_learn_flutter/core/themes/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:space_learn_flutter/core/themes/app_dimensions.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/discussionModel.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/messageModel.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/messageService.dart';
import 'package:space_learn_flutter/core/utils/token_storage.dart';

class ForumMessagesPage extends StatefulWidget {
  final Discussion discussion;

  const ForumMessagesPage({super.key, required this.discussion});

  @override
  State<ForumMessagesPage> createState() => _ForumMessagesPageState();
}

class _ForumMessagesPageState extends State<ForumMessagesPage> {
  final MessageService _messageService = MessageService();
  final TextEditingController _msgController = TextEditingController();
  List<Message> _messages = [];
  bool _isLoading = true;

  /// Ce qui a empeche le chargement, s'il a echoue.
  ///
  /// Jeton absent, la fonction sortait avant de toucher a _isLoading : la roue
  /// tournait sans fin. Reseau coupe, la liste restait vide et le fil paraissait
  /// n'avoir jamais rien contenu. Deux pannes muettes, indiscernables l'une de
  /// l'autre et d'un salon reellement neuf.
  String? _erreur;

  /// Pour amener le fil sur le dernier message.
  final ScrollController _defilement = ScrollController();

  String _timeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inDays >= 7) {
      final weeks = diff.inDays ~/ 7;
      return "il y a $weeks semaine${weeks > 1 ? 's' : ''}";
    } else if (diff.inDays >= 1) {
      return "il y a ${diff.inDays} jour${diff.inDays > 1 ? 's' : ''}";
    } else if (diff.inHours >= 1) {
      return "il y a ${diff.inHours} heure${diff.inHours > 1 ? 's' : ''}";
    } else if (diff.inMinutes >= 1) {
      return "il y a ${diff.inMinutes} min";
    } else {
      return "à l'instant";
    }
  }

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    _defilement.dispose();
    _msgController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    if (mounted) setState(() => _erreur = null);
    try {
      final token = await TokenStorage.getToken();
      if (token == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _erreur =
                "Votre session a expiré. Reconnectez-vous pour "
                "revenir dans la discussion.";
          });
        }
        return;
      }
      final messages = await _messageService.getMessagesByDiscussion(
        widget.discussion.id,
        token,
      );
      if (mounted) {
        setState(() {
          _messages = messages;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _erreur =
              "Les messages n'ont pas pu être chargés. "
              "Vérifiez votre connexion.";
        });
      }
    }
  }

  /// Amene le fil sur le dernier message.
  ///
  /// Apres envoi, le message partait bien mais restait sous la ligne de
  /// flottaison : on ecrivait sans voir ce qu'on venait de dire.
  void _descendreEnBas() {
    if (!_defilement.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_defilement.hasClients) return;
      _defilement.animateTo(
        _defilement.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

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

        // On récupère le nom/photo/rang d'un message précédent si possible (même utilisateur)
        for (var m in _messages) {
          if (m.utilisateurId == newMessage.utilisateurId) {
            if (m.nomUtilisateur != null) nom = m.nomUtilisateur;
            if (m.photoProfil != null) photo = m.photoProfil;
            if (m.rangUtilisateur != null) rang = m.rangUtilisateur;
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
        );

        _msgController.clear();
        setState(() {
          _messages.add(msgToAdd);
        });
        _descendreEnBas();

        // Recharge silencieusement les messages depuis le serveur pour être 100% à jour
        _loadMessages();
      }
    } catch (e) {
      if (!mounted) return;
      AppNotifications.showSnackBar(
        context,
        message: "Erreur lors de l'envoi : $e",
        isError: true,
      );
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
          widget.discussion.titre,
          style: AppTextStyles.button14,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : _erreur != null
                ? Center(
                    child: Padding(
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
                ? Center(
                    child: Text(
                      "Aucun message pour le moment.\nSoyez le premier !",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(color: AppColors.textHint),
                    ),
                  )
                : ListView.builder(
                    controller: _defilement,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      return _buildMessageItem(msg);
                    },
                  ),
          ),
          Container(
            padding: EdgeInsets.all(16),
            color: AppColors.cardBackground,
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
        ],
      ),
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
                  color: AppColors.secondaryVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(width: 6),
              _getUserRankBadge(username, rank: msg.rangUtilisateur),
              Spacer(),
              Text(
                _timeAgo(msg.creeLe),
                style: GoogleFonts.poppins(
                  color: AppColors.textHint,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(msg.contenu, style: AppTextStyles.body),
        ],
      ),
    );
  }
}
