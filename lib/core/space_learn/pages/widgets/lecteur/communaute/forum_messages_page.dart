import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/themes/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/discussionModel.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/messageModel.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/messageService.dart';
import 'package:space_learn_flutter/core/utils/token_storage.dart';
import '../../../../../themes/layout/nav_bar_lecteur.dart';

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

  Future<void> _loadMessages() async {
    try {
      final token = await TokenStorage.getToken();
      if (token == null) return;
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
        });
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    try {
      final token = await TokenStorage.getToken();
      if (token == null) return;

      _msgController.clear();
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

        setState(() {
          _messages.add(msgToAdd);
        });

        // Recharge silencieusement les messages depuis le serveur pour être 100% à jour
        _loadMessages();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Erreur lors de l'envoi : $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.scaffoldBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Iconsax.arrow_left_2, color: Colors.white, size: 20),
          onPressed: () {
            MainNavBar.mainNavBarKey.currentState?.navigateToCommunaute();
            Navigator.of(context).pop();
          },
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
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                ? Center(
                    child: Text(
                      "Aucun message pour le moment.\nSoyez le premier !",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(color: Colors.white54),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      return _buildMessageItem(msg);
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            color: AppColors.cardBackground,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Écrire un message...",
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                      filled: true,
                      fillColor: AppColors.scaffoldBackground,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: AppColors.secondaryVariant,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Iconsax.send_1,
                      color: Colors.white,
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
          color = Colors.grey;
          break;
        default:
          color = Colors.cyan;
      }
    } else {
      // Simulation fallback
      final int hash = username.hashCode.abs() % 100;
      if (hash > 80) {
        rankTitle = "Maître";
        color = AppColors.yellow;
      } else if (hash > 50) {
        rankTitle = "Érudit";
        color = AppColors.violetLight;
      } else if (hash > 20) {
        rankTitle = "Explorateur";
        color = AppColors.primaryLight;
      } else {
        rankTitle = "Novice";
        color = Colors.grey;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(3),
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
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
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
                    ? const Icon(Icons.person, color: Colors.white54, size: 16)
                    : null,
              ),
              const SizedBox(width: 8),
              Text(
                username,
                style: GoogleFonts.poppins(
                  color: AppColors.secondaryVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              _getUserRankBadge(username, rank: msg.rangUtilisateur),
              const Spacer(),
              Text(
                _timeAgo(msg.creeLe),
                style: GoogleFonts.poppins(color: Colors.white30, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            msg.contenu,
            style: AppTextStyles.body,
          ),
        ],
      ),
    );
  }
}
