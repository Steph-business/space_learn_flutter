import 'package:flutter/material.dart';
import 'package:space_learn_flutter/core/themes/app_dimensions.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/services/book_cache_service.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/bookService.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/paymentService.dart';
import 'package:space_learn_flutter/core/utils/app_notifications.dart';
import 'package:space_learn_flutter/core/utils/message_erreur.dart';
import 'package:space_learn_flutter/core/utils/token_storage.dart';
import '../principales/lecteur/accueil_lecteur_page.dart';
import '../widgets/details/reading_page.dart'; // Ajout de l'import

/// Page de résultat après un paiement CinetPay.
///
/// Le serveur ne rend que DEUX statuts : "ACCEPTED" ou "FAILED_OR_PENDING"
/// (modules/paiement/controller.go). L'ancienne version testait un "REFUSED"
/// que le serveur n'envoie jamais — branche morte — et promettait pour tout le
/// reste « vous serez notifié dès sa validation » : un paiement définitivement
/// refusé par l'opérateur s'affichait donc « en attente » pour toujours.
///
/// Désormais :
///   - le refus définitif se lit sur ce que le serveur dit VRAIMENT
///     (`paiement.statut == "echoue"` ou le statut CinetPay porté par le
///     message), calculé par [CinetpayStatusResult.definitivementEchoue] ;
///   - l'attente ne promet aucune notification : elle explique les deux issues
///     possibles et offre un bouton « Vérifier à nouveau ».
///
/// Widget avec état : le lecteur peut re-vérifier depuis cet écran, et le
/// statut affiché doit pouvoir passer d'« en attente » à « réussi » ou
/// « refusé » sans quitter la page.
class CinetpayResultPage extends StatefulWidget {
  final String status; // "ACCEPTED" ou "FAILED_OR_PENDING"
  final Map<String, dynamic> book; // Ajout du livre complet
  final double montant; // le montant OFFICIEL du serveur (paiement.montant)
  final bool estDefinitivementEchoue; // l'opérateur a refusé, pas juste « pas encore »
  final String transactionId;

  const CinetpayResultPage({
    super.key,
    required this.status,
    required this.book,
    required this.montant,
    this.estDefinitivementEchoue = false,
    required this.transactionId,
  });

  @override
  State<CinetpayResultPage> createState() => _CinetpayResultPageState();
}

class _CinetpayResultPageState extends State<CinetpayResultPage> {
  late String _status;
  late bool _refuse;
  late double _montant;
  bool _verification = false;

  /// Le ménage d'après-paiement, retenu pour être ATTENDU.
  ///
  /// Il était lancé sans être conservé : un appui rapide sur « Lire mon livre »
  /// partait donc en course avec l'effacement du cache, et la liseuse — qui lit
  /// le disque avant toute autre chose — pouvait servir l'extrait écrit à
  /// l'emplacement du livre complet, précisément ce que ce ménage vise à
  /// empêcher. Null tant qu'aucune issue n'est tranchée ; `await` sur null est
  /// licite, l'ouverture n'a donc rien à tester.
  Future<void>? _menage;

  bool get isAccepted => _status.toUpperCase() == 'ACCEPTED';
  bool get isRefused => !isAccepted && _refuse;

  @override
  void initState() {
    super.initState();
    _status = widget.status;
    _refuse = widget.estDefinitivementEchoue;
    _montant = widget.montant;
    // Une issue déjà connue à l'arrivée déclenche le ménage tout de suite :
    // le lecteur peut quitter cet écran par un geste retour sans appuyer sur
    // aucun bouton.
    if (isAccepted || isRefused) _menage = _apresIssueDefinitive();
  }

  /// Ménage d'une transaction close — dans un sens ou dans l'autre.
  ///
  /// - La transaction mémorisée pour ce livre est oubliée : l'écran de paiement
  ///   ne proposera plus de la suivre.
  /// - Sur un succès, le cache du LIVRE COMPLET est invalidé : avant l'achat,
  ///   l'extrait a pu y être écrit sous l'identifiant du livre (l'URL signée de
  ///   widget.book est celle de l'extrait pour un non-possesseur), et la
  ///   liseuse sert toujours le disque d'abord. Sans cette invalidation,
  ///   l'acheteur relisait les deux pages de l'aperçu — définitivement.
  Future<void> _apresIssueDefinitive() async {
    final bookId = (widget.book['id'] ?? widget.book['ID'] ?? '').toString();
    try {
      final userId = await TokenStorage.getUserId();
      if (userId != null && bookId.isNotEmpty) {
        await TransactionEnCoursStore.oublier(userId: userId, livreId: bookId);
      }
    } catch (_) {
      // L'entrée expirera d'elle-même (24 h) : ne pas gêner l'écran pour ça.
    }
    if (isAccepted && bookId.isNotEmpty) {
      // L'URL est ignorée par clearBookCache : la clé est l'identifiant.
      await BookCacheService().clearBookCache(bookId, '', extrait: false);
    }
  }

  /// Re-demande le statut au serveur — le recours offert à la place de la
  /// promesse « vous serez notifié », que rien ne garantissait.
  Future<void> _reVerifier() async {
    if (_verification) return;
    setState(() => _verification = true);

    try {
      final token = await TokenStorage.getToken();
      if (token == null || token.isEmpty) {
        if (!mounted) return;
        AppNotifications.showSnackBar(
          context,
          message: 'Votre session a expiré. Reconnectez-vous.',
          isError: true,
        );
        return;
      }

      final result = await PaymentService().getCinetpayStatus(
        widget.transactionId,
        token,
      );

      if (!mounted) return;
      final etaitTranche = isAccepted || isRefused;
      setState(() {
        _status = result.status;
        _refuse = result.definitivementEchoue;
        // Le montant officiel relu en base, jamais le prix chargé par la fiche.
        final m = result.montantServeur;
        if (m != null) _montant = m;
      });

      if (!etaitTranche && (isAccepted || isRefused)) {
        _menage = _apresIssueDefinitive();
        await _menage;
      }

      if (!mounted) return;
      if (!isAccepted && !isRefused) {
        // Toujours pas tranché : le dire, plutôt que de laisser croire que le
        // bouton n'a rien fait.
        AppNotifications.showSnackBar(
          context,
          message:
              "Pas encore de confirmation de l'opérateur. Vous pouvez re-vérifier dans un instant.",
        );
      }
    } catch (e) {
      if (!mounted) return;
      AppNotifications.showSnackBar(
        context,
        message: messageLisible(
          e,
          repli: "Impossible de vérifier ce paiement. Réessayez.",
        ),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _verification = false);
    }
  }

  /// Ouvre la lecture après un paiement confirmé.
  ///
  /// L'URL portée par widget.book est celle de l'EXTRAIT signé — le serveur la
  /// substitue au manuscrit pour un non-possesseur. La laisser dans l'objet
  /// ouvert faisait télécharger l'extrait À LA PLACE du livre acheté quand le
  /// rafraîchissement échouait (réseau, 500), et l'écrire dans le cache du
  /// livre complet. On la retire d'office : la liseuse redemandera l'adresse
  /// fraîche, débloquée, avec le jeton du compte.
  Future<void> _ouvrirLecture() async {
    if (_verification) return;
    // Le bouton s'occupe (indicateur + désactivation) le temps du ménage et du
    // rechargement : sans cela l'appui restait sans effet visible, et un second
    // appui pouvait empiler deux ouvertures.
    setState(() => _verification = true);
    // Le ménage d'abord : tant que le cache du livre complet peut encore
    // contenir l'aperçu, ouvrir la liseuse revient à servir cet aperçu.
    await _menage;
    Map<String, dynamic> bookToOpen = Map<String, dynamic>.from(widget.book)
      ..remove('fichier_url')
      ..remove('fichierUrl');
    try {
      final token = await TokenStorage.getToken();
      final bookId = (widget.book['id'] ?? widget.book['ID'] ?? '').toString();
      if (token != null && token.isNotEmpty && bookId.isNotEmpty) {
        final freshBook = await BookService().getBookById(
          bookId,
          authToken: token,
        );
        bookToOpen = freshBook.toJson();
      }
    } catch (_) {
      // Les métadonnées locales suffisent : sans fichier_url, la liseuse
      // récupérera elle-même l'adresse du manuscrit complet.
    }
    if (!mounted) return;
    setState(() => _verification = false);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => ReadingPage(book: bookToOpen)),
    );
  }

  void _retourAccueil() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomePageLecteur(profileId: '')),
      (route) => false,
    );
  }

  /// La couleur de l'issue du paiement, prise dans la palette.
  ///
  /// L'écran utilisait `Colors.green`, `Colors.red` et `Colors.orange` — les
  /// teintes de Material, étrangères à la charte et identiques en clair comme
  /// en sombre, là où `success`, `error` et `warning` sont calibrées sur les
  /// deux fonds. C'est l'écran qui annonce à un lecteur qu'il vient de payer :
  /// il ne peut pas être le seul à ne pas ressembler à l'application.
  ///
  /// Une seule définition, appelée trois fois — la teinte du fond, celle du
  /// liseré et celle de l'icône ne peuvent plus diverger.
  static Color _couleurEtat(bool accepte, bool refuse) {
    if (accepte) return AppColors.success;
    if (refuse) return AppColors.error;
    return AppColors.warning;
  }

  @override
  Widget build(BuildContext context) {
    AppColors.suivreLeTheme(context);
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              // Icône de résultat animée
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 600),
                curve: Curves.elasticOut,
                builder: (ctx, val, child) =>
                    Transform.scale(scale: val, child: child),
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _couleurEtat(
                      isAccepted,
                      isRefused,
                    ).withValues(alpha: 0.15),
                    border: Border.all(
                      color: _couleurEtat(isAccepted, isRefused),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    isAccepted
                        ? Icons.check_circle_outline_rounded
                        : isRefused
                        ? Icons.cancel_outlined
                        : Icons.hourglass_top_rounded,
                    size: 52,
                    color: _couleurEtat(isAccepted, isRefused),
                  ),
                ),
              ),
              SizedBox(height: 32),
              Text(
                isAccepted
                    ? 'Paiement réussi !'
                    : isRefused
                    ? 'Paiement refusé'
                    : 'Paiement pas encore confirmé',
                style: GoogleFonts.poppins(
                  color: AppColors.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 12),
              Text(
                isAccepted
                    ? 'Votre paiement de ${_montant.toStringAsFixed(0)} FCFA a été validé.\n"${widget.book['titre'] ?? 'Livre inconnu'}" a été ajouté à votre bibliothèque.'
                    : isRefused
                    ? 'Votre paiement de ${_montant.toStringAsFixed(0)} FCFA a été refusé par votre opérateur.\nVous pouvez réessayer, avec ce moyen de paiement ou un autre.'
                    // Ni promesse de notification, ni faux « en attente » : ce
                    // statut ne tranche pas, et il faut le dire tel quel.
                    : 'Votre paiement de ${_montant.toStringAsFixed(0)} FCFA n\'est pas encore confirmé.\nSi votre opérateur a refusé le paiement, vous pouvez réessayer. Sinon, la validation arrive : re-vérifiez dans un instant.',
                style: GoogleFonts.poppins(
                  color: AppColors.textHint,
                  fontSize: 14,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 32),
              // Détails de la transaction
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.textPrimary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
                  border: Border.all(
                    color: AppColors.textPrimary.withValues(alpha: 0.08),
                  ),
                ),
                child: Column(
                  children: [
                    _buildDetailRow(
                      'Livre',
                      widget.book['titre']?.toString() ?? 'Livre inconnu',
                    ),
                    SizedBox(height: 8),
                    _buildDetailRow(
                      'Montant',
                      '${_montant.toStringAsFixed(0)} FCFA',
                    ),
                    // La ligne « Méthode » a été retirée : elle lisait un champ
                    // payment_method que le serveur ne rend jamais — elle ne
                    // s'était donc jamais affichée.
                    SizedBox(height: 8),
                    _buildDetailRow(
                      'Transaction',
                      widget.transactionId.length > 16
                          ? '${widget.transactionId.substring(0, 16)}...'
                          : widget.transactionId,
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // Bouton d'action principal : lire (réussi), re-vérifier (pas
              // tranché), retour (refusé).
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _verification
                      ? null
                      : () {
                          if (isAccepted) {
                            _ouvrirLecture();
                          } else if (isRefused) {
                            _retourAccueil();
                          } else {
                            _reVerifier();
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isAccepted
                        ? AppColors.primary
                        : isRefused
                        ? AppColors.textHint
                        : AppColors.primaryLight,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusInner,
                      ),
                    ),
                  ),
                  child: _verification
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.textPrimary,
                          ),
                        )
                      : Text(
                          isAccepted
                              ? 'Lire mon livre'
                              : isRefused
                              ? 'Retour à l\'accueil'
                              : 'Vérifier à nouveau',
                          style: GoogleFonts.poppins(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
              // Tant que rien n'est tranché, la sortie reste offerte : le
              // paiement continuera d'être suivi côté serveur, et l'écran de
              // paiement du livre proposera de reprendre cette transaction.
              if (!isAccepted && !isRefused)
                TextButton(
                  onPressed: _verification ? null : _retourAccueil,
                  child: Text(
                    'Retour à l\'accueil',
                    style: GoogleFonts.poppins(
                      color: AppColors.textHint,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(color: AppColors.textHint, fontSize: 12),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
