import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/api_client.dart';
import '../../../utils/api_routes.dart';
import '../../../utils/token_storage.dart';
import '../model/paymentModel.dart';
import '../model/authorRevenueModel.dart';
import 'package:space_learn_flutter/core/utils/message_erreur.dart';

/// Résultat du lancement d'un paiement CinetPay
class CinetpayInitResult {
  final PaymentModel paiement;
  final String paymentUrl;

  CinetpayInitResult({required this.paiement, required this.paymentUrl});
}

/// Statut retourné lors de la vérification d'un paiement CinetPay.
///
/// Le serveur ne rend que DEUX statuts — "ACCEPTED" ou "FAILED_OR_PENDING"
/// (modules/paiement/controller.go, GetCinetpayStatus). L'ancienne version
/// annonçait aussi "REFUSED"/"PENDING" et lisait payment_method, amount et
/// currency : aucune de ces valeurs n'existe dans la réponse, elles étaient
/// donc toujours nulles. Le statut réel de la passerelle (REFUSED, EXPIRED…)
/// ne voyage que dans le champ `message` — « statut du paiement CinetPay :
/// REFUSED » — et dans `paiement.statut` : c'est d'eux que se déduit l'issue,
/// comme le fait déjà le site web (Stepace_learn_web/src/lib/paiement.ts).
class CinetpayStatusResult {
  final String status; // "ACCEPTED" ou "FAILED_OR_PENDING", rien d'autre
  final String? message; // le message brut du serveur, porte le statut CinetPay
  final String? paiementStatut; // "en_attente" | "confirme" | "echoue"
  final PaymentModel? paiement; // null si le serveur n'a pas pu joindre CinetPay

  CinetpayStatusResult({
    required this.status,
    this.message,
    this.paiementStatut,
    this.paiement,
  });

  /// Les statuts CinetPay qui closent définitivement une transaction.
  /// Recopiés de `StatutsTerminaux` (modules/paiement/service.go) — même liste,
  /// même retenue : tout le reste laisse le paiement en attente, car conclure à
  /// l'échec d'un paiement peut-être réglé est irréversible pour l'acheteur.
  static const Set<String> _statutsTerminaux = {
    'REFUSED',
    'CANCELED',
    'CANCELLED',
    'EXPIRED',
    'FAILED',
  };

  bool get estAccepte => status.toUpperCase() == 'ACCEPTED';

  /// Le statut brut de la passerelle, extrait du message du serveur.
  /// Vide si le serveur n'a pas pu joindre CinetPay (le message est alors une
  /// erreur technique qui ne dit rien du paiement).
  String get statutOperateur {
    final trouve = RegExp(
      r'statut du paiement cinetpay\s*:\s*([a-z_]+)',
      caseSensitive: false,
    ).firstMatch(message ?? '');
    return trouve == null ? '' : trouve.group(1)!.toUpperCase();
  }

  /// L'opérateur a-t-il définitivement refusé ce paiement ?
  /// `paiement.statut == "echoue"` quand la réconciliation du serveur a déjà
  /// tranché ; sinon le statut de la passerelle fait foi.
  bool get definitivementEchoue {
    if (estAccepte) return false;
    if (paiementStatut == 'echoue') return true;
    return _statutsTerminaux.contains(statutOperateur);
  }

  /// Le montant officiel relu en base par le serveur — le seul à afficher.
  /// Null quand la réponse ne porte pas de paiement.
  double? get montantServeur {
    final m = paiement?.montant;
    return (m != null && m > 0) ? m : null;
  }
}

/// Ce que la garde anti-double-débit conclut d'une transaction déjà ouverte.
///
/// TROIS écrans lancent un paiement — la fiche du livre, la fin d'extrait de la
/// liseuse et l'écran de paiement — et chacun portait sa propre version de
/// cette décision. Elles avaient fini par se contredire : sur une vérification
/// en panne, deux laissaient passer l'achat et le troisième le refusait ; un
/// paiement REFUSÉ par l'opérateur était encore annoncé « en cours, attendez la
/// confirmation ». Le même lecteur, sur le même livre, pouvait acheter ou non
/// selon l'écran d'où il partait. La règle vit désormais ici, une seule fois.
enum VerdictPaiement {
  /// Rien ne s'oppose à un nouveau paiement : aucune transaction ouverte, la
  /// précédente est close, ou la vérification elle-même est en panne.
  ///
  /// Laisser passer est l'arbitrage RETENU pour la panne : refuser un achat
  /// parce qu'on n'a pas pu lire la LISTE des paiements fermerait la boutique,
  /// et le serveur reste seul à accorder le livre — son idempotence par
  /// merchant_transaction_id ne le donne pas deux fois.
  laisserPasser,

  /// Le livre est DÉJÀ acquis : la transaction précédente a abouti.
  dejaAcquis,

  /// Une transaction reste ouverte et non tranchée : ni la garde ni l'écran ne
  /// peuvent décider à la place du lecteur, seul à savoir s'il a réglé.
  aConfirmerParLaPersonne,
}

/// Le verdict rendu par [PaymentService.examinerTransactionOuverte], avec de
/// quoi rédiger le message de l'écran.
///
/// Un verdict, jamais une interface : c'est l'écran qui décide d'ouvrir un
/// dialogue, un bandeau, ou de ne rien montrer du tout.
class GardePaiement {
  final VerdictPaiement verdict;

  /// La référence de la transaction en cause. Vide s'il n'y en a aucune.
  final String transactionId;

  /// Quand elle a été ouverte, si le serveur l'a dit.
  final DateTime? ouverteLe;

  /// Son montant tel que le serveur l'a enregistré (0 s'il est inconnu) — le
  /// seul à afficher, le prix de la fiche pouvant être périmé.
  final double montant;

  /// La vérification n'a PAS abouti (réseau, serveur, quota) : un
  /// [VerdictPaiement.laisserPasser] est alors une tolérance, pas une preuve.
  final bool verificationImpossible;

  const GardePaiement({
    required this.verdict,
    this.transactionId = '',
    this.ouverteLe,
    this.montant = 0,
    this.verificationImpossible = false,
  });
}

class PaymentService {
  final http.Client client;

  PaymentService({http.Client? client}) : client = client ?? ApiClient.instance;

  Future<PaymentModel> createPayment(
    PaymentModel payment,
    String authToken,
  ) async {
    final response = await client.post(
      Uri.parse(ApiRoutes.payments),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $authToken',
      },
      body: jsonEncode(payment.toJson()),
    );

    if (response.statusCode == 201) {
      final Map<String, dynamic> responseData = jsonDecode(response.body);
      final dynamic data = responseData['data'] ?? responseData;

      // Handle the case where the backend returns {"paiement": ..., "livre": ...}
      if (data is Map<String, dynamic> && data.containsKey('paiement')) {
        return PaymentModel.fromJson(data['paiement']);
      }

      return PaymentModel.fromJson(data);
    } else {
      throw Exception(
        messageDeLaReponse(
          response,
          repli: "Le paiement n'a pas pu être lancé.",
        ),
      );
    }
  }

  /// Lance un paiement via CinetPay et retourne l'URL de paiement + le paiement créé
  Future<CinetpayInitResult> initiateCinetpayPayment({
    required String livreId,
    required double montant,
    required String authToken,
    String? customerName,
    String? customerEmail,
    String? customerPhone,
  }) async {
    final body = <String, dynamic>{
      'livre_id': livreId,
      'methode_paiement': 'cinetpay',
      'montant': montant,
    };
    if (customerName != null && customerName.isNotEmpty) {
      body['customer_name'] = customerName;
    }
    if (customerEmail != null && customerEmail.isNotEmpty) {
      body['customer_email'] = customerEmail;
    }
    if (customerPhone != null && customerPhone.isNotEmpty) {
      // `phone_number`, pas `customer_phone` : c'est le nom que lit le binding
      // Go (controller.go : PhoneNumber `json:"phone_number"`). Sous l'ancien
      // nom, le numéro partait dans le vide sans qu'aucune erreur le signale,
      // et CinetPay le redemandait sur sa page.
      body['phone_number'] = customerPhone;
    }

    final response = await client.post(
      Uri.parse(ApiRoutes.payments),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $authToken',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 201) {
      final Map<String, dynamic> responseData = jsonDecode(response.body);
      final dynamic data = responseData['data'] ?? responseData;

      // `paiement` est EXIGÉ, plus jamais remplacé par l'enveloppe.
      //
      // `PaymentModel.fromJson(data['paiement'] ?? data)` construisait le
      // modèle sur {paiement, payment_url, montant} dès que la clé manquait :
      // transaction_id vide, montant lu par hasard sur la clé `montant` du même
      // niveau. Le lecteur partait alors payer avec une référence vide —
      // /cinetpay/status/ interrogé sur rien, aucune trace mémorisable, et plus
      // aucun écran capable de retrouver ce paiement ni de le citer en
      // réclamation. Mieux vaut refuser de lancer que lancer à l'aveugle.
      if (data is Map<String, dynamic> &&
          data['paiement'] is Map<String, dynamic>) {
        final paiement = PaymentModel.fromJson(
          data['paiement'] as Map<String, dynamic>,
        );
        final paymentUrl = data['payment_url'] as String? ?? '';
        if (paiement.transactionId.isEmpty || paymentUrl.isEmpty) {
          throw Exception(
            "Le paiement n'a pas pu être lancé. Réessayez dans un instant.",
          );
        }
        return CinetpayInitResult(paiement: paiement, paymentUrl: paymentUrl);
      }
      throw Exception(
        "Le paiement n'a pas pu être lancé. Réessayez dans un instant.",
      );
    } else {
      final decoded = jsonDecode(response.body);
      final msg = decoded['error'] ?? decoded['message'] ?? response.body;
      throw Exception('Erreur CinetPay : $msg');
    }
  }

  /// Vérifie le statut d'un paiement CinetPay après que l'utilisateur ait payé
  Future<CinetpayStatusResult> getCinetpayStatus(
    String transactionId,
    String authToken,
  ) async {
    final url = ApiRoutes.cinetpayStatus.replaceFirst(
      ':transactionId',
      transactionId,
    );
    final response = await client.get(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $authToken'},
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = jsonDecode(response.body);
      final dynamic data = responseData['data'] ?? responseData;

      if (data is Map<String, dynamic>) {
        final status =
            (data['status'] ?? data['Status'] ?? 'UNKNOWN') as String;
        // `"paiement": null` est une réponse LÉGITIME : quand le serveur ne
        // peut pas joindre CinetPay, il rend paiement nil dans un 200
        // (controller.go:176-181). `containsKey` était vrai pour ce null et
        // `PaymentModel.fromJson(null)` levait un TypeError — le bouton
        // « J'ai payé » devenait muet. On ne parse que si c'est un objet.
        PaymentModel? paiement;
        String? paiementStatut;
        final paiementBrut = data['paiement'];
        if (paiementBrut is Map<String, dynamic>) {
          paiement = PaymentModel.fromJson(paiementBrut);
          // `statut` est lu à même la réponse : PaymentModel ne le porte pas,
          // et c'est lui qui dit qu'une commande est définitivement échouée.
          paiementStatut = paiementBrut['statut']?.toString();
        }
        return CinetpayStatusResult(
          status: status,
          message: responseData['message']?.toString(),
          paiementStatut: paiementStatut,
          paiement: paiement,
        );
      }
      throw Exception('Format de statut CinetPay inattendu');
    } else {
      throw Exception(
        messageDeLaReponse(
          response,
          repli: "Impossible de vérifier ce paiement.",
        ),
      );
    }
  }

  Future<List<PaymentModel>> getUserPayments(String authToken) async {
    final response = await client.get(
      Uri.parse(ApiRoutes.payments),
      headers: {'Authorization': 'Bearer $authToken'},
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = jsonDecode(response.body);
      final List<dynamic> data = responseData['data'] ?? [];
      return data.map((json) => PaymentModel.fromJson(json)).toList();
    } else {
      throw Exception(
        messageDeLaReponse(
          response,
          repli: "Impossible de charger vos paiements.",
        ),
      );
    }
  }

  /// Faut-il ouvrir un NOUVEAU paiement pour ce livre ?
  ///
  /// La garde consulte les deux traces d'une transaction déjà ouverte :
  ///   - la mémoire locale ([TransactionEnCoursStore]), écrite juste avant
  ///     d'envoyer le lecteur payer — elle survit à une liste serveur en panne ;
  ///   - la liste des paiements du serveur, restreinte à ce livre et aux
  ///     dernières 24 h.
  ///
  /// Une commande que le serveur a déjà marquée `echoue` n'oppose rien : elle
  /// est écartée d'emblée, sans quoi un refus interdirait de réessayer.
  ///
  /// Aucune exception ne sort d'ici : une panne rend
  /// [VerdictPaiement.laisserPasser] avec `verificationImpossible`.
  Future<GardePaiement> examinerTransactionOuverte({
    required String userId,
    required String livreId,
    required String authToken,
  }) async {
    if (livreId.isEmpty) {
      return const GardePaiement(verdict: VerdictPaiement.laisserPasser);
    }

    ({String transactionId, double montant})? locale;
    try {
      locale = await TransactionEnCoursStore.enCours(
        userId: userId,
        livreId: livreId,
      );
    } catch (_) {
      // Le stockage local n'est pas une raison d'empêcher un achat.
      locale = null;
    }

    PaymentModel? derniere;
    var verificationImpossible = false;
    try {
      final paiements = await getUserPayments(authToken);
      final surCeLivre =
          paiements
              .where(
                (p) =>
                    p.livreId == livreId &&
                    p.transactionId.isNotEmpty &&
                    // Une commande déjà refusée en base n'oppose rien.
                    p.statut != 'echoue' &&
                    p.creeLe != null &&
                    DateTime.now().difference(p.creeLe!) <
                        TransactionEnCoursStore.dureeMax,
              )
              .toList()
            ..sort((a, b) => b.creeLe!.compareTo(a.creeLe!));

      // Une commande CONFIRMÉE tranche, même si une autre traîne encore en
      // attente : le livre est accordé. On regarde donc toute la liste et pas
      // seulement la plus récente — un second essai abandonné ne doit pas
      // masquer le premier, qui a abouti.
      final confirmees = surCeLivre.where((p) => p.statut == 'confirme');
      if (confirmees.isNotEmpty) {
        final p = confirmees.first;
        await _oublierTrace(userId, livreId);
        return GardePaiement(
          verdict: VerdictPaiement.dejaAcquis,
          transactionId: p.transactionId,
          ouverteLe: p.creeLe,
          montant: p.montant,
        );
      }
      derniere = surCeLivre.isEmpty ? null : surCeLivre.first;
    } catch (_) {
      // La LISTE est en panne : elle n'apprend rien, ni dans un sens ni dans
      // l'autre. La trace locale, si elle existe, reste exploitable.
      verificationImpossible = true;
    }

    final reference = derniere?.transactionId ?? locale?.transactionId ?? '';
    if (reference.isEmpty) {
      return GardePaiement(
        verdict: VerdictPaiement.laisserPasser,
        verificationImpossible: verificationImpossible,
      );
    }

    final CinetpayStatusResult statut;
    try {
      // Le serveur relit le statut chez la passerelle et, si le paiement a
      // abouti, accorde le livre au passage (réconciliation à la volée).
      statut = await getCinetpayStatus(reference, authToken);
    } catch (_) {
      // Statut invérifiable : on LAISSE PASSER. Voir [VerdictPaiement].
      return GardePaiement(
        verdict: VerdictPaiement.laisserPasser,
        transactionId: reference,
        ouverteLe: derniere?.creeLe,
        montant: derniere?.montant ?? locale?.montant ?? 0,
        verificationImpossible: true,
      );
    }

    if (statut.estAccepte) {
      await _oublierTrace(userId, livreId);
      return GardePaiement(
        verdict: VerdictPaiement.dejaAcquis,
        transactionId: reference,
        ouverteLe: derniere?.creeLe,
        montant:
            statut.montantServeur ?? derniere?.montant ?? locale?.montant ?? 0,
      );
    }

    // REFUSED, CANCELED, EXPIRED… : la transaction est CLOSE. La présenter
    // comme « un paiement est déjà en cours, attendez la confirmation »
    // retenait le lecteur devant une confirmation qui ne viendrait jamais —
    // la base ne passe à `echoue` qu'après le balayage de réconciliation.
    // Un nouveau paiement est ici parfaitement légitime.
    if (statut.definitivementEchoue) {
      await _oublierTrace(userId, livreId);
      return GardePaiement(
        verdict: VerdictPaiement.laisserPasser,
        transactionId: reference,
        ouverteLe: derniere?.creeLe,
        montant: derniere?.montant ?? locale?.montant ?? 0,
      );
    }

    // Ni confirmée ni close : peut-être réglée (le webhook CinetPay peut
    // mettre une dizaine de minutes), peut-être abandonnée. Seul le lecteur
    // le sait — à l'écran de lui poser la question.
    return GardePaiement(
      verdict: VerdictPaiement.aConfirmerParLaPersonne,
      transactionId: reference,
      ouverteLe: derniere?.creeLe,
      montant:
          statut.montantServeur ?? derniere?.montant ?? locale?.montant ?? 0,
    );
  }

  /// Efface la trace locale d'une transaction close, sans jamais faire échouer
  /// la garde pour autant : au pire l'entrée expirera d'elle-même (24 h).
  Future<void> _oublierTrace(String userId, String livreId) async {
    try {
      await TransactionEnCoursStore.oublier(userId: userId, livreId: livreId);
    } catch (_) {}
  }

  Future<PaymentModel> getPaymentById(String id, String authToken) async {
    final url = ApiRoutes.paymentById.replaceFirst(':id', id);
    final response = await client.get(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $authToken'},
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = jsonDecode(response.body);
      return PaymentModel.fromJson(responseData['data'] ?? responseData);
    } else {
      throw Exception(
        messageDeLaReponse(response, repli: "Ce paiement est introuvable."),
      );
    }
  }

  /// Les revenus d'un auteur — route AUTHENTIFIÉE.
  ///
  /// L'appel partait sans en-tête Authorization : la route est passée derrière
  /// AuthMiddleware et refuse en outre tout appelant autre que l'auteur
  /// lui-même (modules/paiement/routes.go, GetAuthorRevenue). Elle rendait donc
  /// 401 à tous les coups — un écran de revenus qui aurait avalé l'exception
  /// aurait affiché « 0 FCFA » à un auteur payé. Le jeton se lit comme le fait
  /// AuthorStatsService, et reste injectable pour les tests.
  Future<AuthorRevenueModel> getAuthorRevenue(
    String authorId, {
    String? authToken,
  }) async {
    final token = authToken ?? await TokenStorage.getToken();
    final url = ApiRoutes.authorRevenue.replaceFirst(':authorId', authorId);
    final response = await client.get(
      Uri.parse(url),
      headers: {
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = jsonDecode(response.body);
      return AuthorRevenueModel.fromJson(responseData['data'] ?? responseData);
    } else {
      throw Exception(
        messageDeLaReponse(
          response,
          repli: "Impossible de charger vos revenus.",
        ),
      );
    }
  }

  // getMomoStatus a été retiré avec l'intégration MTN MoMo directe.
  //
  // Tout achat passe par CinetPay, qui affiche lui-même Orange Money, MTN,
  // Moov, Wave et les cartes : la passerelle connaît la disponibilité réelle de
  // chaque opérateur, pas nous. Le statut se lit désormais par
  // getCinetpayStatus, et la route serveur correspondante n'existe plus.
}

/// Mémoire locale de la transaction CinetPay ouverte pour un livre.
///
/// Sans elle, revenir sur l'écran de paiement d'un livre dont le règlement
/// était encore en cours ouvrait une SECONDE transaction : deux débits
/// possibles pour un seul livre, et plus aucune référence de la première à
/// citer en réclamation. C'est le correctif déjà appliqué au site web
/// (Stepace_learn_web/src/lib/paiement.ts, memoriserTransaction).
///
/// La clé porte l'identifiant du COMPTE et celui du LIVRE : deux lecteurs sur
/// le même téléphone ne voient jamais la transaction l'un de l'autre.
class TransactionEnCoursStore {
  /// Au-delà, la transaction est écartée : confirmée par le serveur depuis
  /// longtemps, ou expirée chez CinetPay. La re-sonder n'aurait plus de sens.
  static const Duration dureeMax = Duration(hours: 24);

  static String _cle(String userId, String livreId) =>
      'paiement_en_cours_${userId}_$livreId';

  static Future<void> memoriser({
    required String userId,
    required String livreId,
    required String transactionId,
    required double montant,
  }) async {
    if (userId.isEmpty || livreId.isEmpty || transactionId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _cle(userId, livreId),
      jsonEncode({
        'transaction_id': transactionId,
        'montant': montant,
        'ouverte_le': DateTime.now().millisecondsSinceEpoch,
      }),
    );
  }

  /// La transaction encore suivie pour ce livre, ou null.
  static Future<({String transactionId, double montant})?> enCours({
    required String userId,
    required String livreId,
  }) async {
    if (userId.isEmpty || livreId.isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    final brut = prefs.getString(_cle(userId, livreId));
    if (brut == null) return null;
    try {
      final decode = jsonDecode(brut);
      if (decode is! Map) throw const FormatException('entrée inattendue');
      final transactionId = decode['transaction_id']?.toString() ?? '';
      final ouverteLe = (decode['ouverte_le'] as num?)?.toInt() ?? 0;
      final age = DateTime.now().millisecondsSinceEpoch - ouverteLe;
      if (transactionId.isEmpty || age > dureeMax.inMilliseconds) {
        await prefs.remove(_cle(userId, livreId));
        return null;
      }
      return (
        transactionId: transactionId,
        montant: (decode['montant'] as num?)?.toDouble() ?? 0.0,
      );
    } catch (_) {
      // Une entrée corrompue ne doit pas empêcher un paiement : on l'efface.
      await prefs.remove(_cle(userId, livreId));
      return null;
    }
  }

  static Future<void> oublier({
    required String userId,
    required String livreId,
  }) async {
    if (userId.isEmpty || livreId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cle(userId, livreId));
  }
}
