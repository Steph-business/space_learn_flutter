import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../services/api_client.dart';
import '../../../utils/api_routes.dart';
import '../model/reversement_model.dart';

/// Erreur métier renvoyée par le portefeuille.
///
/// Le code HTTP porte l'information : l'écran doit distinguer « solde
/// insuffisant » de « numéro Mobile Money manquant » pour guider l'auteur vers
/// la bonne action.
class ReversementException implements Exception {
  final String message;
  final int statusCode;

  const ReversementException(this.message, this.statusCode);

  /// L'auteur n'a pas encore enregistré son numéro Mobile Money.
  bool get numeroManquant => statusCode == 428;

  bool get soldeInsuffisant => statusCode == 409;

  bool get sousLeMinimum => statusCode == 400;

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

  Never _erreur(http.Response reponse, String defaut) {
    String message = defaut;
    try {
      final corps = jsonDecode(reponse.body) as Map<String, dynamic>;
      if (corps['message'] is String) message = corps['message'] as String;
    } catch (_) {}
    throw ReversementException(message, reponse.statusCode);
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
  Future<InfosPaiementModel?> getInfosPaiement(String authToken) async {
    final reponse = await client.get(
      Uri.parse(_infosPaiement),
      headers: _headers(authToken),
    );
    if (reponse.statusCode != 200) return null;

    final data = (jsonDecode(reponse.body) as Map<String, dynamic>)['data'];
    if (data is! Map<String, dynamic>) return null;
    return InfosPaiementModel.fromJson(data);
  }

  /// Enregistre le numéro vers lequel l'auteur sera payé.
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
