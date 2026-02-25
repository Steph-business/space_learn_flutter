import 'package:flutter/material.dart';
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

        // On récupère le nom/photo d'un message précédent si possible (même utilsateur)
        for (var m in _messages) {
          if (m.utilisateurId == newMessage.utilisateurId &&
              m.nomUtilisateur != null) {
            nom = m.nomUtilisateur;
            photo = m.photoProfil;
            break;
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
        );

        setState(() {
          _messages.add(msgToAdd);
        });

        // Recharge silencieusement les messages depuis le serveur pour être 100% à jour
        _loadMessages();
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Erreur lors de l'envoi : $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Iconsax.arrow_left_2, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.discussion.titre,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
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
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 12,
                                  backgroundColor: const Color(0xFF0F172A),
                                  backgroundImage:
                                      (msg.photoProfil != null &&
                                          msg.photoProfil!.isNotEmpty)
                                      ? NetworkImage(msg.photoProfil!)
                                      : null,
                                  child:
                                      (msg.photoProfil == null ||
                                          msg.photoProfil!.isEmpty)
                                      ? const Icon(
                                          Icons.person,
                                          color: Colors.white54,
                                          size: 16,
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  msg.nomUtilisateur?.isNotEmpty == true
                                      ? msg.nomUtilisateur!
                                      : 'Utilisateur',
                                  style: GoogleFonts.poppins(
                                    color: const Color(0xFF0EA5E9),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  _timeAgo(msg.creeLe),
                                  style: GoogleFonts.poppins(
                                    color: Colors.white30,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              msg.contenu,
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF1E293B),
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
                      fillColor: const Color(0xFF0F172A),
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
                      color: Color(0xFF0EA5E9),
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
}
