import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../services/api_client.dart';
import '../../../utils/api_routes.dart';
import '../../../utils/message_erreur.dart';
import '../model/reversement_model.dart';

/// Erreur métier renvoyée par le portefeuille.
///
/// UN SEUL CODE EST LU, LE 428, ET LES AUTRES N'ONT RIEN À DIRE DE PLUS QUE LE
/// MESSAGE DU SERVEUR. La demande de retrait a désormais DEUX 409 de natures
/// différentes : le solde insuffisant, et la carence de vingt-quatre heures qui
/// suit un changement de destination — « Le numéro qui reçoit vos virements a
/// été changé récemment. Par sécurité, aucun retrait n'est possible avant le
/// JJ/MM/AAAA à HHhMM… » (`DelaiCarenceNumero`, space_learn_livres). Un écran
/// qui aurait cru lire « solde insuffisant » sur le second aurait proposé de
/// baisser le montant à quelqu'un dont le solde est intact.
///
/// DANS LES DEUX CAS LE GESTE EST LE MÊME, et c'est pourquoi les deux getters
/// qui prétendaient les distinguer ont été retirés : afficher le message du
/// serveur TEL QUEL, sans bouton « Réessayer » — réessayer avant l'heure dite
/// ne peut pas aboutir. `sousLeMinimum` a suivi `soldeInsuffisant` dans ce
/// tour-ci : `grep` ne lui trouvait aucun appelant, et son bloc de
/// documentation parlait du 409 quand la ligne suivante testait le 400.
///
/// Le 401, lui, ne remonte plus l'anglais du serveur des livres : [_erreur]
/// passe par `messageDeLaReponse`. Voir sa note.
class ReversementException implements Exception {
  final String message;
  final int statusCode;

  const ReversementException(this.message, this.statusCode);

  /// L'auteur n'a pas encore enregistré son numéro Mobile Money.
  ///
  /// SEUL CODE ENCORE LU, et c'est le seul qui appelle un geste à part :
  /// l'écran emmène là où le numéro se saisit. Deux getters l'accompagnaient,
  /// `soldeInsuffisant` puis `sousLeMinimum` ; les deux ont été retirés, le
  /// second dans ce tour-ci, et pour la même raison — voir ci-dessous.
  bool get numeroManquant => statusCode == 428;

  @override
  String toString() => message;
}

/// Accès au portefeuille de l'auteur connecté.
///
/// L'identité vient du token : aucune route ne prend d'identifiant d'auteur en
/// paramètre, un auteur ne peut donc consulter et retirer que ses propres gains.
class ReversementService {
  final http.Client client;

  ReversementService({http.Client? client})
    : client = client ?? ApiClient.instance;

  // Déclarées ici plutôt que dans ApiRoutes pour ne pas toucher un fichier en
  // cours de modification ; à déplacer dans ApiRoutes à l'occasion.
  static final String _base = '${ApiRoutes.baseUrlsGin}/api/reversements';
  static String get _portefeuille => '$_base/me';
  static String get _retraits => '$_base/me/retraits';
  static String get _infosPaiement => '$_base/me/infos-paiement';

  Map<String, String> _headers(String token, {bool json = false}) => {
    if (json) 'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  /// La phrase à afficher pour une réponse en échec, et le code qui l'a
  /// produite.
  ///
  /// ELLE PASSE PAR `messageDeLaReponse`, ET C'EST TOUT LE CORRECTIF. Cette
  /// méthode lisait `corps['message']` toute seule, sans filtre et sans le cas
  /// du 401. Trois conséquences, toutes mesurables sur les deux écrans de
  /// l'argent :
  ///
  ///   1. Sur un 401, le middleware du serveur des livres répond EN ANGLAIS —
  ///      « Authorization header required », « Bearer token required »,
  ///      « Invalid token » (space_learn_livres, middleware/auth.go). Ces
  ///      chaînes arrivaient telles quelles dans une application française,
  ///      dans un message furtif et sous le formulaire de saisie du numéro.
  ///   2. Aucune n'est reconnue par `estSessionExpiree` : `payout_info_page`
  ///      en concluait « ce n'est pas la session » et offrait « Réessayer »
  ///      sur un jeton mort — le seul bouton qui ne peut pas aboutir.
  ///   3. Une réponse portant sa phrase sous `error` plutôt que `message`
  ///      était perdue, alors que les deux serveurs écrivent l'un ou l'autre.
  ///
  /// `messageDeLaReponse` répond aux trois : sur un 401 il rend
  /// [phraseSessionExpiree] — celle-là même qu'`estSessionExpiree`
  /// reconnaît —, il lit les quatre clés usuelles, et il écarte ce qui n'a pas
  /// été écrit pour être lu.
  Never _erreur(http.Response reponse, String defaut) {
    throw ReversementException(
      messageDeLaReponse(reponse, repli: defaut),
      reponse.statusCode,
    );
  }

  /// Solde, historique des ventes créditées et demandes de retrait.
  Future<Portefeuille> getPortefeuille(
    String authToken, {
    int limit = 50,
  }) async {
    final uri = Uri.parse(
      _portefeuille,
    ).replace(queryParameters: {'limit': '$limit'});

    final reponse = await client.get(uri, headers: _headers(authToken));
    if (reponse.statusCode != 200) {
      _erreur(reponse, 'Échec du chargement du portefeuille');
    }

    final corps = jsonDecode(reponse.body) as Map<String, dynamic>;
    final data = corps['data'];
    if (data is! Map<String, dynamic>) return Portefeuille.vide;
    return Portefeuille.fromJson(data);
  }

  /// Demande un virement vers le Mobile Money enregistré.
  ///
  /// Quatre refus possibles, et UN SEUL appelle un geste à part : le 428, quand
  /// aucun numéro n'est enregistré — l'écran y emmène. Les trois autres — 400
  /// sous le minimum, 409 solde insuffisant, 409 de carence après un
  /// changement de numéro — s'affichent avec le message du serveur, sans
  /// bouton « Réessayer ». Voir [ReversementException].
  ///
  /// Le 409 de carence est le seul qui se voit venir : l'écran des ventes et
  /// celui du numéro l'annoncent à partir de
  /// [InfosPaiementModel.finDeCarence], AVANT que l'auteur ne demande son
  /// argent.
  Future<(RetraitModel, SoldeAuteur)> demanderRetrait({
    required String authToken,
    required double montant,
  }) async {
    final reponse = await client.post(
      Uri.parse(_retraits),
      headers: _headers(authToken, json: true),
      body: jsonEncode({'montant': montant}),
    );

    if (reponse.statusCode != 200 && reponse.statusCode != 201) {
      _erreur(reponse, 'Échec de la demande de retrait');
    }

    final data =
        (jsonDecode(reponse.body) as Map<String, dynamic>)['data']
            as Map<String, dynamic>;
    return (
      RetraitModel.fromJson(data['retrait'] as Map<String, dynamic>),
      SoldeAuteur.fromJson(data['solde'] as Map<String, dynamic>),
    );
  }

  /// Annule une demande encore en attente. Le montant retourne au solde.
  Future<SoldeAuteur> annulerRetrait({
    required String authToken,
    required String retraitId,
  }) async {
    final reponse = await client.delete(
      Uri.parse('$_retraits/$retraitId'),
      headers: _headers(authToken),
    );

    if (reponse.statusCode != 200) {
      _erreur(reponse, "Échec de l'annulation du retrait");
    }

    final data =
        (jsonDecode(reponse.body) as Map<String, dynamic>)['data']
            as Map<String, dynamic>;
    return SoldeAuteur.fromJson(data['solde'] as Map<String, dynamic>);
  }

  /// Coordonnées Mobile Money enregistrées.
  ///
  /// Le serveur répond 200 même sans enregistrement, en proposant le téléphone
  /// du compte avec `par_defaut: true`.
  ///
  /// UNE PANNE N'EST PAS UNE ABSENCE, ET ICI LA CONFUSION DÉPLAÇAIT DE
  /// L'ARGENT. Cette méthode rendait `null` sur TOUT code différent de 200 :
  /// l'écran des ventes en concluait « aucun numéro enregistré » et affichait
  /// la bannière qui pousse à en saisir un, pendant que la page de saisie
  /// ouvrait un formulaire vide. Il suffisait d'enregistrer pour changer la
  /// destination des virements — et pour armer la carence de vingt-quatre
  /// heures sur un geste qu'une panne venait de suggérer.
  ///
  /// Le serveur a fermé sa moitié du trou : il ne répond plus « Aucune
  /// coordonnée enregistrée » sur une erreur de lecture mais 500 « Vos
  /// coordonnées de paiement n'ont pas pu être lues » (space_learn_livres,
  /// modules/reversement/controller.go). Encore faut-il que le client cesse de
  /// traduire ce 500 en `null`. Elle lève donc, et les deux écrans montrent le
  /// message du serveur avec un bouton « Réessayer » — c'est une panne, elle
  /// se réessaie.
  ///
  /// `null` ne subsiste que pour un 200 dont le corps n'a pas la forme
  /// attendue : là non plus on ne sait rien, mais le serveur, lui, a dit que
  /// tout allait bien.
  Future<InfosPaiementModel?> getInfosPaiement(String authToken) async {
    final reponse = await client.get(
      Uri.parse(_infosPaiement),
      headers: _headers(authToken),
    );
    if (reponse.statusCode != 200) {
      _erreur(reponse, "Vos coordonnées de paiement n'ont pas pu être lues.");
    }

    final data = (jsonDecode(reponse.body) as Map<String, dynamic>)['data'];
    if (data is! Map<String, dynamic>) return null;
    return InfosPaiementModel.fromJson(data);
  }

  /// Enregistre le numéro vers lequel l'auteur sera payé.
  ///
  /// DEUX REFUS DE SAISIE, ET LE SECOND EST NOUVEAU. Le serveur rend 400
  /// « Le numéro doit comporter au moins 6 chiffres. Vérifiez l'indicatif et le
  /// numéro saisis. » (space_learn_livres,
  /// modules/reversement/controller.go:371) et, depuis ce tour, 400
  /// « L'indicatif du pays doit être écrit en chiffres, par exemple 225 pour la
  /// Côte d'Ivoire. » (controller.go:347-352) quand la saisie ne porte aucun
  /// chiffre ou plus de quatre. Il REFUSE plutôt que de corriger en silence :
  /// un indicatif abîmé, c'est un virement qui part vers « ++225 » ou vers le
  /// mauvais pays.
  ///
  /// Les deux s'affichent avec le message du serveur, SANS vider le formulaire
  /// et sans bouton « Réessayer » : la saisie reste à l'écran, c'est elle qu'il
  /// faut corriger. Le « + » de tête et les « 00 » sont nettoyés côté serveur
  /// (`IndicatifNormalise`), donc « +225 » est accepté et rangé « 225 » — mais
  /// aucun écran ne doit enseigner cette forme-là.
  ///
  /// LA RÉPONSE PORTE `numero_change_le`, et c'est de LUI que vient la date de
  /// carence annoncée après l'enregistrement — jamais d'une horloge posée sur
  /// le téléphone. Voir [InfosPaiementModel.finDeCarence].
  Future<InfosPaiementModel> setInfosPaiement({
    required String authToken,
    required String prefix,
    required String telephone,
    String? nomComplet,
    String? email,
  }) async {
    final reponse = await client.put(
      Uri.parse(_infosPaiement),
      headers: _headers(authToken, json: true),
      body: jsonEncode({
        'prefix': prefix,
        'telephone': telephone,
        if (nomComplet != null && nomComplet.isNotEmpty)
          'nom_complet': nomComplet,
        if (email != null && email.isNotEmpty) 'email': email,
      }),
    );

    if (reponse.statusCode != 200) {
      _erreur(reponse, "Échec de l'enregistrement du numéro");
    }

    final data =
        (jsonDecode(reponse.body) as Map<String, dynamic>)['data']
            as Map<String, dynamic>;
    return InfosPaiementModel.fromJson(data);
  }
}
