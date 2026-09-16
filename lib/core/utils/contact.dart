/// L'adresse à laquelle on écrit à Space Learn.
///
/// ELLE MANQUAIT, ET DEUX ÉCRANS ENVOYAIENT POURTANT VERS ELLE.
///
/// Le parcours de suppression de compte renvoie ici — avant l'appel comme
/// après — et aucune adresse ne figurait nulle part dans l'application : ni
/// dans les deux dialogues, ni derrière « Contacter le support », qui ouvre
/// Aide & FAQ. On demandait d'écrire sans dire où — et le pire des deux
/// moments est le second, puisque le message de succès s'affiche juste avant
/// la déconnexion et le retour à l'écran d'accueil : les réglages, donc la
/// seule entrée « support », deviennent alors inatteignables. Une porte sans
/// poignée.
///
/// CE N'EST PLUS « LE SEUL MOYEN D'ANNULER », et ce paragraphe l'a écrit.
/// Depuis que /auth/login et /auth/google appellent `AnnulerLaSuppression`
/// (space_learn_auth), le chemin du retour est la RECONNEXION — par mot de
/// passe ou avec Google. Cette adresse ne couvre plus que les deux cas qu'une
/// connexion ne rouvre pas : le délai de trente jours écoulé, et l'archivage
/// prononcé par l'administration par-dessus la fermeture. Ce sont exactement
/// les deux que le 403 de login.go nomme — et il porte lui-même cette adresse,
/// parce qu'il sort sur l'écran de connexion, où les réglages n'existent pas.
///
/// ELLE RESTE DONC INDISPENSABLE : c'est la sortie de secours de ceux à qui la
/// reconnexion est refusée, et ils n'en ont aucune autre.
///
/// UNE SEULE CONSTANTE, importée partout, et la même valeur que le site
/// (Stepace_learn_web, src/lib/contact.ts) : l'adresse écrite en dur à
/// plusieurs endroits avait déjà divergé là-bas — deux domaines, deux boîtes,
/// et une personne qui écrivait à celle qu'elle avait lue n'atteignait pas
/// forcément quelqu'un. Le jour où elle change, elle change ici.
const String adresseContact = 'contact@spacelearn.com';
