/// Qui suit le parcours auteur, et qui suit celui du lecteur.
///
/// La question se posait dans au moins quatre écrans, et chacun y répondait à
/// sa façon :
///
///   - la connexion acceptait « auteur », « administrateur », « éditeur » ;
///   - le démarrage y ajoutait « ecrivain » ;
///   - la barre de navigation exigeait l'égalité stricte avec « auteur », si
///     bien qu'un éditeur ou un administrateur se voyait ouvrir le guide du
///     LECTEUR depuis son propre espace ;
///   - le profil, lui, raisonnait à l'envers, sur « lecteur ».
///
/// Quatre règles pour une seule question finissent toujours par se contredire,
/// et c'est le genre d'écart que personne ne remarque avant qu'un utilisateur
/// ne signale un écran qui ne lui parle pas.
///
/// Le libellé vient de la base, où « Lecteur » traîne une espace finale et où
/// la casse n'est pas garantie : la comparaison normalise des deux côtés.
library;

/// Les libellés qui ouvrent le parcours auteur.
///
/// L'accent n'est pas normalisé par le passage en minuscules : les deux
/// graphies d'« éditeur » figurent donc explicitement.
const List<String> _libellesAuteur = [
  'auteur',
  'ecrivain',
  'écrivain',
  'editeur',
  'éditeur',
  'admin',
  'administrateur',
  'super admin',
];

/// Cette personne suit-elle le parcours auteur ?
///
/// Rend `false` sur un rôle inconnu ou absent : on ne présume pas de droits
/// qu'on n'a pas lus.
bool estParcoursAuteur(String? role) {
  final r = (role ?? '').trim().toLowerCase();
  if (r.isEmpty) return false;
  return _libellesAuteur.any((libelle) => r.contains(libelle));
}

/// Le pendant, pour les écrans qui raisonnent dans l'autre sens.
///
/// Ce n'est pas la négation stricte : un rôle vide n'est ni l'un ni l'autre,
/// et l'appelant doit pouvoir le distinguer.
bool estParcoursLecteur(String? role) {
  final r = (role ?? '').trim().toLowerCase();
  if (r.isEmpty) return false;
  return r.contains('lecteur') && !estParcoursAuteur(r);
}
