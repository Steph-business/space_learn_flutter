import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../services/api_client.dart';
import '../../../utils/api_routes.dart';
import '../model/relationModel.dart';
import 'package:space_learn_flutter/core/utils/message_erreur.dart';

/// Une tranche d'abonnés, et COMBIEN il y en a en tout.
///
/// LE NOMBRE NE SE DÉDUIT PAS DE LA LONGUEUR DE LA LISTE, et c'est le fond de
/// l'affaire. Le serveur (space_learn_livres, modules/relations) rend
/// `meta.total` à côté de `data` sur les deux routes, exactement pour cela ; le
/// mobile ne lisait que `data` et comptait avec `.length` dans cinq écrans.
/// Tant que la liste arrivait entière, les deux chiffres coïncidaient — et ils
/// ne coïncident plus dès qu'une borne existe.
///
/// C'EST CETTE LECTURE-LÀ QUI A PERMIS AU SERVEUR DE REDESCENDRE SON PLAFOND.
/// La liste des abonnés est nominative : elle porte des noms et des photos, et
/// une liste nominative sans borne se télécharge. Le serveur avait posé
/// `PlafondListeNominative = 500` au lieu de la pagination ordinaire UNIQUEMENT
/// parce que cinq écrans du mobile comptaient avec `.length` et auraient
/// affiché un chiffre faux. `total` est lu partout depuis, et ce plafond vaut
/// maintenant `utils.LimiteMax`, c'est-à-dire CENT (space_learn_livres,
/// modules/relations/controller.go:211).
///
/// ET CE N'ÉTAIT PAS QU'UN RÉGLAGE DE CONFORT : à cinq cents, la pagination
/// était cassée par construction. `utils.PageDepuis` plafonne `limit` à cent
/// AVANT de calculer le décalage, si bien qu'une première tranche de cinq cents
/// ne pouvait être redemandée par AUCUNE valeur de `limit` — `?limit=100&page=2`
/// rendait les abonnés 101 à 200, cent doublons à l'écran, et l'abonné n° 501
/// restait hors d'atteinte. La première tranche vaut désormais cent comme les
/// suivantes, et c'est précisément ce qui rend la concaténation continue.
///
/// [total] vaut -1 quand le serveur ne l'a pas rendu — un serveur plus ancien.
/// Jamais 0 : zéro voudrait dire « personne », ce qui est une affirmation.
class PageDeRelations {
  const PageDeRelations({required this.relations, required this.total});

  final List<RelationModel> relations;
  final int total;

  /// Le nombre à afficher, ou nul quand on ne le sait pas.
  ///
  /// Un écran qui n'a pas la réponse doit se taire, pas annoncer zéro : un
  /// échec et une audience nulle codés pareil se lisent « Personne ne vous
  /// suit encore » sur une simple panne.
  int? get nombreConnu => total >= 0 ? total : null;
}

class RelationService {
  final http.Client client;

  RelationService({http.Client? client})
    : client = client ?? ApiClient.instance;

  Future<RelationModel> followUser(String suitId, String authToken) async {
    final url = ApiRoutes.followUser.replaceFirst(':suit_id', suitId);
    final response = await client.post(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $authToken'},
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      return RelationModel.fromJson(data['data'] ?? data);
    } else {
      throw Exception(
        messageDeLaReponse(response, repli: "Impossible de suivre cet auteur."),
      );
    }
  }

  Future<void> unfollowUser(String suitId, String authToken) async {
    final url = ApiRoutes.unfollowUser.replaceFirst(':suit_id', suitId);
    final response = await client.delete(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $authToken'},
    );

    if (response.statusCode != 200) {
      throw Exception(
        messageDeLaReponse(
          response,
          repli: "Impossible de ne plus suivre cet auteur.",
        ),
      );
    }
  }

  /// Les abonnés d'un compte, et leur nombre. Voir [PageDeRelations].
  ///
  /// [page] part à 1 et demande la tranche suivante. ON ENVOIE LES DEUX
  /// PARAMÈTRES ENSEMBLE, et c'est une habitude à garder plutôt qu'une
  /// nécessité : le serveur substitue désormais son plafond quand `limit` est
  /// absent (controller.go:345-348), donc `?page=2` seul enchaîne aussi. Ce
  /// qu'il ne faut plus écrire, c'est la justification d'hier — « le serveur
  /// retomberait sur sa limite par défaut de 10 » —, qui n'est plus vraie.
  ///
  /// Sans aucun paramètre, la réponse est la première tranche :
  /// `PlafondListeNominative` abonnés au plus, soit CENT (space_learn_livres,
  /// modules/relations/controller.go:211, `= utils.LimiteMax`). La même valeur
  /// que les tranches suivantes — c'est ce qui fait que la page 2 reprend
  /// exactement où la page 1 s'arrête.
  ///
  /// UN REFUS DE PLUS SUR LA PAGE 2, ET IL ARRANGE L'ÉCRAN : un jeton qui vient
  /// d'expirer reçoit maintenant 401 « Votre session a expiré. Reconnectez-vous
  /// pour voir la suite de la liste. » là où il recevait 400 « Connectez-vous
  /// pour parcourir la liste complète des abonnés. » — un refus de DROIT
  /// reproché à un connecté, que rien ne pouvait lever. `ApiClient` traite le
  /// 401 tout seul (renouvellement puis rejeu) ; s'il remonte quand même,
  /// `estSessionExpiree` le reconnaît et l'écran mène à la connexion.
  Future<PageDeRelations> getFollowers(
    String utilisateurId, {
    int? limit,
    int? page,
  }) async {
    var url = ApiRoutes.getFollowers.replaceFirst(
      ':utilisateur_id',
      utilisateurId,
    );
    if (limit != null && page != null) {
      url = '$url?limit=$limit&page=$page';
    }
    final response = await client.get(Uri.parse(url));

    if (response.statusCode == 200) {
      return _pageDuCorps(response.body);
    } else {
      throw Exception(
        messageDeLaReponse(
          response,
          repli: "Impossible de charger les abonnés.",
        ),
      );
    }
  }

  /// Les comptes qu'un compte suit, et leur nombre. Voir [PageDeRelations].
  ///
  /// Mêmes bornes et même pagination que [getFollowers] : cent par tranche
  /// depuis que `PlafondListeNominative` vaut `utils.LimiteMax`. Qui a besoin
  /// de l'ensemble — et non d'une tranche — appelle [getToutesLesRelations].
  Future<PageDeRelations> getFollowing(
    String utilisateurId, {
    int? limit,
    int? page,
  }) async {
    var url = ApiRoutes.getFollowing.replaceFirst(
      ':utilisateur_id',
      utilisateurId,
    );
    if (limit != null && page != null) {
      url = '$url?limit=$limit&page=$page';
    }
    final response = await client.get(Uri.parse(url));

    if (response.statusCode == 200) {
      return _pageDuCorps(response.body);
    } else {
      throw Exception(
        messageDeLaReponse(
          response,
          repli: "Impossible de charger les abonnements.",
        ),
      );
    }
  }

  /// TOUS les comptes qu'un compte suit, tranche après tranche.
  ///
  /// POURQUOI CETTE BOUCLE EXISTE. L'accueil du lecteur construit l'ensemble
  /// des identifiants suivis pour décider, sur chaque carte d'auteur, entre
  /// « Suivre » et « Abonné ». Il lisait une seule tranche : tant que le
  /// serveur en rendait cinq cents, personne ne s'en apercevait ; à cent, un
  /// lecteur qui suit davantage d'auteurs voit « Suivre » sur des auteurs qu'il
  /// suit déjà. L'appui rend alors un 409 que l'écran rattrape proprement —
  /// rien ne casse — mais le bouton a menti jusqu'au premier appui.
  ///
  /// LE TOTAL VIENT DE `meta.total`, JAMAIS DE LA LONGUEUR : voir
  /// [PageDeRelations]. Quand le serveur ne le rend pas (serveur plus ancien),
  /// on garde ce qu'on a plutôt que de tourner à l'aveugle.
  ///
  /// DEUX GARDE-FOUS, parce qu'une boucle qui interroge le réseau ne doit pas
  /// pouvoir tourner sans fin : une tranche vide arrête tout — le serveur n'a
  /// plus rien à donner, quoi qu'annonce le total — et [pagesAuPlus] borne le
  /// nombre d'allers-retours. Au-delà, on rend ce qu'on a obtenu, avec le total
  /// que le serveur a dit : mieux vaut un ensemble incomplet et un nombre juste
  /// qu'un écran qui n'ouvre jamais.
  Future<PageDeRelations> getToutesLesRelations(
    String utilisateurId, {
    int pagesAuPlus = 20,
  }) async {
    final premiere = await getFollowing(utilisateurId);
    final total = premiere.nombreConnu;
    if (total == null || premiere.relations.length >= total) return premiere;

    // LA TAILLE DE TRANCHE VIENT DU SERVEUR, ET NON D'UN CHIFFRE ÉCRIT ICI.
    //
    // Il y avait un paramètre `parTranche = 100` que le PREMIER appel
    // n'utilisait pas : celui-ci part sans `limit`, donc le serveur applique
    // son propre plafond, puis les pages suivantes étaient demandées avec le
    // chiffre du paramètre. Les deux ne coïncidaient que par hasard —
    // `PlafondListeNominative` vaut cent aujourd'hui, et le défaut valait cent.
    // Toute autre valeur décalait la suite : `parTranche: 50` redemandait à
    // partir du cinquantième et rendait deux fois les entrées 51 à 100 ;
    // `parTranche: 200` sautait les entrées 101 à 200, `utils.PageDepuis`
    // replafonnant la limite à cent mais pas le décalage. Un paramètre qui ne
    // peut avoir qu'une seule valeur juste n'est pas un réglage, c'est un
    // piège : il est parti.
    //
    // Ce que le serveur vient de rendre EST la taille de tranche, quel que soit
    // son plafond du jour — cent pour un appelant connu, vingt-quatre pour un
    // inconnu (modules/relations/controller.go, PlafondAnonyme), et autre chose
    // demain sans que ce fichier ait à le savoir.
    final tranche = premiere.relations.length;
    if (tranche <= 0) return premiere;

    final tout = [...premiere.relations];
    var page = 1;
    while (tout.length < total && page < pagesAuPlus) {
      page += 1;
      final suivante = await getFollowing(
        utilisateurId,
        limit: tranche,
        page: page,
      );
      if (suivante.relations.isEmpty) break;
      tout.addAll(suivante.relations);
    }
    return PageDeRelations(relations: tout, total: total);
  }

  /// `data` et `meta.total`, lus ensemble parce qu'ils vont ensemble.
  ///
  /// `meta` est absent d'un serveur plus ancien : le total vaut alors -1, et
  /// [PageDeRelations.nombreConnu] rend nul plutôt que zéro.
  PageDeRelations _pageDuCorps(String corps) {
    final Map<String, dynamic> responseData = jsonDecode(corps);
    final List<dynamic> data = responseData['data'] ?? [];
    final relations = data.map((json) => RelationModel.fromJson(json)).toList();

    final meta = responseData['meta'];
    final brut = meta is Map ? meta['total'] : null;
    final total = brut is num ? brut.toInt() : int.tryParse('$brut') ?? -1;

    return PageDeRelations(relations: relations, total: total);
  }

  Future<List<dynamic>> getCommunityEvents(String authToken) async {
    final response = await client.get(
      Uri.parse(ApiRoutes.communityEvents),
      headers: {'Authorization': 'Bearer $authToken'},
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = jsonDecode(response.body);
      return responseData['data'] ?? responseData;
    } else {
      throw Exception(
        messageDeLaReponse(
          response,
          repli: "Impossible de charger les événements.",
        ),
      );
    }
  }
}
