/// Noms des salons de la communauté.
///
/// Ils vivent ici parce qu'une salle ne doit pas changer de nom selon la porte
/// par laquelle on y entre.
///
/// `ForumDiscussionPage` recevait auparavant son titre et son sous-titre en
/// paramètres requis, et chacun de ses cinq appelants écrivait les siens. Le
/// salon global — une seule salle côté serveur, `type = 'GLOBAL'`, sans aucun
/// filtre de rôle — s'appelait donc « SALON DE L'AUTEUR » depuis l'onglet
/// Communauté d'un auteur, « LE CAFE DES LECTEURS » depuis celui d'un lecteur,
/// et « Le Café des Lecteurs » quand une notification y menait. Le même auteur
/// pouvait voir la même salle sous deux noms au cours d'une même session, et
/// « votre communauté » lui laissait croire qu'il s'adressait à ses propres
/// lecteurs alors qu'il écrivait dans le forum de toute la plateforme.
///
/// La casse naturelle est conservée : l'en-tête applique `toUpperCase()`
/// lui-même. Écrire les constantes en majuscules ferait perdre les accents.
abstract final class SalonNoms {
  /// Le salon ouvert à tous, lecteurs comme auteurs.
  static const String globalTitre = 'Le Café des Lecteurs';
  static const String globalSousTitre =
      'Espace d\'échange commun aux lecteurs et aux auteurs';

  /// Le salon attaché à un livre : son sous-titre est le titre de l'ouvrage.
  static const String clubTitre = 'Club de lecture';

  /// Catégories d'un sujet de discussion.
  ///
  /// Elles servent à la fois d'onglets de filtrage et de choix à l'ouverture
  /// d'un sujet : une seule liste, sans quoi un onglet qu'on ne peut pas
  /// choisir en créant un sujet ne renverrait jamais rien.
  ///
  /// Les précédentes — « Théories », « Personnages », « Animations » — venaient
  /// d'un forum de fiction. Space Learn est une place de marché de livres :
  /// on y vient pour dire ce qu'on a pensé d'un ouvrage, en demander un, ou
  /// parler du métier d'écrire. Ces quatre-là couvrent ce qui s'y dit vraiment,
  /// dans le salon commun comme dans le club d'un livre.
  static const List<String> categories = [
    'Avis de lecture',
    'Recommandations',
    'Questions à l\'auteur',
    'Écriture & édition',
  ];
}
