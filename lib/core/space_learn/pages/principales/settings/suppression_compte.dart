import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:space_learn_flutter/core/space_learn/data/dataServices/authServices.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/auth/bienvenue.dart';
import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/themes/app_dimensions.dart';
import 'package:space_learn_flutter/core/utils/app_notifications.dart';
import 'package:space_learn_flutter/core/utils/message_erreur.dart';

/// Le parcours « Supprimer mon compte », PARTAGÉ par les deux écrans de
/// réglages.
///
/// Il vivait entièrement dans settings_page.dart, côté lecteur, et les
/// réglages auteur n'avaient pas l'entrée du tout : un compte dont le profil
/// est « Auteur » est routé vers HomePageAuteur (main.dart) et n'atteint
/// jamais SettingsPage. Il n'avait donc, dans l'application, aucun moyen de
/// demander la suppression de son compte — deux écrans jumeaux tranchaient en
/// sens contraire le même droit. Recopier deux cents lignes de dialogue aurait
/// garanti qu'elles divergent au premier correctif : le parcours est ici, les
/// deux écrans l'appellent.
///
/// CE QUE CES TEXTES PROMETTENT EST CE QUE LE SERVEUR FAIT, ni plus ni moins.
/// `DeleteAccount` (space_learn_auth, controllers/user.go) exécute un seul
/// `Save(&user)` : statut « supprime », nom affiché remplacé, date de
/// suppression — et `PeutOuvrirSession` referme la porte. L'e-mail, le pseudo,
/// le téléphone, la biographie et la photo restent en base, et aucun travail
/// périodique ne lit `deleted_at` : parler d'« anonymisation des données » ou
/// d'une « suppression définitive après 30 jours » serait promettre au nom
/// d'un serveur qui ne le fait pas.
Future<void> afficherLaSuppressionDeCompte(BuildContext context) {
  return showDialog(
    context: context,
    // Le dialogue RESTE ouvert pendant l'appel, et ne se ferme plus d'un
    // appui à côté : c'est lui qui porte l'attente.
    //
    // Il se fermait auparavant avant même que la requête ne parte, et plus
    // rien ne bougeait à l'écran jusqu'à la réponse du serveur. Sur un réseau
    // lent, la personne rouvrait le dialogue et ré-appuyait : le garde-fou
    // anti-double-appui lui rendait alors la main sans le moindre message —
    // ni dialogue, ni snackbar. Pour un geste irréversible, l'absence totale
    // de retour est le pire des états. Même patron que showLogoutDialog
    // (base_settings_layout.dart) : bouton en attente, actions désactivées.
    //
    // C'est aussi ce dialogue modal, et lui seul, qui empêche le double
    // appui : tant qu'il tient l'écran, l'entrée de liste qui l'a ouvert est
    // hors d'atteinte. Le drapeau `_suppressionEnCours` que portait l'écran
    // des réglages ne gardait donc rien — il a été retiré plutôt que laissé
    // là à se faire prendre pour le vrai garde-fou.
    barrierDismissible: false,
    builder: (dialogContext) {
      bool enCours = false;
      return StatefulBuilder(
        builder: (contexteDuDialogue, setDialogState) {
          return PopScope(
            // Le bouton retour du système n'escamote pas l'attente non plus.
            canPop: !enCours,
            child: Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 24,
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                  border: Border.all(
                    color: AppColors.textPrimary.withValues(alpha: 0.08),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.error.withValues(alpha: 0.12),
                        border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        size: 28,
                        color: AppColors.error,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      "Supprimer mon compte",
                      style: GoogleFonts.poppins(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    // La phrase ne promet QUE ce que le serveur fait — cf. la
                    // note en tête de fichier. La version précédente ajoutait
                    // « Vos données sont conservées pendant un délai de grâce
                    // de 30 jours, puis supprimées définitivement » : la
                    // conservation est vraie, la suppression n'existe nulle
                    // part côté serveur. Mieux vaut dire à la personne que ces
                    // informations restent, et par où passer pour les faire
                    // effacer, que lui promettre une purge automatique qui
                    // n'aura pas lieu.
                    Text(
                      "Votre compte sera immédiatement désactivé : vous ne pourrez plus vous y connecter et votre nom cessera d'être affiché. Vos autres informations (adresse e-mail, pseudo, téléphone, biographie) restent conservées ; pour en demander l'effacement définitif, contactez le support.",
                      style: GoogleFonts.poppins(
                        color: AppColors.textPrimary.withValues(alpha: 0.7),
                        fontSize: 14,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: TextButton(
                              onPressed: enCours
                                  ? null
                                  : () => Navigator.pop(dialogContext),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.textHint,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppDimensions.radiusInner,
                                  ),
                                ),
                              ),
                              child: Text(
                                "Annuler",
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: enCours
                                  ? null
                                  : () async {
                                      setDialogState(() => enCours = true);
                                      await _executerLaSuppression(
                                        ecran: context,
                                        dialogue: dialogContext,
                                      );
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.error,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppDimensions.radiusInner,
                                  ),
                                ),
                              ),
                              child: enCours
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                  : Text(
                                      "Supprimer",
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

/// Enchaîne l'appel au serveur, la fermeture du dialogue d'attente et
/// l'annonce du résultat.
///
/// Isolée du `builder` pour que le `await` ne vive pas au milieu de l'arbre de
/// widgets : le dialogue se ferme ici, dans tous les cas, avant que quoi que
/// ce soit ne s'affiche. [ecran] est le contexte de la page des réglages —
/// celui qui survit à la fermeture du dialogue et porte la navigation.
Future<void> _executerLaSuppression({
  required BuildContext ecran,
  required BuildContext dialogue,
}) async {
  Object? echec;
  try {
    await _demanderLaSuppression();
  } catch (e) {
    echec = e;
  }

  if (dialogue.mounted) {
    Navigator.of(dialogue).pop();
  }
  if (!ecran.mounted) return;

  if (echec != null) {
    // Échec = rien n'a changé, ni sur le serveur ni en local. On affiche la
    // raison du serveur au lieu d'annoncer un succès qui n'a pas eu lieu.
    AppNotifications.showSnackBar(
      ecran,
      message: messageLisible(
        echec,
        repli: "La suppression du compte n'a pas abouti. Réessayez.",
      ),
      isError: true,
    );
    return;
  }

  // Le message d'après-coup dit exactement ce que le serveur vient de faire.
  // Il ne relaie plus la phrase du serveur (« vos données anonymisées…
  // définitivement supprimées après 30 jours ») : elle promettait, cinq
  // secondes après un dialogue de confirmation qu'on avait corrigé, ce que
  // `DeleteAccount` ne fait pas.
  await AppNotifications.showPremiumDialog(
    ecran,
    title: "Compte désactivé",
    message:
        "Votre compte a été désactivé : vous ne pouvez plus vous y connecter et votre nom n'est plus affiché.",
    confirmText: "Fermer",
    isSuccess: true,
  );

  // La session n'existe plus : rester sur les réglages n'aurait aucun sens.
  // Retour au point de départ de l'application — et par le retour du dialogue
  // plutôt que par onConfirm, car showPremiumDialog se ferme aussi d'un appui
  // à côté (barrierDismissible) : on serait alors resté sur les réglages d'un
  // compte qui n'existe plus, jusqu'au premier 401.
  if (!ecran.mounted) return;
  Navigator.of(ecran).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const BienvenuePage()),
    (route) => false,
  );
}

/// Demande la suppression au serveur, et n'annonce QUE ce qu'il a confirmé.
///
/// Ce gestionnaire n'appelait que SessionService.terminer() — un nettoyage
/// purement LOCAL — puis affichait « votre demande a bien été transmise » :
/// aucune requête ne partait, le compte restait pleinement actif en base avec
/// toutes ses données, et il suffisait de se reconnecter pour le retrouver
/// intact. La route existe (DELETE /utilisateurs/:id) : c'est elle qui fait
/// foi, et le nettoyage local ne vient qu'APRÈS son accord.
///
/// Lève si le serveur refuse. Aucun affichage ici : c'est
/// [_executerLaSuppression] qui décide de ce que voit la personne.
Future<void> _demanderLaSuppression() async {
  await AuthService().deleteAccount();

  // Le compte est désactivé côté serveur : on révoque la session sur le
  // serveur puis on efface toute trace locale — logout() fait les deux.
  //
  // Un ennui ICI ne remet pas en cause ce que le serveur a déjà fait : le
  // signaler comme un échec de suppression ferait croire que le compte est
  // intact. On le journalise, et on annonce ce qui s'est réellement produit.
  try {
    await AuthService().logout();
  } catch (e) {
    debugPrint('Suppression du compte : fin de session imparfaite — $e');
  }
}
