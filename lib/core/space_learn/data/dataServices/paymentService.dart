import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../utils/api_routes.dart';
import '../model/paymentModel.dart';
import '../model/authorRevenueModel.dart';

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
