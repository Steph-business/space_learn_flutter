import 'book_model.dart';

class PaymentModel {
  final String id;
  final String utilisateurId; // utilisateur_id
  final String livreId; // livre_id
  final String methodePaiement; // mobile_money|carte_bancaire|paypal|crypto
  final String transactionId;
  final String referenceId; // reference_id

  /// L'état de la commande côté serveur : `en_attente`, `confirme` ou
  /// `echoue` (modules/paiement/model.go).
  ///
  /// Le serveur le sérialise depuis toujours ; personne ne le lisait. Une
  /// transaction retrouvée dans l'historique ne pouvait donc pas être triée
  /// localement : pour savoir si un paiement d'il y a dix minutes avait
  /// abouti, il fallait redemander la passerelle. Les gardes anti-double-débit
  /// écartent maintenant d'emblée ce qui est déjà tranché.
  final String statut;

  final double montant;
  final String? phoneNumber;
  final DateTime? creeLe;
  final BookModel? livre;

  PaymentModel({
    required this.id,
    required this.utilisateurId,
    required this.livreId,
    required this.methodePaiement,
    required this.transactionId,
    required this.referenceId,
    this.statut = 'en_attente',
    required this.montant,
    this.phoneNumber,
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
      // Le défaut suit celui de la colonne : une ligne sans statut est une
      // commande engagée, jamais une commande payée.
      statut: (json['statut'] as String?)?.trim().isNotEmpty == true
          ? (json['statut'] as String).trim()
          : 'en_attente',
      phoneNumber: json['phone_number'],
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
      'statut': statut,
      if (phoneNumber != null) 'phone_number': phoneNumber,
      'montant': montant,
      'cree_le': creeLe?.toIso8601String(),
      'Livre': livre?.toJson(),
    };
  }
}
