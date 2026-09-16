import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';

/// LES IMAGES DISTANTES, GARDÉES SUR LE DISQUE.
///
/// CE QUI MANQUAIT. Flutter tient un cache EN MÉMOIRE — environ mille entrées,
/// cent mégaoctets, partagé par toute l'application : défiler la boutique et
/// revenir en arrière ne retélécharge pas une couverture déjà vue. Il ne tient
/// AUCUN cache disque. `NetworkImage` passe par le client HTTP de `dart:io`,
/// qui ne persiste rien.
///
/// Conséquence, mesurée sur ce dépôt : trente et une images distantes —
/// couvertures d'ouvrages, photos de profil, visuels d'événements — repartaient
/// du réseau à CHAQUE lancement, et à chaque fois qu'Android reprend la mémoire
/// d'une application passée en arrière-plan. Sur les forfaits comptés que ce
/// projet vise explicitement (voir l'avertissement de `main.dart`), c'est de
/// l'argent dépensé pour retélécharger la même chose, et une grille de boutique
/// grise à chaque ouverture.
///
/// POURQUOI UNE FONCTION PLUTÔT QU'UN WIDGET. Le paquet expose aussi un widget
/// `CachedNetworkImage`, dont l'interface diffère de `Image` : `placeholder` et
/// `errorWidget` au lieu de `loadingBuilder` et `errorBuilder`. L'adopter aurait
/// obligé à réécrire les trente et un appels, chacun avec ses propres états de
/// chargement et d'erreur — trente et une occasions de perdre en route un repli
/// soigneusement écrit. Un `ImageProvider` se substitue, lui, sans rien changer
/// d'autre :
///
///   Image.network(url, fit: BoxFit.cover, errorBuilder: …)
///   Image(image: imageReseau(url), fit: BoxFit.cover, errorBuilder: …)
///
///   backgroundImage: NetworkImage(url)
///   backgroundImage: imageReseau(url)
///
/// Tous les paramètres, tous les replis, tous les états restent en place. Le
/// seul changement est l'endroit d'où viennent les octets.
///
/// UN SEUL POINT DE PASSAGE, et c'est l'autre raison de ce fichier. Le jour où
/// il faudra borner la taille du cache, poser une durée de conservation, ou
/// changer de bibliothèque, cela se fera ici — pas dans dix-neuf fichiers.
ImageProvider imageReseau(String url) => CachedNetworkImageProvider(url);
