import 'bookModel.dart';

class PaymentModel {
  final String id;
  final String utilisateurId; // utilisateur_id
  final String livreId; // livre_id
  final String methodePaiement; // mobile_money|carte_bancaire|paypal|crypto
  final String transactionId;
  final String referenceId; // reference_id
  final double montant;
  final DateTime? creeLe;
  final BookModel? livre;

  PaymentModel({
    required this.id,
    required this.utilisateurId,
    required this.livreId,
    required this.methodePaiement,
    required this.transactionId,
    required this.referenceId,
    required this.montant,
    this.creeLe,
    this.livre,
  });

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    return PaymentModel(
      id: json['id'] ?? '',
      utilisateurId: json['utilisateur_id'] ?? '',
      livreId: json['livre_id'] ?? '',
      methodePaiement: json['methode_paiement'] ?? '',
      transactionId: json['transaction_id'] ?? '',
      referenceId: json['reference_id'] ?? '',
      montant: (json['montant'] ?? 0.0).toDouble(),
      creeLe: json['cree_le'] != null ? DateTime.parse(json['cree_le']) : null,
      livre: json['Livre'] != null ? BookModel.fromJson(json['Livre']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'utilisateur_id': utilisateurId,
      'livre_id': livreId,
      'methode_paiement': methodePaiement,
      'transaction_id': transactionId,
      'reference_id': referenceId,
      'montant': montant,
      'cree_le': creeLe?.toIso8601String(),
      'Livre': livre?.toJson(),
    };
  }
}
