import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:space_learn_flutter/core/utils/image_reseau.dart';

class ProfileImageHelper {
  static ImageProvider? getProfileImageProvider(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('data:image')) {
      try {
        final base64String = url.split(',').last;
        final bytes = base64Decode(base64String);
        return MemoryImage(bytes);
      } catch (_) {
        return null;
      }
    }
    return imageReseau(url);
  }

  static Widget buildProfileImage(
    String? url, {
    required String fallbackInitial,
    required TextStyle textStyle,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
  }) {
    if (url == null || url.isEmpty) {
      return Center(child: Text(fallbackInitial, style: textStyle));
    }

    if (url.startsWith('data:image')) {
      try {
        final base64String = url.split(',').last;
        final bytes = base64Decode(base64String);
        return Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (context, error, stackTrace) =>
              Center(child: Text(fallbackInitial, style: textStyle)),
        );
      } catch (_) {
        return Center(child: Text(fallbackInitial, style: textStyle));
      }
    }

    return Image(
      image: imageReseau(url),
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) =>
          Center(child: Text(fallbackInitial, style: textStyle)),
    );
  }
}
