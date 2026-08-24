import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/themes/widgets/app_card.dart';
import 'package:space_learn_flutter/core/themes/widgets/app_segmented_control.dart';
import 'package:flutter/material.dart';
import 'package:space_learn_flutter/core/themes/app_dimensions.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/authorStatsService.dart';
import 'package:space_learn_flutter/core/utils/app_notifications.dart';
import 'package:space_learn_flutter/core/utils/message_erreur.dart';

class PeriodOption {
  final String key;
  final String label;
  final String fullLabel;

  const PeriodOption({
    required this.key,
    required this.label,
    required this.fullLabel,
  });
}

class Revenus extends StatefulWidget {
  final Map<String, dynamic> stats;
  final String? authorId;
  final ValueChanged<String>? onPeriodChanged;

  const Revenus({
    super.key,
    required this.stats,
    this.authorId,
    this.onPeriodChanged,
  });

  @override
  State<Revenus> createState() => _RevenusState();
}

class _RevenusState extends State<Revenus> {
  bool isRevenueSelected = true;
  // « Tout » par defaut, parce que c'est ce que la page CHARGE.
  //
  // L'accueil appelle getAuthorStats(authorId, "") — chaine vide, donc aucun
  // parametre `period`, donc le serveur retient « all » et rend TOUT
  // l'historique. Mais cet ecran partait sur '30d' sans rien redemander : le
  // chiffre couvrait toutes les ventes depuis l'ouverture du compte et
  // s'affichait sous le libelle « Total (Mois) ». Un mensonge sur de l'argent.
  String _selectedPeriodKey = 'all';
  bool _isLoadingPeriodData = false;
  Map<String, dynamic>? _customPeriodStats;
  final AuthorStatsService _authorStatsService = AuthorStatsService();

  static const List<PeriodOption> _periods = [
    // `all` est la valeur que le serveur retient quand aucune periode n'est
    // demandee (livre/repository.go, PeriodeDebut) : l'option existe donc
    // desormais a l'ecran aussi, au lieu d'etre un etat sans nom.
    PeriodOption(key: 'all', label: 'Tout', fullLabel: 'Depuis le début'),
    PeriodOption(key: '7d', label: 'Semaine', fullLabel: 'Cette Semaine'),
    PeriodOption(key: '30d', label: 'Mois', fullLabel: 'Ce Mois'),
    PeriodOption(key: '1y', label: 'Année', fullLabel: 'Cette Année'),
  ];

  PeriodOption get _currentPeriod => _periods.firstWhere(
    (p) => p.key == _selectedPeriodKey,
    orElse: () => _periods[0],
  );

  Map<String, dynamic> get activeStats => _customPeriodStats ?? widget.stats;

  double get totalRevenue => (activeStats['total_revenue'] ?? 0).toDouble();
  double get totalDownloads => (activeStats['total_downloads'] ?? 0).toDouble();

  /// Ce que l'auteur touche, commission déduite.
  ///
  /// Lu dans le registre des reversements — celui dont son portefeuille tire
  /// ses chiffres. Repli sur le brut quand le serveur ne l'envoie pas encore.
  double get netRevenue => activeStats['net_revenue'] != null
      ? (activeStats['net_revenue'] as num).toDouble()
      : totalRevenue;

  /// Les points de la courbe, tels que le serveur les a découpés.
  ///
  /// Repli sur la série mensuelle pour un serveur d'une version antérieure :
  /// douze mois valent mieux qu'une courbe vide, et les étiquettes suivront
  /// la même logique.
  List<double> _serie() {
    final cle = isRevenueSelected ? 'serie_revenus' : 'serie_lectures';
    final repli = isRevenueSelected ? 'monthly_revenue' : 'monthly_readings';

    final brut = activeStats[cle] is List
        ? activeStats[cle] as List
        : (activeStats[repli] is List ? activeStats[repli] as List : const []);

    final valeurs = <double>[
      for (final v in brut) if (v is num) v.toDouble() else 0.0,
    ];
    // Un seul point ne dessine pas de courbe : fl_chart a besoin de deux
    // extrémités pour tracer un segment.
    return valeurs.length >= 2 ? valeurs : [0.0, 0.0];
  }

  /// Les étiquettes de l'axe, telles que le serveur les a nommées.
  List<String> _etiquettes() {
    final brut = activeStats['serie_libelles'];
    if (brut is List && brut.length >= 2) {
      return [for (final e in brut) e.toString()];
    }
    // Serveur antérieur : la série de repli est mensuelle, donc les mois.
    return moisDeLaFenetre(activeStats['mois_debut']?.toString());
  }

  /// La légende du grand chiffre, accordée à l'onglet et à la période.
  String _sousTitreDuTotal() {
    final quoi = isRevenueSelected ? "Vos gains" : "Lectures";
    return _currentPeriod.key == 'all'
        ? "$quoi — depuis le début"
        : "$quoi (${_currentPeriod.label})";
  }

  @override
  void didUpdateWidget(Revenus oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.stats != oldWidget.stats && _customPeriodStats == null) {
      setState(() {});
    }
  }

  Future<void> _handlePeriodChange(String periodKey) async {
    if (_selectedPeriodKey == periodKey) return;

    setState(() {
      _selectedPeriodKey = periodKey;
      _isLoadingPeriodData = true;
    });

    widget.onPeriodChanged?.call(periodKey);

    if (widget.authorId != null && widget.authorId!.isNotEmpty) {
      try {
        final newStats = await _authorStatsService.getAuthorStats(
          widget.authorId!,
          periodKey,
        );
        if (mounted) {
          setState(() {
            _customPeriodStats = newStats.isNotEmpty ? newStats : null;
            _isLoadingPeriodData = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoadingPeriodData = false);
          // Sans ce message, changer de période sur un appel refusé laissait
          // les chiffres de la période précédente sous le nouveau libellé :
          // l'auteur lisait « ce mois-ci » au-dessus des montants de l'an
          // dernier.
          AppNotifications.showSnackBar(
            context,
            message: messageLisible(
              e,
              repli: "Les chiffres de cette période sont indisponibles.",
            ),
            isError: true,
          );
        }
      }
    } else {
      if (mounted) {
        setState(() => _isLoadingPeriodData = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    AppColors.suivreLeTheme(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Header: Title & Period Dropdown Selector + Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left Column: Main Title & Dropdown Pill
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isRevenueSelected ? "Revenus" : "Lectures",
                    style: GoogleFonts.poppins(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Dropdown Selector (PopupMenuButton)
                  PopupMenuButton<String>(
                    onSelected: (String periodKey) =>
                        _handlePeriodChange(periodKey),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusInner,
                      ),
                    ),
                    color: AppColors.cardBackground,
                    elevation: 6,
                    itemBuilder: (BuildContext context) {
                      return _periods.map((PeriodOption option) {
                        final isSelected = option.key == _selectedPeriodKey;
                        return PopupMenuItem<String>(
                          value: option.key,
                          child: Row(
                            children: [
                              Text(
                                option.label,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w400,
                                  color: isSelected
                                      ? AppColors.accentInk
                                      : AppColors.textPrimary,
                                ),
                              ),
                              if (isSelected) ...[
                                const Spacer(),
                                Icon(
                                  Icons.check_rounded,
                                  size: 18,
                                  color: AppColors.accentInk,
                                ),
                              ],
                            ],
                          ),
                        );
                      }).toList();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.scaffoldBackground,
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusCard,
                        ),
                        border: Border.all(
                          color: AppColors.accentInk.withOpacity(0.3),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _currentPeriod.label,
                            style: GoogleFonts.poppins(
                              color: AppColors.accentInk,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 18,
                            color: AppColors.accentInk,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Right Column: Total Amount
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Le sous-titre suit l'onglet choisi.
                  //
                  // Il annonçait « Chiffre d'affaires brut » en toutes
                  // circonstances, y compris sous le titre « Lectures » : la
                  // légende décrivait alors une grandeur que le chiffre
                  // d'en dessous ne mesurait pas.
                  //
                  // Et « brut » n'a plus lieu d'être : la courbe montre
                  // désormais ce que l'auteur touche, commission déduite,
                  // comme son portefeuille.
                  Text(
                    _sousTitreDuTotal(),
                    style: GoogleFonts.poppins(
                      color: AppColors.textHint,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isRevenueSelected
                        ? '${netRevenue.toStringAsFixed(0)} FCFA'
                        : totalDownloads.toStringAsFixed(0),
                    style: GoogleFonts.poppins(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 28),

          // Chart Section with loader overlay
          SizedBox(
            height: 120,
            child: Stack(
              children: [
                LineChart(_buildChartData()),
                if (_isLoadingPeriodData)
                  Positioned.fill(
                    child: Container(
                      color: AppColors.cardBackground.withOpacity(0.6),
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.accentInk,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // X-Axis Labels
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: _buildXAxisLabels(),
            ),
          ),

          const SizedBox(height: 24),

          // Selector Lectures / Revenus
          AppSegmentedControl(
            labels: const ["Lectures", "Revenus"],
            selectedIndex: isRevenueSelected ? 1 : 0,
            onChanged: (index) =>
                setState(() => isRevenueSelected = index == 1),
          ),
        ],
      ),
    );
  }

  Widget _buildDateLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.poppins(
        color: AppColors.textHint,
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  /// Les étiquettes de l'axe, prises de la série elle-même.
  ///
  /// Elles étaient écrites en dur, et ne décrivaient rien : « Lun, Mar, Jeu,
  /// Sam, Dim » sous sept points, « Sem 1 » à « Sem 4 » sous quatre mois,
  /// « Jan » à « Déc » sous une fenêtre glissante. Chaque valeur s'affichait
  /// donc sous un moment qui n'était pas le sien.
  ///
  /// Cinq repères au plus : au-delà, ils se chevauchent sur un téléphone.
  List<Widget> _buildXAxisLabels() {
    final noms = _etiquettes();
    if (noms.length <= 5) {
      return [for (final n in noms) _buildDateLabel(n)];
    }

    final pas = (noms.length - 1) / 4;
    return [
      for (var i = 0; i < 5; i++)
        _buildDateLabel(noms[(i * pas).round().clamp(0, noms.length - 1)]),
    ];
  }

  LineChartData _buildChartData() {
    // La série vient du serveur, découpée pour la période demandée.
    //
    // Elle était fabriquée ici, et deux fois de travers. D'abord la courbe des
    // lectures n'existait pas : on divisait les revenus par 1500, un nombre
    // sans aucun rapport avec des lectures, affiché sous le mot « Lectures ».
    // Ensuite le découpage était inventé : sous « Semaine » on montrait les
    // sept premiers mois de la fenêtre comme s'ils étaient sept jours, sous
    // « Mois » les quatre premiers mois sous « Sem 1 » à « Sem 4 ».
    //
    // Le serveur a les dates : c'est lui qui découpe, et il envoie les
    // étiquettes avec.
    final chartValues = _serie();
    final pointCount = chartValues.length;

    double maxY = chartValues.isEmpty
        ? 10
        : chartValues.reduce((a, b) => a > b ? a : b);
    if (maxY == 0) maxY = 10;
    maxY = maxY * 1.2;

    List<FlSpot> spots = [];
    for (int i = 0; i < pointCount; i++) {
      spots.add(FlSpot(i.toDouble(), chartValues[i]));
    }

    return LineChartData(
      gridData: const FlGridData(show: false),
      titlesData: const FlTitlesData(show: false),
      borderData: FlBorderData(show: false),
      minX: 0,
      maxX: (pointCount - 1).toDouble(),
      minY: 0,
      maxY: maxY,
      lineBarsData: [
        LineChartBarData(
          spots: spots.isEmpty ? [const FlSpot(0, 0)] : spots,
          isCurved: true,
          color: AppColors.accentInk,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) =>
                FlDotCirclePainter(
                  radius: 4,
                  color: AppColors.accentInk,
                  strokeWidth: 2,
                  strokeColor: AppColors.cardBackground,
                ),
          ),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: [
                AppColors.secondary.withOpacity(0.2),
                AppColors.secondary.withOpacity(0.0),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ],
    );
  }
}

const List<String> abrevMois = [
  "Jan",
  "Fév",
  "Mar",
  "Avr",
  "Mai",
  "Juin",
  "Juil",
  "Août",
  "Sep",
  "Oct",
  "Nov",
  "Déc",
];

/// Les douze mois couverts par les séries de statistiques, dans l'ordre des
/// points de la courbe.
///
/// Les étiquettes de l'axe étaient écrites en dur, de « Jan » à « Déc ». Or le
/// serveur renvoie les douze derniers mois GLISSANTS — du mois M-11 au mois
/// courant. En août, le premier point est donc celui de septembre de l'année
/// précédente, et il s'affichait sous « Jan » : toute la courbe était décalée
/// de huit mois, sans que rien ne le signale.
///
/// [moisDebut] est ce que le serveur annonce, au format « 2025-09 ». À défaut
/// — serveur d'une version antérieure, ou valeur illisible — la fenêtre est
/// recomposée depuis [maintenant], ce qui donne le même résultat tant que les
/// deux horloges s'accordent sur le mois.
///
/// Fonction de premier niveau, et non méthode privée d'un écran : c'est une
/// règle de lecture des données, et elle doit pouvoir être vérifiée seule.
List<String> moisDeLaFenetre(String? moisDebut, {DateTime? maintenant}) {
  final aujourdhui = maintenant ?? DateTime.now();
  var debut = DateTime(aujourdhui.year, aujourdhui.month - 11);

  final decoupe = (moisDebut ?? '').split('-');
  if (decoupe.length >= 2) {
    final annee = int.tryParse(decoupe[0]);
    final mois = int.tryParse(decoupe[1]);
    if (annee != null && mois != null && mois >= 1 && mois <= 12) {
      debut = DateTime(annee, mois);
    }
  }

  return List.generate(12, (i) {
    final m = DateTime(debut.year, debut.month + i);
    // L'année apparaît en janvier : sans elle, une fenêtre à cheval sur deux
    // années se lit comme si tout s'était passé dans la même.
    final abrev = abrevMois[m.month - 1];
    return m.month == 1 ? "$abrev ${m.year % 100}" : abrev;
  });
}
