package com.example.space_learn_flutter

import com.ryanheise.audioservice.AudioServiceActivity

/**
 * L'activité hérite d'`AudioServiceActivity`, et non de `FlutterActivity`.
 *
 * `AudioServiceActivity` ne fait qu'une chose : redéfinir `provideFlutterEngine`
 * pour rendre le moteur PARTAGÉ du greffon audio_service. Sans elle, l'activité
 * fabrique son propre moteur, que le greffon ne trouve pas dans le cache — il en
 * crée alors un second et y relance `main()`.
 *
 * L'application tournait donc dans DEUX isolats. Deux isolats, deux
 * `ApiClient.instance`, donc deux verrous de renouvellement distincts — mais un
 * seul coffre de jetons, partagé au niveau du processus. Au démarrage, les deux
 * lisaient le même jeton d'accès périmé, prenaient chacun leur 401, et
 * envoyaient DEUX `POST /auth/refresh` avec le MÊME jeton de rafraîchissement.
 *
 * Le premier faisait tourner le jeton et recevait 200. Le second présentait un
 * jeton déjà consommé : le serveur y voit un rejeu — la signature d'un vol — et
 * révoque toute la famille, y compris le jeton neuf que le premier venait
 * d'obtenir. D'où le journal contradictoire : « Session renouvelée avec succès »
 * et « DÉCONNEXION DÉCLENCHÉE » dans la même seconde.
 *
 * Le défaut n'était donc ni dans le verrou du client, qui est correct, ni dans
 * la révocation de famille du serveur, qui protège d'un vol réel : il était ici,
 * dans une ligne d'héritage manquante. Le README d'audio_service l'exige
 * explicitement pour toute activité personnalisée.
 */
class MainActivity : AudioServiceActivity()
