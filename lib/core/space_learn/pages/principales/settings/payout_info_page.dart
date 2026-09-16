import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:space_learn_flutter/core/services/session_service.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/reversementService.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/reversement_model.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/auth/login.dart';
import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/themes/app_dimensions.dart';
import 'package:space_learn_flutter/core/themes/widgets/app_card.dart';
import 'package:space_learn_flutter/core/utils/app_notifications.dart';
import 'package:space_learn_flutter/core/utils/token_storage.dart';
import 'package:space_learn_flutter/core/utils/message_erreur.dart';

/// Saisie du numéro Mobile Money vers lequel l'auteur est payé.
///
/// Sans ce numéro, les reversements restent au statut « sans_infos » : la somme
/// est bien enregistrée comme due, mais aucun virement ne peut partir.
class PayoutInfoPage extends StatefulWidget {
  const PayoutInfoPage({super.key});

  @override
  State<PayoutInfoPage> createState() => _PayoutInfoPageState();
}

class _PayoutInfoPageState extends State<PayoutInfoPage> {
  final _formKey = GlobalKey<FormState>();
  final _reversementService = ReversementService();

  final _telephoneController = TextEditingController();
  final _nomController = TextEditingController();

  /// Indicatifs des pays couverts par CinetPay en zone Mobile Money.
  ///
  /// LA LISTE DE RÉFÉRENCE EST CELLE DU SERVEUR, ET IL EN MANQUAIT DEUX. C'est
  /// la boucle de `DecouperNumero` (space_learn_livres,
  /// modules/reversement/service.go:1139) qui fait foi : ONZE indicatifs, dont
  /// 242 et 243. Ce menu n'en portait que neuf.
  ///
  /// CE QUE LES DEUX MANQUANTS COÛTAIENT, ET LE TOUR PRÉCÉDENT A AGGRAVÉ LA
  /// FACTURE. Pour un auteur dont le téléphone est congolais, le serveur
  /// propose `prefix = "242"` à l'ouverture de cet écran ; la ligne qui suivait
  /// jetait cette valeur sans un mot et laissait '225' sélectionné. Appuyer sur
  /// « Enregistrer » sur le numéro que l'écran venait lui-même de proposer
  /// changeait donc la DESTINATION des virements : depuis que la carence s'arme
  /// aussi à la première inscription, le serveur bloque alors les retraits
  /// vingt-quatre heures et écrit à l'auteur « rétablissez votre numéro et
  /// changez votre mot de passe sans attendre » — pour un changement qu'il n'a
  /// pas fait et que rien ne lui a demandé. Et le virement partait vers
  /// « +225 » suivi d'un numéro du Congo.
  static const List<(String, String)> _indicatifs = [
    ('225', "Côte d'Ivoire"),
    ('221', 'Sénégal'),
    ('226', 'Burkina Faso'),
    ('227', 'Niger'),
    ('228', 'Togo'),
    ('229', 'Bénin'),
    ('223', 'Mali'),
    ('224', 'Guinée'),
    ('237', 'Cameroun'),
    ('242', 'Congo-Brazzaville'),
    ('243', 'RD Congo'),
  ];

  String _prefix = '225';

  /// Un indicatif rendu par le serveur que [_indicatifs] ne connaît pas.
  ///
  /// AJOUTÉ AU MENU ET SÉLECTIONNÉ, PLUTÔT QUE REMPLACÉ EN SILENCE. Ajouter les
  /// deux manquants ne suffit pas : le jour où le serveur en reconnaîtra un
  /// douzième, la même bascule muette vers '225' recommencerait — et un
  /// indicatif remplacé sans un mot EST un changement de destination, avec sa
  /// carence de vingt-quatre heures et son avis d'alerte à l'auteur. Mieux vaut
  /// une entrée sans nom de pays qu'un numéro qu'on abîme.
  String? _indicatifHorsTable;

  /// Le menu réellement affiché : la table, plus l'éventuel hors-table.
  List<(String, String)> get _choixDIndicatifs => [
    ..._indicatifs,
    if (_indicatifHorsTable != null) (_indicatifHorsTable!, ''),
  ];
  bool _isLoading = true;
  bool _isSaving = false;
  bool _dejaEnregistre = false;

  /// La lecture des coordonnées a-t-elle échoué ?
  ///
  /// UN FORMULAIRE VIDE EST UNE RÉPONSE, ET C'ÉTAIT LA PIRE. Le `catch (_)`
  /// qui vivait ici avalait tout : sur une panne de lecture, la page s'ouvrait
  /// sur des champs vides, exactement comme pour un auteur qui n'a jamais rien
  /// enregistré. Il suffisait alors d'un enregistrement pour changer la
  /// destination des virements pour de bon — et pour armer les vingt-quatre
  /// heures de carence sur un geste qu'une panne avait suggéré.
  ///
  /// Le serveur répond maintenant 500 « Vos coordonnées de paiement n'ont pas
  /// pu être lues » là où il rendait un faux « Aucune coordonnée enregistrée »
  /// (space_learn_livres, modules/reversement/controller.go). C'est une PANNE :
  /// on montre sa phrase et un bouton « Réessayer », et on ne montre pas le
  /// formulaire — il n'y a rien à enregistrer tant qu'on ne sait pas ce qui est
  /// déjà là.
  String? _erreurChargement;

  /// L'instant où les retraits redeviennent possibles, quand le serveur a armé
  /// la carence de vingt-quatre heures. Nul le reste du temps.
  ///
  /// Voir [InfosPaiementModel.finDeCarence] : c'est le serveur qui décide, cet
  /// écran ne fait que le dire — avant que l'auteur n'aille demander son
  /// argent, plutôt qu'après le refus.
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

  @override
  void dispose() {
    _telephoneController.dispose();
    _nomController.dispose();
    super.dispose();
  }

  Future<void> _charger() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _erreurChargement = null;
      });
    }
    try {
      final token = await TokenStorage.getToken();
      if (!mounted) return;
      if (token == null) {
        setState(() {
          _isLoading = false;
          _erreurChargement = phraseSessionExpiree;
        });
        return;
      }

      final infos = await _reversementService.getInfosPaiement(token);
      if (!mounted) return;

      setState(() {
        if (infos != null) {
          // L'INDICATIF DU SERVEUR EST TOUJOURS RETENU — voir
          // [_indicatifHorsTable]. La condition qui vivait ici le jetait quand
          // la table ne le connaissait pas, sans un mot et sans que rien ne le
          // signale : `_prefix` restait '225', et l'enregistrement suivant
          // changeait la destination des virements.
          if (infos.prefix.isNotEmpty) {
            _prefix = infos.prefix;
            _indicatifHorsTable = _indicatifs.any((i) => i.$1 == infos.prefix)
                ? null
                : infos.prefix;
          }
          _telephoneController.text = infos.telephone;
          _nomController.text = infos.nomComplet;
          _dejaEnregistre = infos.estRenseigne;
          _finDeCarence = infos.finDeCarence;
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _erreurChargement = messageLisible(
          e,
          repli: "Vos coordonnées de paiement n'ont pas pu être lues.",
        );
      });
    }
  }

  Future<void> _enregistrer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final token = await TokenStorage.getToken();
      if (token == null) throw Exception('Session expirée');

      final infos = await _reversementService.setInfosPaiement(
        authToken: token,
        prefix: _prefix,
        telephone: _telephoneController.text.trim(),
        nomComplet: _nomController.text.trim(),
      );

      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _dejaEnregistre = true;
        _finDeCarence = infos.finDeCarence;
      });
      // ON ANNONCE LE FAIT, PLUS LA PROMESSE.
      //
      // « Numéro enregistré. Vos prochaines ventes y seront versées. » est
      // FAUX dans le cas le plus courant : dès que le numéro enregistré diffère
      // de la destination précédente — Y COMPRIS À LA PREMIÈRE INSCRIPTION —
      // le serveur arme vingt-quatre heures de carence et refuse le retrait
      // suivant par un 409 daté (space_learn_livres,
      // modules/reversement/controller.go). L'écran annonçait donc un
      // versement à l'instant où le serveur venait de le bloquer, et l'auteur
      // découvrait la carence en demandant son argent.
      //
      // La date vient du serveur (`numero_change_le`), jamais d'une horloge
      // posée ici : voir [InfosPaiementModel.finDeCarence]. Quand elle est
      // absente, rien n'a été armé — le numéro est identique au précédent — et
      // la phrase d'origine redevient vraie.
      final fin = infos.finDeCarence;
      AppNotifications.showSnackBar(
        context,
        message: fin == null
            ? 'Numéro enregistré. Vos prochaines ventes y seront versées.'
            : 'Numéro enregistré. Par sécurité, aucun retrait ne partira vers '
                  'ce numéro avant le ${_quand(fin)}.',
        isSuccess: true,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      AppNotifications.showSnackBar(
        context,
        message: messageLisible(e, repli: "Enregistrement impossible."),
        isSuccess: false,
      );
    }
  }

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
          'Compte de versement',
          style: GoogleFonts.poppins(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.accentInk))
          : _erreurChargement != null
          // Ni formulaire, ni champs vides : voir [_erreurChargement]. Une
          // session morte ne se réessaie pas non plus, et elle ne sort PAS
          // d'ici toute seule — voir [_etatDePanne], qui l'y mène.
          ? _etatDePanne()
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(AppDimensions.screenPadding),
                children: [
                  AppCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          _dejaEnregistre
                              ? Icons.check_circle_outline
                              : Icons.info_outline,
                          color: _dejaEnregistre
                              ? AppColors.success
                              : AppColors.accentInk,
                          size: 22,
                        ),
                        const SizedBox(width: AppDimensions.spaceMd),
                        Expanded(
                          child: Text(
                            _dejaEnregistre
                                ? "Vos ventes sont versées sur ce numéro, après déduction de la commission de la plateforme."
                                : "Renseignez le numéro Mobile Money sur lequel recevoir vos ventes. Tant qu'il est absent, vos gains sont enregistrés mais ne peuvent pas vous être virés.",
                            style: GoogleFonts.poppins(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // LA CARENCE SE DIT ICI, PAS AU MOMENT DU REFUS.
                  //
                  // C'est un refus de DROIT et il est DATÉ : aucun bouton
                  // « Réessayer », réessayer avant l'heure dite ne peut pas
                  // aboutir. Le serveur reste seul juge — l'écran n'empêche
                  // rien, il annonce.
                  if (_finDeCarence != null) ...[
                    const SizedBox(height: AppDimensions.spaceMd),
                    AppCard(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.gpp_maybe,
                            color: AppColors.warning,
                            size: 22,
                          ),
                          const SizedBox(width: AppDimensions.spaceMd),
                          Expanded(
                            child: Text(
                              "Le numéro qui reçoit vos virements a été changé "
                              "récemment. Aucun retrait n'est possible avant le "
                              "${_quand(_finDeCarence!)}.",
                              style: GoogleFonts.poppins(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: AppDimensions.sectionGap),

                  Text(
                    'Pays',
                    style: GoogleFonts.poppins(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spaceSm),
                  DropdownButtonFormField<String>(
                    value: _prefix,
                    decoration: _decoration(),
                    dropdownColor: AppColors.cardBackground,
                    style: GoogleFonts.poppins(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                    items: _choixDIndicatifs
                        .map(
                          (i) => DropdownMenuItem(
                            value: i.$1,
                            // Une entrée hors table n'a pas de nom de pays :
                            // on montre l'indicatif seul plutôt que d'en
                            // inventer un. Voir [_indicatifHorsTable].
                            child: Text(
                              i.$2.isEmpty ? '+${i.$1}' : '${i.$2}  (+${i.$1})',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _prefix = v);
                    },
                  ),
                  const SizedBox(height: AppDimensions.spaceLg),

                  Text(
                    'Numéro Mobile Money',
                    style: GoogleFonts.poppins(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spaceSm),
                  TextFormField(
                    controller: _telephoneController,
                    keyboardType: TextInputType.phone,
                    style: GoogleFonts.poppins(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                    decoration: _decoration(hint: '07 00 00 00 00'),
                    validator: (v) {
                      final chiffres = (v ?? '').replaceAll(
                        RegExp(r'[^0-9]'),
                        '',
                      );
                      if (chiffres.isEmpty) {
                        return 'Le numéro est obligatoire';
                      }
                      if (chiffres.length < 8) {
                        return 'Numéro trop court';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppDimensions.spaceLg),

                  Text(
                    'Nom du titulaire du compte',
                    style: GoogleFonts.poppins(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spaceSm),
                  TextFormField(
                    controller: _nomController,
                    style: GoogleFonts.poppins(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                    decoration: _decoration(hint: 'Nom et prénoms'),
                  ),
                  const SizedBox(height: AppDimensions.spaceXl),

                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _enregistrer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.onAccent,
                        disabledBackgroundColor: AppColors.primary.withValues(
                          alpha: 0.5,
                        ),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppDimensions.radiusInner,
                          ),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: AppColors.onAccent,
                              ),
                            )
                          : Text(
                              'Enregistrer',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  /// La panne, sa phrase, et le seul geste qui puisse y répondre.
  ///
  /// « Réessayer » a sa place ici — c'est une panne, elle passe. Il n'en a
  /// aucune sur une session morte : ce bouton-là ne peut par construction
  /// jamais aboutir, et `estSessionExpiree` sait faire la différence.
  ///
  /// UNE SESSION MORTE N'OFFRAIT ALORS PLUS RIEN DU TOUT, ET C'ÉTAIT UNE
  /// IMPASSE. Le commentaire qui l'autorisait disait « elle sort d'ici par le
  /// premier 401 venu » : faux dans le cas précis où elle se produit le plus
  /// souvent ici — `_charger` pose la phrase quand le jeton est ABSENT du
  /// coffre, donc AUCUNE requête n'est partie et aucun 401 ne viendra.
  /// L'intercepteur ne peut rien pour un appel qui n'a pas eu lieu. L'écran
  /// mène donc lui-même à la connexion, comme les salons et les
  /// conversations.
  Widget _etatDePanne() {
    final sessionFinie = estSessionExpiree(_erreurChargement);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.screenPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: AppColors.error, size: 40),
            const SizedBox(height: AppDimensions.spaceMd),
            Text(
              _erreurChargement ?? '',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppDimensions.spaceLg),
            if (sessionFinie)
              ElevatedButton.icon(
                onPressed: _seReconnecter,
                icon: const Icon(Icons.login_rounded, size: 18),
                label: Text(
                  'Se reconnecter',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onAccent,
                ),
              )
            else
              ElevatedButton.icon(
                onPressed: _charger,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(
                  'Réessayer',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onAccent,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Fin de session complète, puis retour à l'écran de connexion.
  ///
  /// Même geste que les salons et les conversations : le nettoyage passe par
  /// [SessionService], effacer le seul jeton laisserait le reste derrière.
  Future<void> _seReconnecter() async {
    await SessionService.terminer();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  InputDecoration _decoration({String? hint}) {
    OutlineInputBorder bordure(Color couleur) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDimensions.radiusInner),
      borderSide: BorderSide(color: couleur),
    );

    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.poppins(color: AppColors.textHint, fontSize: 14),
      filled: true,
      fillColor: AppColors.cardBackground,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: bordure(AppColors.border),
      focusedBorder: bordure(AppColors.primary),
      errorBorder: bordure(AppColors.error),
      focusedErrorBorder: bordure(AppColors.error),
    );
  }
}
