import 'package:space_learn_flutter/core/space_learn/data/model/user_model.dart';

class TokenUser {
  final String token;

  /// Le jeton qui prolonge la session sans redemander le mot de passe.
  ///
  /// Vide quand le serveur n'en délivre pas encore — une version antérieure de
  /// l'API. L'application fonctionne alors comme avant : la session dure ce que
  /// dure le jeton d'accès, et pas davantage.
  final String refreshToken;

  final UserModel user;

  /// La connexion vient-elle de ROUVRIR un compte que son titulaire avait
  /// fermé ?
  ///
  /// /auth/login et /auth/google appellent tous deux `AnnulerLaSuppression`
  /// (space_learn_auth) : présenter le bon mot de passe — ou un jeton Google
  /// vérifié — pendant le délai de grâce annule la suppression sur-le-champ.
  ///
  /// CE CHAMP ÉTAIT RENDU PAR LE SERVEUR ET LU PAR PERSONNE ICI. La personne
  /// entrait donc dans un compte nommé « Utilisateur Anonymisé » — c'est
  /// `DeleteAccount` qui remplace le nom affiché — sans un mot lui disant que
  /// son effacement était annulé ni qu'elle devait ressaisir son nom. Le site
  /// le lisait, le mobile non : un serveur, deux vérités.
  final bool suppressionAnnulee;

  /// Ce que le serveur a écrit pour être lu, sur cette connexion-là.
  ///
  /// Vaut « Connexion réussie » dans le cas ordinaire — rien à montrer. Quand
  /// [suppressionAnnulee] est vrai, il porte la phrase qui explique la
  /// réouverture et le nom à ressaisir : c'est CELLE-LÀ qu'on affiche, et non
  /// une phrase à nous qui divergerait au premier changement.
  final String message;

  TokenUser({
    required this.token,
    required this.user,
    this.refreshToken = '',
    this.suppressionAnnulee = false,
    this.message = '',
  });

  factory TokenUser.fromJson(Map<String, dynamic> json) {
    return TokenUser(
      token: json['token'],
      refreshToken: json['refresh_token']?.toString() ?? '',
      user: UserModel.fromJson(json['user']),
      suppressionAnnulee: json['suppression_annulee'] == true,
      message: json['message']?.toString() ?? '',
    );
  }
}
