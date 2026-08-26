/// À quelle distance se trouve un rendez-vous, en français.
///
/// Les cartes n'affichaient que la date exacte : « 17 août 2026 ». Elle dit la
/// même chose le jour de la publication et trois semaines plus tard, et laisse
/// au lecteur le soin de calculer si c'est demain ou dans un mois. Personne ne
/// calcule. Une carte qui ne bouge pas pendant que le temps avance finit par ne
/// plus être lue.
///
/// La date exacte reste affichée — elle seule permet de noter un rendez-vous.
/// Ceci s'y ajoute et dit ce qu'elle ne dit pas : est-ce que ça me concerne
/// maintenant.
///
/// Distinct de [tempsRelatif], qui mesure l'ANCIENNETÉ d'un message à la minute
/// près. Un rendez-vous, lui, est une journée : une dédicace à 9 h et une à
/// 18 h ont lieu « aujourd'hui » toutes les deux, et c'est le seul mot juste.
library;

/// Le numéro du jour civil, compté depuis une origine fixe.
///
/// Passer par UTC plutôt que par une différence de `Duration` : deux dates
/// locales séparées par un changement d'heure ne sont pas distantes d'un
/// multiple exact de 24 h, et `inDays` rend alors 0 pour deux jours différents.
/// La Côte d'Ivoire n'en connaît pas, mais un téléphone réglé sur un autre
/// fuseau, si — et un « Demain » affiché le jour même se remarque.
int _numeroDeJour(DateTime d) =>
    DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 86400000;

/// « Aujourd'hui », « Demain », « Dans 3 jours », « Il y a 2 semaines »…
String proximiteEvenement(DateTime date, {DateTime? maintenant}) {
  final jours =
      _numeroDeJour(date) - _numeroDeJour(maintenant ?? DateTime.now());

  // Les trois seuls mots que personne n'a besoin de traduire en distance.
  if (jours == 0) return "Aujourd'hui";
  if (jours == 1) return "Demain";
  if (jours == -1) return "Hier";

  if (jours > 0) return "Dans ${_duree(jours)}";
  return "Il y a ${_duree(-jours)}";
}

/// La distance, arrondie à l'unité qui se retient.
///
/// On ne dit pas « dans 47 jours » : au-delà de quelques semaines le nombre
/// exact n'apprend plus rien, et c'est la date affichée à côté qui sert. Les
/// mois valent trente jours — approximation assumée pour un repère, pas pour
/// un calcul.
String _duree(int jours) {
  if (jours < 7) return "$jours jours";

  if (jours < 30) {
    final semaines = jours ~/ 7;
    return semaines == 1 ? "une semaine" : "$semaines semaines";
  }

  final mois = jours ~/ 30;
  return mois == 1 ? "un mois" : "$mois mois";
}
