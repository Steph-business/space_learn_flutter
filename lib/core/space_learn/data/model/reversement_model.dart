/// Portefeuille de l'auteur.
///
/// Les gains s'accumulent à chaque vente ; l'auteur retire quand il le décide.
/// Le solde n'est pas stocké côté serveur, il est recalculé depuis le registre
/// des crédits et des retraits.
class SoldeAuteur {
  /// Tout ce que les ventes ont rapporté, commission déduite.
  final double totalGagne;

  /// Retraits effectivement versés.
  final double totalRetire;

  /// Retraits demandés, pas encore versés. Ce montant est immobilisé.
  final double enCours;

  /// Ce qui peut être retiré maintenant.
  final double disponible;

  final String devise;

  const SoldeAuteur({
    required this.totalGagne,
    required this.totalRetire,
    required this.enCours,
    required this.disponible,
    required this.devise,
  });

  factory SoldeAuteur.fromJson(Map<String, dynamic> json) => SoldeAuteur(
    totalGagne: _double(json['total_gagne']),
    totalRetire: _double(json['total_retire']),
    enCours: _double(json['en_cours']),
    disponible: _double(json['disponible']),
    devise: json['devise']?.toString() ?? 'XOF',
  );

  static const SoldeAuteur vide = SoldeAuteur(
    totalGagne: 0,
    totalRetire: 0,
    enCours: 0,
    disponible: 0,
    devise: 'XOF',
  );
}

/// Un crédit : la part revenant à l'auteur sur une vente.
class ReversementModel {
  final String id;
  final String livreId;

  /// Ce que l'acheteur a payé.
  final double montantBrut;

  /// Part conservée par la plateforme.
  final double commission;

  /// Ce qui est entré au portefeuille.
  final double montantNet;

  final String devise;
  final DateTime? creeLe;

  const ReversementModel({
    required this.id,
    required this.livreId,
    required this.montantBrut,
    required this.commission,
    required this.montantNet,
    required this.devise,
    this.creeLe,
  });

  factory ReversementModel.fromJson(Map<String, dynamic> json) =>
      ReversementModel(
        id: json['id']?.toString() ?? '',
        livreId: json['livre_id']?.toString() ?? '',
        montantBrut: _double(json['montant_brut']),
        commission: _double(json['commission']),
        montantNet: _double(json['montant_net']),
        devise: json['devise']?.toString() ?? 'XOF',
        creeLe: _date(json['cree_le']),
      );
}

/// Une demande de retrait vers le Mobile Money.
class RetraitModel {
  final String id;
  final double montant;
  final String devise;
  final String statut;
  final String? derniereErreur;
  final DateTime? demandeLe;
  final DateTime? traiteLe;

  const RetraitModel({
    required this.id,
    required this.montant,
    required this.devise,
    required this.statut,
    this.derniereErreur,
    this.demandeLe,
    this.traiteLe,
  });

  factory RetraitModel.fromJson(Map<String, dynamic> json) => RetraitModel(
    id: json['id']?.toString() ?? '',
    montant: _double(json['montant']),
    devise: json['devise']?.toString() ?? 'XOF',
    statut: json['statut']?.toString() ?? 'demandee',
    derniereErreur: json['derniere_erreur']?.toString(),
    demandeLe: _date(json['demande_le']),
    traiteLe: _date(json['traite_le']),
  );

  /// Seule une demande pas encore transmise à l'opérateur peut être annulée.
  bool get estAnnulable => statut == 'demandee';

  bool get estPaye => statut == 'payee';

  bool get estEnEchec => statut == 'echouee';

  String get libelleStatut {
    switch (statut) {
      case 'demandee':
        return 'En attente de traitement';
      case 'en_cours':
        return 'Virement en cours';
      case 'payee':
        return 'Versé';
      case 'echouee':
        return 'Échec, nouvelle tentative prévue';
      case 'annulee':
        return 'Annulé';
      default:
        return statut;
    }
  }
}

/// Réponse complète de l'endpoint portefeuille.
class Portefeuille {
  final SoldeAuteur solde;
  final double tauxCommission;

  /// Le montant à partir duquel le virement est offert.
  final double minimumRetrait;

  /// Le plancher en dessous duquel on ne vire pas du tout.
  ///
  /// Entre les deux, le retrait reste possible : les frais d'opérateur sont
  /// retenus. Sans cette seconde borne, un auteur qui n'a qu'un seul livre
  /// voyait son portefeuille monter sans jamais pouvoir y toucher.
  final double minimumRetraitAbsolu;

  /// Ce qui est retenu sur un virement demandé sous le seuil de gratuité.
  ///
  /// Nul aujourd'hui : la plateforme prend les frais de transfert à sa charge,
  /// quel que soit le montant. Les écrans ne doivent donc parler ni de frais ni
  /// de « virement offert » — les deux notions n'ont de sens que l'une par
  /// rapport à l'autre, et annoncer une gratuité à partir d'un seuil laisse
  /// entendre qu'en dessous on paie.
  final double fraisRetrait;

  /// Un virement peut-il coûter quelque chose à l'auteur ?
  ///
  /// Tant que c'est faux, les écrans se taisent sur le sujet.
  bool get desFraisExistent => fraisRetrait > 0;

  final List<ReversementModel> ventes;
  final List<RetraitModel> retraits;

  const Portefeuille({
    required this.solde,
    required this.tauxCommission,
    required this.minimumRetrait,
    required this.minimumRetraitAbsolu,
    required this.fraisRetrait,
    required this.ventes,
    required this.retraits,
  });

  factory Portefeuille.fromJson(Map<String, dynamic> json) => Portefeuille(
    solde: json['solde'] is Map<String, dynamic>
        ? SoldeAuteur.fromJson(json['solde'] as Map<String, dynamic>)
        : SoldeAuteur.vide,
    tauxCommission: _double(json['taux_commission']),
    minimumRetrait: _double(json['minimum_retrait']),
    // Un serveur d'une version antérieure n'envoie pas ces deux bornes : on
    // retombe alors sur l'ancien comportement, où le seuil de gratuité était
    // aussi le plancher absolu.
    minimumRetraitAbsolu: json['minimum_retrait_absolu'] != null
        ? _double(json['minimum_retrait_absolu'])
        : _double(json['minimum_retrait']),
    fraisRetrait: _double(json['frais_retrait']),
    ventes: _liste(json['reversements'], ReversementModel.fromJson),
    retraits: _liste(json['retraits'], RetraitModel.fromJson),
  );

  static const Portefeuille vide = Portefeuille(
    solde: SoldeAuteur.vide,
    tauxCommission: 0.20,
    minimumRetrait: 5000,
    minimumRetraitAbsolu: 1000,
    fraisRetrait: 100,
    ventes: [],
    retraits: [],
  );

  /// L'auteur peut-il demander un retrait maintenant ?
  ///
  /// La borne est le plancher absolu, pas le seuil de gratuité : c'est tout
  /// l'objet de la distinction. Le bouton restait grisé jusqu'à 5 000 F.
  bool get retraitPossible => solde.disponible >= minimumRetraitAbsolu;

  /// Les frais retenus sur un retrait de [montant]. Zéro au-dessus du seuil.
  ///
  /// La règle est la même que celle du serveur, `DecomposerRetrait` : le
  /// montant est aligné sur le palier de l'opérateur — cinq francs en zone
  /// XOF — et les frais absorbent le reliquat, de sorte que versé + frais
  /// redonne exactement le montant demandé.
  double fraisPour(double montant) {
    final aligne = (montant / 5).floor() * 5.0;
    if (aligne <= 0 || aligne >= minimumRetrait) return 0;
    final verse = ((aligne - fraisRetrait) / 5).floor() * 5.0;
    if (verse <= 0) return aligne;
    return aligne - verse;
  }

  /// Ce que l'auteur recevra réellement pour un retrait de [montant].
  double versePour(double montant) {
    final aligne = (montant / 5).floor() * 5.0;
    if (aligne <= 0) return 0;
    return aligne - fraisPour(montant);
  }
}

/// Coordonnées Mobile Money vers lesquelles l'auteur est payé.
class InfosPaiementModel {
  final String prefix;
  final String telephone;
  final String nomComplet;
  final String email;

  /// Vrai quand le serveur n'a rien d'enregistré et propose le téléphone du
  /// compte comme point de départ — l'auteur doit encore confirmer.
  final bool parDefaut;

  const InfosPaiementModel({
    required this.prefix,
    required this.telephone,
    this.nomComplet = '',
    this.email = '',
    this.parDefaut = false,
  });

  factory InfosPaiementModel.fromJson(Map<String, dynamic> json) =>
      InfosPaiementModel(
        prefix: json['prefix']?.toString() ?? '',
        telephone: json['telephone']?.toString() ?? '',
        nomComplet: json['nom_complet']?.toString() ?? '',
        email: json['email']?.toString() ?? '',
        parDefaut: json['par_defaut'] == true,
      );

  bool get estRenseigne => telephone.isNotEmpty && !parDefaut;

  String get numeroComplet =>
      prefix.isEmpty ? telephone : '+$prefix $telephone';
}

double _double(dynamic v) =>
    v == null ? 0.0 : (v is num ? v.toDouble() : double.tryParse('$v') ?? 0.0);

DateTime? _date(dynamic v) => v == null ? null : DateTime.tryParse('$v');

List<T> _liste<T>(dynamic brut, T Function(Map<String, dynamic>) depuis) =>
    (brut as List?)?.whereType<Map<String, dynamic>>().map(depuis).toList() ??
    <T>[];
