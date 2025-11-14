import 'package:space_learn_flutter/core/space_learn/data/model/userModel.dart';

class TokenUser {
  final String token;
  final UserModel user;

  TokenUser({required this.token, required this.user});

  factory TokenUser.fromJson(Map<String, dynamic> json) {
    return TokenUser(
      token: json['token'],
      user: UserModel.fromJson(json['user']),
    );
  }
}
