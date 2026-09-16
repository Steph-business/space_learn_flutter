import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:space_learn_flutter/core/space_learn/data/dataServices/authServices.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/auth/bienvenue.dart';
import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/themes/app_dimensions.dart';
import 'package:space_learn_flutter/core/utils/app_notifications.dart';
import 'package:space_learn_flutter/core/utils/contact.dart';
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
/// `DeleteAccount` (space_learn_auth, controllers/user.go) ferme le compte
/// sur-le-champ — statut « supprime », nom affiché remplacé, date de
/// suppression — et révoque toutes les sessions ; `PeutOuvrirSession`
/// (models/user.go) referme la porte. Les autres informations restent en base
/// le temps du délai de grâce, puis `service.PurgerComptesSupprimes` — la tâche
/// périodique montée en routes/routes.go — efface l'adresse, le pseudo, le
/// téléphone, la date de naissance, le sexe, la photo, la biographie, les liens
/// sociaux et le portefeuille.
///
/// LE DÉLAI DE TRENTE JOURS N'EST PAS UN ORNEMENT : c'est lui qui rend
/// l'annulation possible, l'adresse restant en base le temps qu'il court. C'est
/// la seule clé dont le support dispose pour retrouver un compte fermé
/// (space_learn_auth, scripts/chercher_compte.go et scripts/restaurer_compte.go).
/// Le dire ici, c'est donc décrire un chemin qui existe — pas promettre au nom
/// d'un serveur qui ne le ferait pas.
///
/// LE CHEMIN DU RETOUR EST LA RECONNEXION, PAS LE COURRIEL AU SUPPORT — et les
/// deux textes de ce fichier ont dit le contraire pendant trois tours. Ils
/// annonçaient « vous ne pourrez plus vous y connecter », puis renvoyaient vers
/// $adresseContact comme unique sortie. Les deux moitiés sont fausses depuis
/// que /auth/login appelle `service.AnnulerLaSuppression` (login.go) et que
/// /auth/google en fait autant (oauth_google.go) : SE RECONNECTER, par mot de
/// passe OU avec Google selon la façon dont on s'est inscrit, rouvre le compte
/// pendant tout le délai.
///
/// C'ÉTAIT LE DÉGÂT LE PLUS CONCRET DE LA CAMPAGNE, et pas seulement une phrase
/// inexacte : une personne à qui l'on écrit « vous ne pourrez plus vous y
/// connecter » se reconnecte quand même — par habitude, depuis un second
/// appareil, avec un mot de passe enregistré — et ANNULE SON PROPRE EFFACEMENT
/// sans l'avoir voulu.
///
/// $adresseContact reste écrit, en SECOND, pour les deux seuls cas qu'une
/// connexion ne rouvre pas : le délai écoulé, et l'archivage prononcé par
/// l'administration par-dessus la fermeture. Ce sont exactement les deux cas
/// que le 403 de login.go nomme.
///
/// LA RÉSERVATION DE L'ADRESSE est la seconde chose que le serveur annonce et
/// que ces textes taisaient : l'e-mail et le pseudo restent dans leur index
/// unique jusqu'à la purge, donc une réinscription se heurte à « Un compte
/// existe déjà avec cette adresse ». On le dit à l'instant où la réservation
/// commence.
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
                    // note en tête de fichier. Elle a dit successivement les
                    // deux contraires : d'abord une purge automatique que rien
                    // n'exécutait, puis, quand le serveur s'est mis à tout
                    // effacer sur-le-champ, que « vos autres informations
                    // restent conservées ». La purge différée existe désormais
                    // vraiment (service.PurgerComptesSupprimes), et le délai
                    // qu'elle laisse est ce que la personne doit connaître :
                    // c'est sa fenêtre pour revenir en arrière.
                    // L'ADRESSE EST ÉCRITE ICI, pas seulement « le support ».
                    // Ce texte est le dernier que la personne lise en étant
                    // encore connectée : dire d'écrire sans dire où renvoyait
                    // vers une entrée « Contacter le support » qui n'ouvre
                    // qu'une FAQ, et qui disparaît de toute façon avec les
                    // réglages une fois le compte fermé.
                    //
                    // ELLE EST ÉCRITE EN SECOND, ET C'EST TOUT LE CORRECTIF :
                    // le premier chemin est la reconnexion — voir la note en
                    // tête de fichier. « Vous ne pourrez plus vous y
                    // connecter » disait le contraire de ce que le serveur
                    // fait, et cette phrase-là faisait annuler des
                    // suppressions par accident.
                    //
                    // LES TRENTE JOURS SONT CONDITIONNELS, ET L'ANNONCE
                    // D'AVANT NE LE DISAIT PAS. La purge retient les comptes à
                    // qui il reste de l'argent : effacer la destination de
                    // virement d'un auteur encore créditeur ferait sortir sa
                    // créance de tous les écrans à la fois
                    // (space_learn_auth, service/purge_comptes.go,
                    // `PurgeRetenuePour`). C'est une décision d'exploitation,
                    // pas une panne, et elle vaut mieux que l'incident qu'elle
                    // remplace — mais elle doit se dire AVANT le clic, pas
                    // seulement après, où le serveur la nomme déjà (`reste_du`
                    // sur la réponse du DELETE, lu plus bas). Le geste de
                    // sortie est écrit avec elle : demander le versement
                    // d'abord.
                    Text(
                      "Votre compte sera immédiatement fermé : vos appareils seront déconnectés et votre nom cessera d'être affiché. Vos autres informations seront effacées dans trente jours ; d'ici là, il suffit de vous reconnecter — par mot de passe ou avec Google — pour annuler la suppression. Si des gains vous restent dus, l'effacement attend leur versement : demandez votre retrait avant de fermer le compte. Si la connexion vous est refusée, écrivez à $adresseContact depuis l'adresse de ce compte.",
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
  SuppressionDemandee? reponse;
  try {
    reponse = await _demanderLaSuppression();
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

  // Le message d'après-coup dit exactement ce que le serveur vient de faire, et
  // redonne les deux renseignements dont la personne aura besoin ensuite : LE
  // GESTE QUI ANNULE — se reconnecter, par mot de passe ou avec Google — et
  // l'adresse à laquelle écrire quand ce geste lui est refusé. C'est le dernier
  // écran qu'elle voit avant d'être déconnectée : la ligne du dessous la ramène
  // à l'accueil, et plus rien dans l'application ne pourra le lui rappeler.
  //
  // L'ORDRE DES DEUX N'EST PAS INDIFFÉRENT. Ce texte annonçait le support comme
  // seule sortie et la connexion comme impossible ; il disait donc l'inverse du
  // serveur, qui rouvre le compte à la première reconnexion réussie.
  //
  // LA RÉSERVATION DE L'ADRESSE est dite ici et nulle part ailleurs dans
  // l'application : c'est la seule occasion, la personne étant déconnectée juste
  // après. Sans elle, elle découvrirait la chose en se heurtant au 409 de
  // /auth/register.
  //
  // Trente jours est bien la durée appliquée : `service.DelaiDeGraceSuppression`
  // (space_learn_auth) est la constante que la purge elle-même lit, et que
  // DeleteAccount rend en `grace_period_days`.
  // CE QUI RETIENT L'EFFACEMENT CHANGE CE QUE LE SERVEUR PROMET, DONC CE QUE
  // L'ÉCRAN ANNONCE.
  //
  // `DeleteAccount` RETIENT l'effacement dans deux cas : quand la personne est
  // encore créditrice — la purge emporterait la seule destination de virement
  // enregistrée — et quand son portefeuille n'a pas pu être LU, où l'on ignore
  // justement ce qu'on lui doit. Dans les deux, son message ne donne AUCUNE
  // date, et c'est lui qui le dit par `effacement_retenu` : le second cas ne
  // porte aucune somme, s'y fier ferait promettre trente jours. Rejouer notre
  // phrase, qui annonce trente jours, serait promettre ce que le serveur ne
  // fera pas. Dans ce cas-là, et dans celui-là seulement, on affiche la sienne
  // telle quelle : elle nomme la somme et dit le geste — se reconnecter pour
  // annuler la suppression et demander le versement. Voir
  // [SuppressionDemandee], et la note en tête de `deleteAccount`.
  final phraseDeLaDette =
      reponse != null &&
          reponse.uneDetteRetientLEffacement &&
          reponse.message.isNotEmpty
      ? reponse.message
      : null;

  await AppNotifications.showPremiumDialog(
    ecran,
    title: "Compte fermé",
    message: phraseDeLaDette != null
        ? "$phraseDeLaDette Si la connexion vous est refusée, écrivez à $adresseContact depuis l'adresse de ce compte."
        : "Votre compte est fermé et votre nom n'est plus affiché. Vos autres informations seront effacées dans trente jours ; d'ici là, reconnectez-vous — par mot de passe ou avec Google — et la suppression sera annulée. Votre adresse e-mail reste réservée jusqu'à cette date et ne peut pas servir à un nouveau compte avant. Si la connexion vous est refusée, écrivez à $adresseContact depuis l'adresse de ce compte.",
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
Future<SuppressionDemandee> _demanderLaSuppression() async {
  final reponse = await AuthService().deleteAccount();

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

  return reponse;
}
