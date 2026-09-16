import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

import 'package:space_learn_flutter/core/space_learn/data/dataServices/bookService.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/reversementService.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/book_model.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/reversement_model.dart';
import 'package:space_learn_flutter/core/services/session_service.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/auth/login.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/settings/payout_info_page.dart';
import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/themes/app_dimensions.dart';
import 'package:space_learn_flutter/core/themes/widgets/app_card.dart';
import 'package:space_learn_flutter/core/utils/app_notifications.dart';
import 'package:space_learn_flutter/core/utils/token_storage.dart';
import 'package:space_learn_flutter/core/utils/message_erreur.dart';

/// Portefeuille de l'auteur : gains cumulés, retrait à la demande, historique.
///
/// Les montants viennent du registre du serveur, donc des paiements réellement
/// encaissés. La version précédente estimait un solde côté client à partir du
/// nombre de téléchargements, et son bouton « Retirer » n'appelait aucune API :
/// l'auteur voyait une confirmation de virement alors que rien ne partait.
class SalesReportPage extends StatefulWidget {
  const SalesReportPage({super.key});

  @override
  State<SalesReportPage> createState() => _SalesReportPageState();
}

class _SalesReportPageState extends State<SalesReportPage> {
  final ReversementService _service = ReversementService();
  final BookService _bookService = BookService();

  Portefeuille _portefeuille = Portefeuille.vide;
  Map<String, String> _titresParLivre = {};

  bool _isLoading = true;
  bool _retraitEnCours = false;
  String? _erreur;

  /// Le numéro de versement manque-t-il ? Nul quand on ne SAIT pas.
  ///
  /// Trois états, et le troisième n'existait pas : renseigné, absent, illisible.
  /// La lecture des coordonnées rendait `null` sur une panne comme sur une
  /// absence, et l'écran affichait alors « Renseignez votre numéro Mobile
  /// Money » à un auteur qui en avait un — puis l'emmenait vers un formulaire
  /// vide dont l'enregistrement aurait changé la destination de ses virements.
  /// Sur une panne, on ne dit rien de ce qu'on ignore : on dit la panne.
  bool? _numeroManquant;

  /// La panne qui a empêché de lire les coordonnées, s'il y en a eu une.
  ///
  /// Distincte de [_erreur], qui porte l'échec du portefeuille entier : le
  /// solde et l'historique peuvent être parfaitement lisibles alors que cette
  /// seule lecture-là a échoué.
  String? _erreurCoordonnees;

  /// L'échec du portefeuille est-il une session morte ?
  ///
  /// La cause était dite, le geste non : le bandeau de [_erreur] n'offrait
  /// AUCUN geste — ni « Réessayer » sur une panne, ni « Se reconnecter » sur un
  /// jeton mort — pendant que le geste de rafraîchissement, lui, restait armé
  /// et rejouait la requête refusée à chaque tirage.
  bool _sessionFinie = false;

  /// L'instant où les retraits redeviennent possibles après un changement de
  /// numéro, quand le serveur a armé sa carence de vingt-quatre heures.
  ///
  /// Voir [InfosPaiementModel.finDeCarence]. Cet écran l'ANNONCE ; c'est le
  /// serveur qui refuse, avec sa propre horloge — le bouton « Retirer » n'est
  /// pas masqué pour autant.
  DateTime? _finDeCarence;

  /// « 12/09/2026 à 14h30 » — le format du serveur (`02/01/2006 à 15h04`),
  /// pour que l'annonce et le refus disent la même heure de la même façon.
  String _quand(DateTime instant) {
    final d = instant.toLocal();
    String d2(int n) => n.toString().padLeft(2, '0');
    return '${d2(d.day)}/${d2(d.month)}/${d.year} à ${d2(d.hour)}h${d2(d.minute)}';
  }

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    if (mounted) {
      setState(() {
        _erreur = null;
        _erreurCoordonnees = null;
        _sessionFinie = false;
      });
    }

    try {
      final token = await TokenStorage.getToken();
      if (token == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            // La phrase vient de la constante partagée, et non d'une copie à
            // la main : c'est elle qu'`estSessionExpiree` reconnaît, et les
            // deux avaient déjà divergé une fois.
            _erreur = phraseSessionExpiree;
            _sessionFinie = true;
          });
        }
        return;
      }

      final portefeuille = await _service.getPortefeuille(token);

      // La lecture des coordonnées a son propre échec, et il ne doit pas
      // emporter le portefeuille : le solde et l'historique viennent d'arriver
      // intacts. Elle ne doit pas non plus se taire — voir [_numeroManquant].
      bool? manquant;
      String? panneCoordonnees;
      DateTime? finDeCarence;
      try {
        final infos = await _service.getInfosPaiement(token);
        manquant = infos == null || !infos.estRenseigne;
        // La carence se lit ici et s'annonce plus bas : voir [_finDeCarence].
        finDeCarence = infos?.finDeCarence;
      } catch (e) {
        panneCoordonnees = messageLisible(
          e,
          repli: "Vos coordonnées de paiement n'ont pas pu être lues.",
        );
      }

      final titres = await _chargerTitres(token);

      if (!mounted) return;
      setState(() {
        _portefeuille = portefeuille;
        _titresParLivre = titres;
        _numeroManquant = manquant;
        _erreurCoordonnees = panneCoordonnees;
        _finDeCarence = finDeCarence;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _sessionFinie = estSessionExpiree(e);
        _erreur = messageLisible(e, repli: "Impossible de charger vos ventes.");
      });
    }
  }

  /// Fin de session complète, puis retour à l'écran de connexion.
  Future<void> _seReconnecter() async {
    await SessionService.terminer();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  /// Les crédits ne portent que l'identifiant du livre : on résout les titres
  /// pour que l'historique soit lisible.
  Future<Map<String, String>> _chargerTitres(String token) async {
    try {
      // Les livres de CET auteur, et non le catalogue entier.
      //
      // L'appel ne portait aucun filtre : il telechargeait tous les livres de
      // la plateforme pour retrouver quelques titres. Sans identifiant, on ne
      // resout rien — mieux vaut un historique sans titres qu'un catalogue
      // entier sur le reseau d'un telephone.
      final auteurId = await TokenStorage.getUserId();
      if (auteurId == null || auteurId.isEmpty) return {};

      final livres = await _bookService.getAllBooks(
        auteurId: auteurId,
        authToken: token,
        maximum: 1000,
      );
      return {for (final BookModel l in livres) l.id: l.titre};
    } catch (_) {
      return {};
    }
  }

  String _montant(double valeur, [String? devise]) {
    final f = NumberFormat.decimalPattern('fr_FR');
    return '${f.format(valeur.round())} ${devise ?? _portefeuille.solde.devise}';
  }

  // ──────────────────────────── Actions ────────────────────────────

  Future<void> _ouvrirCompteVersement() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const PayoutInfoPage()));
    if (mounted) _charger();
  }

  /// Demande le virement, et n'annonce QUE ce que le serveur a confirmé.
  ///
  /// Deux refus de ce parcours sont des refus de DROIT et ne se réessaient
  /// pas : le 428 sans numéro enregistré — l'écran emmène là où le corriger —
  /// et le 409 de carence, daté, qui suit un changement de destination
  /// (`DelaiCarenceNumero`, space_learn_livres). Les deux s'affichent avec le
  /// message du serveur, sans bouton « Réessayer » : réessayer avant l'heure
  /// dite ne peut pas aboutir.
  ///
  /// `if (!mounted) return;` après CHAQUE await : la saisie du montant ouvre un
  /// dialogue, le jeton se lit sur disque, la requête part sur le réseau. Trois
  /// occasions pour l'écran de disparaître entre-temps.
  Future<void> _demanderRetrait() async {
    final montant = await _saisirMontant();
    if (!mounted) return;
    if (montant == null) return;

    setState(() => _retraitEnCours = true);
    try {
      final token = await TokenStorage.getToken();
      if (!mounted) return;
      if (token == null) throw Exception('Session expirée');

      await _service.demanderRetrait(authToken: token, montant: montant);

      if (!mounted) return;
      AppNotifications.showSnackBar(
        context,
        message:
            'Demande enregistrée. Le virement part vers votre Mobile Money.',
        isSuccess: true,
      );
      await _charger();
    } on ReversementException catch (e) {
      if (!mounted) return;
      setState(() => _retraitEnCours = false);

      // Le numéro manquant est la seule erreur qui appelle une action
      // immédiate : on emmène l'auteur là où il peut la corriger.
      if (e.numeroManquant) {
        await _ouvrirCompteVersement();
        return;
      }

      // UN REFUS DE DROIT NE TIENT PAS DANS QUATRE SECONDES.
      //
      // C'est le raisonnement que l'écran de connexion tient déjà pour les
      // 403 de compte fermé — « on ne recopie pas une adresse en quatre
      // secondes » — et il s'appliquait à l'envers ici. Le 409 de carence
      // porte 239 caractères, une DATE, une HEURE et la consigne « changez
      // votre mot de passe sans attendre » : il sortait dans un message
      // furtif de quatre secondes (app_notifications.dart), et il n'existe
      // aucun autre endroit de l'application où le relire.
      //
      // Le dialogue ne propose PAS de réessayer : réessayer un refus de droit
      // ne peut par construction jamais aboutir, et celui de la carence est
      // DATÉ — il faut attendre l'heure dite, pas insister. Une panne du
      // serveur, elle, reste un message furtif : c'est un état passager et le
      // geste évident est de recommencer là où l'on est.
      if (e.statusCode == 400 || e.statusCode == 409) {
        await AppNotifications.showPremiumDialog(
          context,
          title: "Retrait refusé",
          message: e.message,
          confirmText: "Fermer",
          isError: true,
        );
        // Le refus de carence vient peut-être d'apprendre à l'écran ce qu'il
        // ignorait : on relit les coordonnées pour que le bandeau porte
        // désormais l'échéance, au lieu de laisser le prochain appui rejouer
        // la même découverte.
        if (mounted) await _charger();
        return;
      }

      AppNotifications.showSnackBar(
        context,
        message: e.message,
        isSuccess: false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _retraitEnCours = false);
      AppNotifications.showSnackBar(
        context,
        message: messageLisible(e, repli: "Action impossible pour le moment."),
        isSuccess: false,
      );
    } finally {
      if (mounted) setState(() => _retraitEnCours = false);
    }
  }

  /// Demande le montant à retirer, prérempli avec la totalité du disponible.
  Future<double?> _saisirMontant() async {
    final solde = _portefeuille.solde;
    final controleur = TextEditingController(
      text: solde.disponible.round().toString(),
    );
    final cleFormulaire = GlobalKey<FormState>();

    final p = _portefeuille;
    final minimum = p.minimumRetraitAbsolu;
    final maximum = solde.disponible;

    return showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusPill),
        ),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, rafraichir) {
          final montantActuel = (double.tryParse(controleur.text) ?? 0).clamp(
            0.0,
            maximum,
          );
          final sliderValue = montantActuel.clamp(minimum, maximum);

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Form(
                key: cleFormulaire,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Poignée ──
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.textPrimary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(
                            AppDimensions.radiusXs,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Titre ──
                    Text(
                      'Montant à retirer',
                      style: GoogleFonts.poppins(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // ── Infos ──
                    Row(
                      children: [
                        _infoPuce(
                          'Disponible',
                          _montant(solde.disponible),
                          AppColors.success,
                        ),
                        const SizedBox(width: 16),
                        _infoPuce(
                          'Minimum',
                          _montant(minimum),
                          AppColors.warning,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── Champ de saisie + bouton MAX ──
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: controleur,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            autofocus: true,
                            onChanged: (_) => rafraichir(() {}),
                            style: GoogleFonts.poppins(
                              color: AppColors.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                            decoration: InputDecoration(
                              suffixText: solde.devise,
                              suffixStyle: GoogleFonts.poppins(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                              ),
                              filled: true,
                              fillColor: AppColors.scaffoldBackground,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  AppDimensions.radiusInner,
                                ),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  AppDimensions.radiusInner,
                                ),
                                borderSide: BorderSide(
                                  color: AppColors.border,
                                  width: 1,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  AppDimensions.radiusInner,
                                ),
                                borderSide: BorderSide(
                                  color: AppColors.secondaryVariant,
                                  width: 1.5,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                            validator: (v) {
                              final montant = double.tryParse(v ?? '');
                              if (montant == null || montant <= 0) {
                                return 'Montant invalide';
                              }
                              if (montant < minimum) {
                                return 'Minimum ${_montant(minimum)}';
                              }
                              if (montant > solde.disponible) {
                                return 'Supérieur au solde';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Bouton MAX
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: GestureDetector(
                            onTap: () {
                              controleur.text = maximum.round().toString();
                              controleur.selection = TextSelection.collapsed(
                                offset: controleur.text.length,
                              );
                              rafraichir(() {});
                              HapticFeedback.lightImpact();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.secondaryVariant.withOpacity(
                                  0.12,
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppDimensions.radiusInner,
                                ),
                              ),
                              child: Text(
                                'MAX',
                                style: GoogleFonts.poppins(
                                  color: AppColors.secondaryVariant,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // ── Slider ──
                    if (maximum > minimum)
                      SliderTheme(
                        data: SliderThemeData(
                          activeTrackColor: AppColors.secondaryVariant,
                          inactiveTrackColor: AppColors.secondaryVariant
                              .withOpacity(0.15),
                          thumbColor: AppColors.secondaryVariant,
                          overlayColor: AppColors.secondaryVariant.withOpacity(
                            0.12,
                          ),
                          trackHeight: 4,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 8,
                          ),
                        ),
                        child: Slider(
                          value: sliderValue,
                          min: minimum,
                          max: maximum,
                          onChanged: (val) {
                            controleur.text = val.round().toString();
                            controleur.selection = TextSelection.collapsed(
                              offset: controleur.text.length,
                            );
                            rafraichir(() {});
                          },
                        ),
                      ),

                    // ── Aperçu du virement ──
                    _apercuDuVirement(p, montantActuel),
                    const SizedBox(height: 24),

                    // ── Bouton Confirmer pleine largeur ──
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () {
                          if (!cleFormulaire.currentState!.validate()) return;
                          HapticFeedback.mediumImpact();
                          Navigator.of(
                            context,
                          ).pop(double.parse(controleur.text));
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondaryVariant,
                          foregroundColor: AppColors.onAccent,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppDimensions.radiusInner,
                            ),
                          ),
                        ),
                        child: Text(
                          'Confirmer le retrait',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // ── Annuler ──
                    Center(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          'Annuler',
                          style: GoogleFonts.poppins(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Puce d'info compacte pour le bottom sheet (Disponible / Minimum).
  Widget _infoPuce(String label, String valeur, Color couleur) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: couleur.withOpacity(0.08),
          borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              valeur,
              style: GoogleFonts.poppins(
                color: couleur,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Ce que l'auteur touchera vraiment, dit avant qu'il ne confirme.
  ///
  /// Le seuil de retrait n'était pas un seuil mais une porte : sous 5 000 F,
  /// rien ne sortait. Un auteur qui n'a qu'un seul livre voyait son
  /// portefeuille monter sans jamais pouvoir y toucher. Le virement reste
  /// offert au-dessus du seuil ; en dessous, il est possible, frais retenus —
  /// et c'est ici qu'ils s'annoncent.
  Widget _apercuDuVirement(Portefeuille p, double montant) {
    if (montant <= 0 || montant > p.solde.disponible) {
      return const SizedBox.shrink();
    }

    final frais = p.fraisPour(montant);
    if (frais <= 0) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text(
          // « Virement offert » n'a de sens que s'il peut être payant. Quand
          // aucun frais n'existe, on dit simplement ce qui arrive.
          p.desFraisExistent
              ? 'Virement offert : vous recevrez ${_montant(p.versePour(montant))}.'
              : 'Vous recevrez ${_montant(p.versePour(montant))}, sans aucun frais.',
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.accentInk,
            height: 1.4,
          ),
        ),
      );
    }

    final manque = p.minimumRetrait - montant;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Vous recevrez ${_montant(p.versePour(montant))} '
            '(${_montant(frais)} de frais d\'opérateur).',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              height: 1.4,
            ),
          ),
          if (manque > 0) ...[
            const SizedBox(height: 4),
            Text(
              'Encore ${_montant(manque)} et le virement devient gratuit.',
              style: GoogleFonts.poppins(
                fontSize: 11.5,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _annulerRetrait(RetraitModel retrait) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: Text(
          'Annuler ce retrait ?',
          style: GoogleFonts.poppins(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        content: Text(
          'Les ${_montant(retrait.montant, retrait.devise)} retourneront à votre solde disponible.',
          style: GoogleFonts.poppins(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Non',
              style: GoogleFonts.poppins(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Oui, annuler',
              style: GoogleFonts.poppins(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirme != true) return;

    try {
      final token = await TokenStorage.getToken();
      if (token == null) throw Exception('Session expirée');
      await _service.annulerRetrait(authToken: token, retraitId: retrait.id);
      if (!mounted) return;
      AppNotifications.showSnackBar(
        context,
        message: 'Retrait annulé, le montant est de nouveau disponible.',
        isSuccess: true,
      );
      await _charger();
    } catch (e) {
      if (!mounted) return;
      AppNotifications.showSnackBar(
        context,
        message: messageLisible(e, repli: "Action impossible pour le moment."),
        isSuccess: false,
      );
      // Un refus veut le plus souvent dire que le virement vient d'être pris
      // en main : l'écran montrerait encore un bouton « Annuler » sur une
      // ligne qui a déjà bougé.
      await _charger();
    }
  }

  // ──────────────────────────── Rendu ────────────────────────────

  @override
  Widget build(BuildContext context) {
    AppColors.suivreLeTheme(context);
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.scaffoldBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Mes gains',
          style: GoogleFonts.poppins(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Compte de versement',
            icon: Icon(
              Icons.account_balance_wallet_outlined,
              color: AppColors.textPrimary,
            ),
            onPressed: _ouvrirCompteVersement,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.accentInk))
          : _avecRelance(
              ListView(
                padding: const EdgeInsets.all(AppDimensions.screenPadding),
                children: [
                  // UN BANDEAU SANS GESTE, SUR L'ÉCRAN DE L'ARGENT.
                  //
                  // `onTap` est facultatif et n'était pas passé : une panne
                  // comme une session morte s'affichaient là sans aucune
                  // sortie. Le geste suit la cause, comme partout ailleurs :
                  // se reconnecter sur un jeton mort, réessayer sur une panne.
                  //
                  // C'ÉTAIT LA MOITIÉ DU CORRECTIF, ET L'AUTRE MOITIÉ EST
                  // AU-DESSUS : voir [_avecRelance]. Le commentaire qui tenait
                  // cette place disait le geste de rafraîchissement désarmé —
                  // « restait armé et rejouait la requête refusée à chaque
                  // tirage », au passé — alors qu'il l'était encore trois
                  // lignes plus bas, sans aucune condition.
                  if (_erreur != null) ...[
                    _bandeau(
                      Icons.error_outline,
                      AppColors.error,
                      _sessionFinie ? "$_erreur Se reconnecter." : _erreur!,
                      onTap: _sessionFinie ? _seReconnecter : _charger,
                    ),
                    const SizedBox(height: AppDimensions.sectionGap),
                  ],
                  // LA CARENCE S'ANNONCE AVANT LA DEMANDE, PAS APRÈS LE REFUS.
                  //
                  // Le serveur arme vingt-quatre heures dès que la destination
                  // des virements change — première inscription comprise — et
                  // refuse ensuite le retrait par un 409 daté. Sans cette
                  // ligne, l'auteur ne l'apprenait qu'en demandant son argent,
                  // dans un message furtif. Voir [_finDeCarence].
                  //
                  // Pas d'`onTap` : c'est un refus de DROIT daté, aucun geste
                  // ne peut le lever avant l'heure dite.
                  if (_finDeCarence != null) ...[
                    _bandeau(
                      Icons.gpp_maybe,
                      AppColors.warning,
                      "Le numéro qui reçoit vos virements a été changé "
                      "récemment. Aucun retrait n'est possible avant le "
                      "${_quand(_finDeCarence!)}.",
                    ),
                    const SizedBox(height: AppDimensions.sectionGap),
                  ],
                  // La panne se dit, et elle mène à « Réessayer » — pas à la
                  // saisie d'un numéro. Proposer d'aller enregistrer une
                  // destination parce qu'on n'a pas réussi à lire l'actuelle,
                  // c'est exactement le geste qui changeait la destination des
                  // virements sur un incident passager.
                  if (_erreurCoordonnees != null) ...[
                    _bandeau(
                      Icons.error_outline,
                      AppColors.error,
                      "$_erreurCoordonnees Réessayez.",
                      onTap: _charger,
                    ),
                    const SizedBox(height: AppDimensions.sectionGap),
                  ] else if (_numeroManquant == true) ...[
                    _bandeau(
                      Icons.warning_amber_rounded,
                      AppColors.warning,
                      "Renseignez votre numéro Mobile Money pour pouvoir retirer vos gains.",
                      onTap: _ouvrirCompteVersement,
                    ),
                    const SizedBox(height: AppDimensions.sectionGap),
                  ],
                  _carteSolde(),
                  const SizedBox(height: AppDimensions.sectionGap),
                  if (_portefeuille.retraits.isNotEmpty) ...[
                    _titre('Mes retraits'),
                    const SizedBox(height: AppDimensions.spaceMd),
                    ..._portefeuille.retraits.map(_ligneRetrait),
                    const SizedBox(height: AppDimensions.sectionGap),
                  ],
                  _titre('Mes ventes'),
                  const SizedBox(height: AppDimensions.spaceMd),
                  if (_portefeuille.ventes.isEmpty)
                    _etatVide()
                  else
                    ..._portefeuille.ventes.map(_ligneVente),
                ],
              ),
            ),
    );
  }

  /// Le geste de rafraîchissement, et seulement quand il peut aboutir.
  ///
  /// SUR UNE SESSION MORTE, IL NE LE PEUT PAS. Chaque tirage relançait
  /// `_charger`, qui relit un jeton absent et repose la même erreur : une
  /// boucle sous le doigt, sur l'écran de l'argent. Le bandeau de [_erreur]
  /// porte déjà le seul geste qui aboutisse — « Se reconnecter » — et le
  /// laisser sous un geste de relance armé, c'était proposer les deux à la
  /// fois. Le laisser « pour ne pas empêcher de réessayer » ne retirait pas la
  /// boucle, il la cachait : c'est le mot du salon de forum
  /// (forum_messages_page.dart), qui a retiré le sien pour la même raison, et
  /// celui de la conversation privée depuis ce tour.
  ///
  /// Une PANNE garde le sien : réessayer y a un sens, et c'est le geste le plus
  /// naturel sur cet écran.
  Widget _avecRelance(Widget contenu) {
    if (_sessionFinie) return contenu;
    return RefreshIndicator(
      onRefresh: _charger,
      color: AppColors.accentInk,
      child: contenu,
    );
  }

  Widget _titre(String texte) => Text(
    texte,
    style: GoogleFonts.poppins(
      fontSize: 16,
      fontWeight: FontWeight.bold,
      color: AppColors.textPrimary,
    ),
  );

  Widget _carteSolde() {
    final solde = _portefeuille.solde;
    final pourcentage = (_portefeuille.tauxCommission * 100).round();
    final peutRetirer = _portefeuille.retraitPossible && !_retraitEnCours;

    return AppCard(
      padding: const EdgeInsets.all(AppDimensions.spaceXl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Iconsax.wallet_3, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                'Solde disponible',
                style: GoogleFonts.poppins(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spaceXs),
          Text(
            _montant(solde.disponible),
            style: GoogleFonts.poppins(
              color: AppColors.accentInk,
              fontSize: 30,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppDimensions.spaceLg),
          Divider(color: AppColors.borderLight, height: 1),
          const SizedBox(height: AppDimensions.spaceLg),
          Row(
            children: [
              Expanded(
                child: _statistique('Total gagné', _montant(solde.totalGagne)),
              ),
              Expanded(
                child: _statistique('Déjà retiré', _montant(solde.totalRetire)),
              ),
            ],
          ),
          if (solde.enCours > 0) ...[
            const SizedBox(height: AppDimensions.spaceMd),
            _statistique('Retrait en cours', _montant(solde.enCours)),
          ],
          const SizedBox(height: AppDimensions.spaceXl),
          SizedBox(
            height: 48,
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: peutRetirer ? _demanderRetrait : null,
              icon: _retraitEnCours
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.onAccent,
                      ),
                    )
                  : const Icon(Icons.south_west_rounded, size: 18),
              label: Text(
                'Retirer',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onAccent,
                disabledBackgroundColor: AppColors.primary.withValues(
                  alpha: 0.35,
                ),
                disabledForegroundColor: AppColors.onAccent.withValues(
                  alpha: 0.5,
                ),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppDimensions.radiusInner,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.spaceMd),
          // Deux seuils, deux phrases distinctes. « Retrait possible à partir
          // de 5 000 » était faux depuis que le virement est ouvert dès le
          // plancher absolu — et c'était la phrase qui faisait croire à
          // l'auteur que son argent était retenu.
          Text(
            !_portefeuille.retraitPossible
                ? 'Retrait possible à partir de '
                      '${_montant(_portefeuille.minimumRetraitAbsolu)}. '
                      'Commission de la plateforme : $pourcentage % sur chaque vente.'
                : _portefeuille.desFraisExistent &&
                      _portefeuille.solde.disponible <
                          _portefeuille.minimumRetrait
                ? 'Virement offert à partir de '
                      '${_montant(_portefeuille.minimumRetrait)} ; en dessous, '
                      'les frais d\'opérateur sont retenus. '
                      'Commission de la plateforme : $pourcentage % sur chaque vente.'
                : 'Virement sans frais. '
                      'Commission de la plateforme : $pourcentage % sur chaque vente.',
            style: GoogleFonts.poppins(
              color: AppColors.textHint,
              fontSize: 11.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statistique(String libelle, String valeur) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        libelle,
        style: GoogleFonts.poppins(
          color: AppColors.textSecondary,
          fontSize: 11.5,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        valeur,
        style: GoogleFonts.poppins(
          color: AppColors.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );

  Widget _bandeau(
    IconData icone,
    Color couleur,
    String texte, {
    VoidCallback? onTap,
  }) {
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icone, color: couleur, size: 22),
          const SizedBox(width: AppDimensions.spaceMd),
          Expanded(
            child: Text(
              texte,
              style: GoogleFonts.poppins(
                color: AppColors.textPrimary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
          if (onTap != null)
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: AppColors.textHint,
              size: 14,
            ),
        ],
      ),
    );
  }

  Widget _etatVide() => AppCard(
    padding: const EdgeInsets.all(AppDimensions.spaceXl),
    child: Column(
      children: [
        Icon(
          Icons.receipt_long_outlined,
          size: 44,
          color: AppColors.textSecondary,
        ),
        const SizedBox(height: AppDimensions.spaceMd),
        Text(
          'Aucune vente pour le moment',
          style: GoogleFonts.poppins(
            color: AppColors.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );

  Widget _ligneRetrait(RetraitModel retrait) {
    final (couleur, icone) = switch (retrait.statut) {
      'payee' => (AppColors.success, Icons.check_rounded),
      'en_cours' => (AppColors.primary, Icons.sync_rounded),
      // La flèche de rafraîchissement disait « ça repart » ; rien ne repart.
      // « echouee » est terminal côté serveur — aucune relance ne reprend la
      // ligne — et le montant est déjà revenu au disponible. L'icône dit donc
      // un arrêt, pas une reprise ; le libellé, à côté, dit quoi faire
      // (reversement_model.dart, libelleStatut).
      'echouee' => (AppColors.error, Icons.error_outline_rounded),
      'annulee' => (AppColors.textHint, Icons.close_rounded),
      // Un virement dont le sort est inconnu portait l'horloge de l'attente
      // ordinaire : à l'œil, rien ne le distinguait d'une demande déposée la
      // veille. Le point d'interrogation dit ce qu'il en est — on ne sait pas
      // encore, et c'est précisément pour cela que la somme ne revient pas.
      'incertain' => (AppColors.warning, Icons.help_outline_rounded),
      _ => (AppColors.warning, Icons.schedule_rounded),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spaceMd),
      child: AppCard(
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: couleur.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icone, color: couleur, size: 18),
            ),
            const SizedBox(width: AppDimensions.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _montant(retrait.montant, retrait.devise),
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _sousTitre(retrait),
                    style: GoogleFonts.poppins(
                      color: AppColors.textSecondary,
                      fontSize: 11.5,
                    ),
                  ),
                  // LE MOTIF DU SERVEUR, LU DEPUIS TOUJOURS ET AFFICHÉ NULLE
                  // PART.
                  //
                  // `RetraitModel.derniereErreur` était parsé et jeté : le
                  // libellé de statut était tout ce que l'auteur voyait. Or
                  // c'est ce champ, et lui seul, qui distingue les quatre fins
                  // d'un retrait « echouee » — une clôture après tentatives
                  // (personne n'a refusé, aucun ordre n'est parti), un refus de
                  // l'opérateur, une régularisation, un refus faute de numéro —
                  // et il porte le geste qui débloque : « renseignez vos
                  // coordonnées de paiement », « vérifiez le numéro Mobile
                  // Money enregistré ». Sur téléphone, il n'arrivait que par la
                  // notification. Le site l'affiche depuis toujours
                  // (SalesReports.tsx) : un serveur, deux vérités.
                  //
                  // Il est montrable sans réserve depuis que la cause technique
                  // est partie dans `note_exploitation` — voir
                  // `RetraitModel.derniereErreur`.
                  if ((retrait.derniereErreur ?? '').trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        retrait.derniereErreur!.trim(),
                        style: GoogleFonts.poppins(
                          color: AppColors.textSecondary,
                          fontSize: 11.5,
                          height: 1.35,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (retrait.estAnnulable)
              TextButton(
                onPressed: () => _annulerRetrait(retrait),
                child: Text(
                  'Annuler',
                  style: GoogleFonts.poppins(
                    color: AppColors.error,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _sousTitre(RetraitModel retrait) {
    final date = retrait.traiteLe ?? retrait.demandeLe;
    final quand = date == null
        ? ''
        : ' • ${DateFormat('d MMM y', 'fr_FR').format(date.toLocal())}';
    return '${retrait.libelleStatut}$quand';
  }

  Widget _ligneVente(ReversementModel vente) {
    final titre = _titresParLivre[vente.livreId] ?? 'Livre';
    // La date de la VENTE, et non celle du crédit.
    //
    // Les deux diffèrent dès qu'un crédit a été rattrapé après coup : une
    // vente du 20 juillet, créditée le 17 août, s'affichait « 17 août ».
    // L'auteur ne pouvait rapprocher son rapport de rien de ce qu'il savait.
    final date = vente.dateAAfficher;
    final quand = date == null
        ? ''
        : DateFormat('d MMM y', 'fr_FR').format(date.toLocal());

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spaceMd),
      child: AppCard(
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Iconsax.book_1, color: AppColors.success, size: 18),
            ),
            const SizedBox(width: AppDimensions.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                  if (quand.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      quand,
                      style: GoogleFonts.poppins(
                        color: AppColors.textSecondary,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppDimensions.spaceSm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '+ ${_montant(vente.montantNet, vente.devise)}',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    color: AppColors.success,
                    fontSize: 14,
                  ),
                ),
                // Le prix de vente est rappelé pour que l'auteur puisse
                // rapprocher ce qu'il touche de ce que l'acheteur a payé.
                Text(
                  'sur ${_montant(vente.montantBrut, vente.devise)}',
                  style: GoogleFonts.poppins(
                    color: AppColors.textHint,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
