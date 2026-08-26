/// Ancienneté d'une date, en français, telle qu'on la lit dans la communauté.
///
/// La fonction existait à l'identique dans les deux pages du forum. Deux
/// copies d'une même règle finissent toujours par diverger — l'une gagne un
/// pluriel, l'autre un seuil — et rien ne le signale, puisqu'elles compilent
/// séparément. Ici, une seule.
String tempsRelatif(DateTime date, {DateTime? maintenant}) {
  final ecart = (maintenant ?? DateTime.now()).difference(date);

  // Une date à venir n'a pas d'ancienneté. Les horloges d'un téléphone et d'un
  // serveur ne sont jamais tout à fait d'accord : sans ce cas, un message tout
  // juste envoyé pouvait s'afficher « il y a -1 min ».
  if (ecart.isNegative) return "à l'instant";

  // Au-delà d'un mois, on cesse de compter les semaines.
  //
  // Une annonce vit trois mois dans le fil. Sans ce palier, la plus ancienne
  // s'affichait « il y a 12 semaines » — une durée que personne ne se
  // représente, et qui donne au texte l'air d'être plus frais qu'il n'est.
  // Le mois vaut trente jours : un repère, pas un calcul.
  if (ecart.inDays >= 30) {
    final mois = ecart.inDays ~/ 30;
    return "il y a $mois mois";
  }
  if (ecart.inDays >= 7) {
    final semaines = ecart.inDays ~/ 7;
    return "il y a $semaines semaine${semaines > 1 ? 's' : ''}";
  }
  if (ecart.inDays >= 1) {
    return "il y a ${ecart.inDays} jour${ecart.inDays > 1 ? 's' : ''}";
  }
  if (ecart.inHours >= 1) {
    return "il y a ${ecart.inHours} heure${ecart.inHours > 1 ? 's' : ''}";
  }
  if (ecart.inMinutes >= 1) {
    return "il y a ${ecart.inMinutes} min";
  }
  return "à l'instant";
}
