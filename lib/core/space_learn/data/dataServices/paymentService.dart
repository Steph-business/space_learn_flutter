import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../utils/api_routes.dart';
import '../model/paymentModel.dart';
import '../model/authorRevenueModel.dart';

/// Résultat du lancement d'un paiement CinetPay
class CinetpayInitResult {
  final PaymentModel paiement;
  final String paymentUrl;

  CinetpayInitResult({required this.paiement, required this.paymentUrl});
}

/// Statut retourné lors de la vérification d'un paiement CinetPay
class CinetpayStatusResult {
  final String status; // "ACCEPTED", "REFUSED", "PENDING"
  final String? paymentMethod;
  final String? amount;
  final String? currency;
  final PaymentModel? paiement; // présent si ACCEPTED

  CinetpayStatusResult({
    required this.status,
    this.paymentMethod,
    this.amount,
    this.currency,
    this.paiement,
  });
}

class PaymentService {
  final http.Client client;

  PaymentService({http.Client? client}) : client = client ?? http.Client();

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
      throw Exception('Failed to create payment: ${response.body}');
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
      body['customer_phone'] = customerPhone;
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

      if (data is Map<String, dynamic>) {
        final paiement = PaymentModel.fromJson(data['paiement'] ?? data);
        final paymentUrl = data['payment_url'] as String? ?? '';
        return CinetpayInitResult(paiement: paiement, paymentUrl: paymentUrl);
      }
      throw Exception('Format de réponse CinetPay inattendu');
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
        final status = (data['status'] ?? data['Status'] ?? 'UNKNOWN') as String;
        PaymentModel? paiement;
        if (data.containsKey('paiement')) {
          paiement = PaymentModel.fromJson(data['paiement']);
        }
        return CinetpayStatusResult(
          status: status,
          paymentMethod: data['payment_method'] as String?,
          amount: data['amount']?.toString(),
          currency: data['currency'] as String?,
          paiement: paiement,
        );
      }
      throw Exception('Format de statut CinetPay inattendu');
    } else {
      throw Exception(
          'Échec de la vérification CinetPay : ${response.body}');
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
      throw Exception('Failed to fetch user payments');
    }
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
      throw Exception('Failed to fetch payment');
    }
  }

  Future<AuthorRevenueModel> getAuthorRevenue(String authorId) async {
    final url = ApiRoutes.authorRevenue.replaceFirst(':authorId', authorId);
    final response = await client.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = jsonDecode(response.body);
      return AuthorRevenueModel.fromJson(responseData['data'] ?? responseData);
    } else {
      throw Exception('Failed to fetch author revenue');
    }
  }

  Future<Map<String, dynamic>> getMomoStatus(
    String referenceId,
    String authToken,
  ) async {
    final url = ApiRoutes.momoStatus.replaceFirst(':referenceId', referenceId);
    final response = await client.get(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $authToken'},
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = jsonDecode(response.body);
      return responseData['data'] ?? responseData;
    } else {
      throw Exception('Failed to get MoMo status: ${response.body}');
    }
  }
}
