import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';

import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/themes/app_dimensions.dart';
import 'package:space_learn_flutter/core/utils/message_erreur.dart';
import 'package:space_learn_flutter/core/utils/profile_image_helper.dart';
import 'package:space_learn_flutter/core/utils/token_storage.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/dm_service.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/conversation_model.dart';
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

  @override
  void initState() {
    super.initState();
    _charger();
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

      final conversations = await _service.getConversations(token);
      if (!mounted) return;
      setState(() {
        _conversations = conversations;
        _chargement = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _erreur = messageLisible(
          e,
          repli: "Vos conversations n'ont pas pu être chargées.",
        );
      });
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
              icone: Iconsax.warning_2,
              titre: "Conversations indisponibles",
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
            child: ElevatedButton(
              onPressed: _charger,
              child: const Text("Réessayer"),
            ),
          ),
        ],
      ],
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
