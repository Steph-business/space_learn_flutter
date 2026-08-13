import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/utils/app_notifications.dart';
import 'package:space_learn_flutter/core/themes/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:space_learn_flutter/core/themes/app_dimensions.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/book_model.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/discussionModel.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/discussionService.dart';
import 'package:space_learn_flutter/core/utils/token_storage.dart';
import 'forum_messages_page.dart';
import 'salon_noms.dart';

/// Un salon de discussion.
///
/// Le nom n'est pas un parametre : il se deduit de la salle. `book` nul
/// designe le salon global, `book` renseigne le club de lecture d'un ouvrage —
/// c'est exactement ce que le serveur distingue.
///
/// Les parametres `title` et `subtitle` ont ete supprimes plutot que rendus
/// optionnels. Tant qu'ils existaient, chaque appelant ecrivait les siens et
/// la meme salle portait quatre noms selon la porte empruntee ; un parametre
/// optionnel aurait laisse le sixieme ecran en inventer un cinquieme sans que
/// rien ne le signale. Sans eux, c'est impossible a ecrire.
class ForumDiscussionPage extends StatefulWidget {
  final BookModel? book;

  const ForumDiscussionPage({super.key, this.book});

  @override
  State<ForumDiscussionPage> createState() => _ForumDiscussionPageState();
}

class _ForumDiscussionPageState extends State<ForumDiscussionPage> {
  /// Le nom vient de la salle, jamais de l'appelant.
  String get _titre =>
      widget.book == null ? SalonNoms.globalTitre : SalonNoms.clubTitre;

  String get _sousTitre => widget.book?.titre ?? SalonNoms.globalSousTitre;

  final DiscussionService _discussionService = DiscussionService();
  List<Discussion> _discussions = [];
  Map<String, DateTime?> _lastViewedDates = {};
  bool _isLoading = true;

  /// Ce qui a empeche le chargement, s'il a echoue.
  ///
  /// Sans lui, deux pannes se presentaient a l'identique : jeton absent, la
  /// fonction sortait avant de toucher a _isLoading et la roue tournait sans
  /// fin ; reseau coupe, la liste restait vide et la salle paraissait
  /// simplement deserte. Dans les deux cas, rien a lire et rien a faire.
  String? _erreur;

  /// L'onglet qui ne filtre rien.
  static const String _categorieTout = "Tout";

  String _selectedCategory = _categorieTout;

  /// Categories proposees a l'ouverture d'un sujet, et onglets de filtrage.
  ///
  /// Les deux listes n'en font qu'une : un onglet qu'on ne peut pas choisir en
  /// creant un sujet ne renverra jamais rien.
  static const List<String> categoriesSujet = [
    "Théories",
    "Personnages",
    "Animations",
  ];

  final List<String> _categories = [_categorieTout, ...categoriesSujet];

  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

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
    _loadDiscussions();
  }

  Future<void> _loadDiscussions() async {
    if (mounted) setState(() => _erreur = null);
    try {
      final token = await TokenStorage.getToken();
      if (token == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _erreur =
                "Votre session a expiré. Reconnectez-vous pour "
                "retrouver les discussions.";
          });
        }
        return;
      }

      List<Discussion> dbDiscussions;
      if (widget.book != null) {
        dbDiscussions = await _discussionService.getDiscussionsByLivre(
          widget.book!.id,
          token,
        );
      } else {
        dbDiscussions = await _discussionService.getGlobalDiscussions();
      }

      if (mounted) {
        final Map<String, DateTime?> viewedDates = {};
        for (var d in dbDiscussions) {
          viewedDates[d.id] = await TokenStorage.getDiscussionLastViewed(d.id);
        }

        setState(() {
          _discussions = dbDiscussions;
          _lastViewedDates = viewedDates;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _erreur =
              "Les discussions n'ont pas pu être chargées. "
              "Vérifiez votre connexion.";
        });
      }
    }
  }

  Future<void> _createNewDiscussion(String title, String categorie) async {
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

      final newDisc = await _discussionService.createDiscussion(
        type: widget.book != null ? "LIVRE" : "GLOBAL",
        titre: title,
        token: token,
        livreId: widget.book?.id,
        categorie: categorie == _categorieTout ? null : categorie,
      );

      if (mounted) {
        setState(() {
          _discussions.insert(0, newDisc);
        });
        Navigator.pop(context); // close dialog
      }
    } catch (e) {
      if (!mounted) return;
      AppNotifications.showSnackBar(
        context,
        message: 'Erreur : $e',
        isError: true,
      );
    }
  }

  /// Les initiales d'un nom, pour la pastille du participant.
  String _initiales(String nom) {
    final mots = nom
        .trim()
        .split(RegExp(r'\s+'))
        .where((m) => m.isNotEmpty)
        .toList();
    if (mots.isEmpty) return "?";
    if (mots.length == 1) return mots.first.characters.first.toUpperCase();
    return (mots.first.characters.first + mots[1].characters.first)
        .toUpperCase();
  }

  void _showNewDiscussionDialog() {
    final TextEditingController titleController = TextEditingController();
    // La categorie se choisit ici. Sans ce choix, la colonne restait vide et
    // les onglets de filtrage ne pouvaient rien trouver.
    String categorie = categoriesSujet.first;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.cardBackground,
              title: Text(
                "Nouveau sujet",
                style: GoogleFonts.poppins(color: AppColors.textPrimary),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleController,
                    autofocus: true,
                    style: TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: "Titre de la discussion",
                      hintStyle: TextStyle(color: AppColors.textHint),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "Catégorie",
                    style: GoogleFonts.poppins(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: categoriesSujet.map((c) {
                      final choisie = c == categorie;
                      return GestureDetector(
                        onTap: () => setDialogState(() => categorie = c),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: choisie
                                ? AppColors.primary
                                : AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(
                              AppDimensions.radiusPill,
                            ),
                          ),
                          child: Text(
                            c,
                            style: GoogleFonts.poppins(
                              color: choisie
                                  ? AppColors.onAccent
                                  : AppColors.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    "Annuler",
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (titleController.text.trim().isNotEmpty) {
                      _createNewDiscussion(
                        titleController.text.trim(),
                        categorie,
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onAccent,
                  ),
                  child: Text("Créer"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    AppColors.suivreLeTheme(context);
    return Scaffold(
      backgroundColor: AppColors.darkSurface,
      appBar: AppBar(
        backgroundColor: AppColors.darkSurface,
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
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: "Rechercher...",
                  hintStyle: TextStyle(color: AppColors.textHint),
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              )
            : Column(
                children: [
                  Text(
                    _titre.toUpperCase(),
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: 1.2,
                    ),
                  ),
                  // Le sous-titre etait coupe net — « Discussions generales
                  // avec votre communa... » — faute de place dans l'en-tete.
                  // Il tient maintenant sur deux lignes, et son orange passe
                  // en accentInk : secondaryVariant tenait 2,40:1 sur un fond
                  // clair, illisible a onze pixels.
                  Text(
                    _sousTitre,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      height: 1.3,
                      fontWeight: FontWeight.w500,
                      color: AppColors.accentInk,
                    ),
                  ),
                ],
              ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              _isSearching ? Icons.close : Iconsax.search_normal_1,
              color: AppColors.textPrimary,
              size: 20,
            ),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  _searchQuery = "";
                }
              });
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Promotional Header Card
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
                  border: Border.all(
                    color: AppColors.textPrimary.withOpacity(0.05),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.textPrimary.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusSmall,
                        ),
                      ),
                      child:
                          widget.book?.imageCouverture != null &&
                              !widget.book!.imageCouverture!.contains(
                                'example.com',
                              )
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(
                                AppDimensions.radiusSmall,
                              ),
                              child: Image.network(
                                widget.book!.imageCouverture!,
                                fit: BoxFit.cover,
                              ),
                            )
                          : Center(
                              child: Icon(
                                Iconsax.book,
                                color: AppColors.textHint,
                                size: 30,
                              ),
                            ),
                    ),
                    SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Rejoignez la discussion",
                            style: GoogleFonts.poppins(
                              color: AppColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            widget.book == null
                                ? "Lecteurs et auteurs échangent ici."
                                : "Le salon des lecteurs de ce livre.",
                            style: AppTextStyles.grey12,
                          ),
                          SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(
                                AppDimensions.radiusSmall,
                              ),
                            ),
                            // La pastille annoncait « COMMUNAUTE ACTIVE »
                            // meme au-dessus d'un « Aucun sujet de
                            // discussion » : elle se contredisait a une ligne
                            // d'intervalle. Elle compte maintenant ce qu'il y
                            // a reellement.
                            child: Text(
                              _discussions.isEmpty
                                  ? "SALON NEUF"
                                  : _discussions.length == 1
                                  ? "1 SUJET OUVERT"
                                  : "${_discussions.length} SUJETS OUVERTS",
                              style: GoogleFonts.poppins(
                                color: AppColors.accentInk,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Categories
            SizedBox(
              height: 45,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  final bool isSelected = _selectedCategory == cat;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategory = cat),
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.secondaryVariant
                            : AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusPill,
                        ),
                      ),
                      child: Text(
                        cat,
                        style: GoogleFonts.poppins(
                          color: isSelected
                              ? AppColors.onAccent
                              : AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            SizedBox(height: 30),

            // Posts List
            if (_isLoading)
              Center(child: CircularProgressIndicator(color: AppColors.primary))
            else if (_erreur != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 40,
                ),
                child: Column(
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
                        _loadDiscussions();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.onAccent,
                      ),
                      child: const Text("Réessayer"),
                    ),
                  ],
                ),
              )
            else if (_discussions.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 40,
                ),
                child: Text(
                  "Aucun sujet de discussion. Lancez le premier sujet !",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(color: AppColors.textSecondary),
                ),
              )
            else
              Builder(
                builder: (context) {
                  // Le filtre portait sur le TITRE du sujet : « Théories »
                  // ne retenait que ceux dont le titre contenait ce mot, si
                  // bien que trois onglets sur quatre renvoyaient toujours
                  // « aucun sujet ». Il porte maintenant sur la catégorie,
                  // choisie a l'ouverture du sujet.
                  var filtered = _selectedCategory == _categorieTout
                      ? _discussions
                      : _discussions
                            .where(
                              (d) =>
                                  (d.categorie ?? '').toLowerCase() ==
                                  _selectedCategory.toLowerCase(),
                            )
                            .toList();

                  if (_searchQuery.isNotEmpty) {
                    filtered = filtered
                        .where(
                          (d) => d.titre.toLowerCase().contains(
                            _searchQuery.toLowerCase(),
                          ),
                        )
                        .toList();
                  }

                  if (filtered.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 40,
                      ),
                      child: Text(
                        "Aucun sujet ne correspond à cette catégorie.",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: filtered.map((d) {
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  ForumMessagesPage(discussion: d),
                            ),
                          ).then((_) {
                            TokenStorage.saveDiscussionLastViewed(d.id).then((
                              _,
                            ) {
                              _loadDiscussions();
                            });
                          });
                        },
                        child: _buildPostItem(
                          // Le nom de la personne, que le serveur renvoie
                          // depuis toujours dans nom_utilisateur. On affichait
                          // les six premiers caracteres de son identifiant :
                          // « @70f2c9 ». Personne ne se reconnait la-dedans, et
                          // deux participants pouvaient sembler etre le meme.
                          username:
                              (d.nomUtilisateur?.trim().isNotEmpty ?? false)
                              ? d.nomUtilisateur!.trim()
                              : "Anonyme",
                          time: d.creeLe != null
                              ? _timeAgo(d.creeLe!)
                              : "inconnu",
                          title: d.titre,
                          // La description de la discussion. Un texte
                          // identique sur chaque ligne — « Rejoindre la
                          // conversation... » — n'aide pas a choisir laquelle
                          // ouvrir, et donne l'impression que tout se ressemble.
                          content: (d.description?.trim().isNotEmpty ?? false)
                              ? d.description!.trim()
                              : "Aucune description",
                          comments: d.messagesCount ?? d.messages.length,
                          likes: d.likesCount ?? 0,
                          hasNewNotification: (() {
                            if (d.dernierMessageLe == null) return false;
                            final lastViewed = _lastViewedDates[d.id];
                            if (lastViewed == null) return true;
                            return d.dernierMessageLe!.isAfter(lastViewed);
                          })(),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),

            SizedBox(height: 100), // Space for FAB
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        // L'interpolation etait echappee — « \$ » dans une chaine simple — et
        // tous les forums partageaient donc la meme etiquette. Deux forums
        // empiles dans la navigation levaient un conflit de Hero.
        heroTag: 'forum_discussion_fab_${widget.book?.id ?? "global"}',
        onPressed: _showNewDiscussionDialog,
        backgroundColor: AppColors.secondaryVariant,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        ),
        child: Icon(Iconsax.add, color: AppColors.onAccent, size: 28),
      ),
    );
  }

  /// Le rang d'un participant, tel que le serveur le donne.
  ///
  /// Il etait calcule sur `username.hashCode % 100`, et le commentaire du code
  /// l'assumait : « Simulation d'un rang base sur le nom pour la demo ». Des
  /// lecteurs portaient donc publiquement un titre de « Maitre » ou d'« Erudit »
  /// tire de l'orthographe de leur nom, dans un salon ou tout le monde les
  /// voyait. Faute de rang transmis, on n'affiche rien : mieux vaut une
  /// absence qu'une distinction inventee.
  Widget _getUserRankBadge(String? rang) {
    final valeur = rang?.trim() ?? '';
    if (valeur.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.accentInk.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
      ),
      child: Text(
        valeur,
        style: GoogleFonts.poppins(
          color: AppColors.accentInk,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildPostItem({
    required String username,
    required String time,
    required String title,
    required String content,
    required int comments,
    required int likes,
    String? rang,
    bool isAnonymous = false,
    bool hasNewNotification = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Les initiales, et non un portrait.
                  //
                  // La pastille chargeait « i.pravatar.cc/150?u=<nom> » : un
                  // service tiers qui renvoie la photo d'une personne reelle,
                  // choisie au hasard. Chaque participant portait donc le
                  // visage d'un inconnu, et le nom des lecteurs partait chez
                  // un tiers a chaque affichage de la liste.
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isAnonymous
                          ? AppColors.primary
                          : AppColors.accentInk.withValues(alpha: 0.18),
                    ),
                    child: Text(
                      _initiales(isAnonymous ? "Anonyme" : username),
                      style: GoogleFonts.poppins(
                        color: isAnonymous
                            ? AppColors.onAccent
                            : AppColors.accentInk,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            // Sans « @ » : ce que le serveur envoie est un
                            // nom complet, pas un pseudonyme. Et en accentInk,
                            // car secondaryVariant tenait 2,40:1 sur fond
                            // clair — sous le minimum lisible.
                            Flexible(
                              child: Text(
                                username,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  color: AppColors.accentInk,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            _getUserRankBadge(rang),
                            const Spacer(),
                            Text(
                              time,
                              style: GoogleFonts.poppins(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          title,
                          style: GoogleFonts.poppins(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 52, top: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      content,
                      style: AppTextStyles.grey13,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          Iconsax.message_text,
                          size: 20,
                          color: comments > 0
                              ? AppColors.secondaryVariant
                              : AppColors.textSecondary,
                        ),
                        SizedBox(width: 6),
                        Text(
                          comments.toString(),
                          style: GoogleFonts.poppins(
                            color: comments > 0
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                            fontSize: 13,
                            fontWeight: comments > 0
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                        SizedBox(width: 20),
                        Icon(
                          likes > 0 ? Iconsax.heart5 : Iconsax.heart,
                          size: 20,
                          color: likes > 0
                              ? AppColors.error
                              : AppColors.textSecondary,
                        ),
                        SizedBox(width: 6),
                        Text(
                          likes.toString(),
                          style: GoogleFonts.poppins(
                            color: likes > 0
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              Divider(color: AppColors.textPrimary.withOpacity(0.05)),
            ],
          ),
          if (hasNewNotification)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
