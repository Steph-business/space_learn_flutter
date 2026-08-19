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

  TokenUser({required this.token, required this.user, this.refreshToken = ''});

  factory TokenUser.fromJson(Map<String, dynamic> json) {
    return TokenUser(
      token: json['token'],
      refreshToken: json['refresh_token']?.toString() ?? '',
      user: UserModel.fromJson(json['user']),
    );
  }
}
