/// Une ligne de reversement : la part d'une vente due à l'auteur.
///
/// Miroir du modèle `Reversement` du backend. Chaque vente en produit une, et
/// son statut décrit où en est le virement Mobile Money.
class ReversementModel {
  final String id;
  final String livreId;

  /// Ce que l'acheteur a payé.
  final double montantBrut;

  /// Part conservée par la plateforme.
  final double commission;

  /// Ce qui revient à l'auteur, après commission et arrondi opérateur.
  final double montantNet;

  final double tauxApplique;
  final String devise;
  final String statut;
  final int tentatives;
  final String? derniereErreur;
  final DateTime? envoyeLe;
  final DateTime? creeLe;

  const ReversementModel({
    required this.id,
    required this.livreId,
    required this.montantBrut,
    required this.commission,
    required this.montantNet,
    required this.tauxApplique,
    required this.devise,
    required this.statut,
    required this.tentatives,
    this.derniereErreur,
    this.envoyeLe,
    this.creeLe,
  });

  factory ReversementModel.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v) =>
        v == null ? 0.0 : (v is num ? v.toDouble() : double.tryParse('$v') ?? 0.0);

    DateTime? toDate(dynamic v) =>
        v == null ? null : DateTime.tryParse('$v');

    return ReversementModel(
      id: json['id']?.toString() ?? '',
      livreId: json['livre_id']?.toString() ?? '',
      montantBrut: toDouble(json['montant_brut']),
      commission: toDouble(json['commission']),
      montantNet: toDouble(json['montant_net']),
      tauxApplique: toDouble(json['taux_applique']),
      devise: json['devise']?.toString() ?? 'XOF',
      statut: json['statut']?.toString() ?? 'en_attente',
      tentatives: json['tentatives'] is int ? json['tentatives'] as int : 0,
      derniereErreur: json['derniere_erreur']?.toString(),
      envoyeLe: toDate(json['envoye_le']),
      creeLe: toDate(json['cree_le']),
    );
  }

  /// Le virement a-t-il abouti côté opérateur ?
  bool get estVerse => statut == 'envoye' || statut == 'paye';

  /// Le versement attend une action : coordonnées manquantes ou échec à rejouer.
  bool get estBloque => statut == 'sans_infos' || statut == 'echoue';

  String get libelleStatut {
    switch (statut) {
      case 'paye':
        return 'Versé';
      case 'envoye':
        return 'Virement envoyé';
      case 'en_attente':
        return 'En attente';
      case 'echoue':
        return 'Échec, nouvelle tentative prévue';
      case 'sans_infos':
        return 'Numéro Mobile Money manquant';
      default:
        return statut;
    }
  }
}

/// Agrégat renvoyé avec l'historique.
class ResumeReversements {
  /// Somme des reversements dont le virement est parti.
  final double totalVerse;

  /// Somme due mais pas encore virée.
  final double totalEnAttente;

  /// Taux de commission appliqué (0.10 = 10 %).
  final double tauxCommission;

  final String devise;

  const ResumeReversements({
    required this.totalVerse,
    required this.totalEnAttente,
    required this.tauxCommission,
    required this.devise,
  });

  factory ResumeReversements.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v) =>
        v == null ? 0.0 : (v is num ? v.toDouble() : double.tryParse('$v') ?? 0.0);

    return ResumeReversements(
      totalVerse: toDouble(json['total_verse']),
      totalEnAttente: toDouble(json['total_en_attente']),
      tauxCommission: toDouble(json['taux_commission']),
      devise: json['devise']?.toString() ?? 'XOF',
    );
  }

  static const ResumeReversements vide = ResumeReversements(
    totalVerse: 0,
    totalEnAttente: 0,
    tauxCommission: 0.10,
    devise: 'XOF',
  );
}

/// Coordonnées Mobile Money vers lesquelles l'auteur est payé.
class InfosPaiementModel {
  final String prefix;
  final String telephone;
  final String nomComplet;
  final String email;

  /// Vrai quand le backend n'a rien d'enregistré et propose le téléphone du
  /// compte comme point de départ — l'auteur doit encore confirmer.
  final bool parDefaut;

  const InfosPaiementModel({
    required this.prefix,
    required this.telephone,
    this.nomComplet = '',
    this.email = '',
    this.parDefaut = false,
  });

  factory InfosPaiementModel.fromJson(Map<String, dynamic> json) {
    return InfosPaiementModel(
      prefix: json['prefix']?.toString() ?? '',
      telephone: json['telephone']?.toString() ?? '',
      nomComplet: json['nom_complet']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      parDefaut: json['par_defaut'] == true,
    );
  }

  bool get estRenseigne => telephone.isNotEmpty && !parDefaut;

  String get numeroComplet =>
      prefix.isEmpty ? telephone : '+$prefix $telephone';
}
